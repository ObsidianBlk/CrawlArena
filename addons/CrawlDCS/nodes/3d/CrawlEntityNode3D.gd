extends Node3D
class_name CrawlEntityNode3D


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal entity_changing()
signal entity_changed()
signal transition_started(dir)
signal transition_complete()
signal movement_queue_update(remaining)

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const DEG90 : float = 1.570796
const CLOCKWISE : int = -1
const COUNTERCLOCKWISE : int = 1

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export_category("Crawl Entity Node 3D")
@export var cell_size : float = 5.0
@export var entity : CrawlEntity = null:						set = set_entity
@export var body_node_path : NodePath = "":						set = set_body_node_path
@export_range(0.0, 10.0) var quarter_turn_time : float = 0.2
@export_range(0.0, 10.0) var h_move_time : float = 0.4
@export_range(0.0, 10.0) var climb_time : float = 0.6
@export_range(0.0, 10.0) var fall_time : float = 0.1

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _body_node : Node3D = null
var _tween : Tween = null

var _instant_movement : bool = false
var _entity_position_changed : Array = []
var _entity_facing_changed : Array = []
var _entity_changed_order : Array = []

var _hide_distance : int = 4
var _focus_position : Vector3i = Vector3i.ZERO

var _schedule_movement_locking : bool = false

var _keep_hidden : bool = false

# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_entity(ent : CrawlEntity) -> void:
	if ent != entity:
		entity_changing.emit()
		if entity != null:
			if entity.position_changed.is_connected(_on_position_changed):
				entity.position_changed.disconnect(_on_position_changed)
			if entity.facing_changed.is_connected(_on_facing_changed):
				entity.facing_changed.disconnect(_on_facing_changed)
			if entity.removed_from_map.is_connected(_on_ce_removed_from_map):
				entity.removed_from_map.disconnect(_on_ce_removed_from_map)
			if entity.schedule_started.is_connected(_on_ce_schedule_started):
				entity.schedule_started.disconnect(_on_ce_schedule_started)
			if entity.schedule_ended.is_connected(_on_ce_schedule_ended):
				entity.schedule_ended.disconnect(_on_ce_schedule_ended)
			
			# This will force a disconnect
			var hd : int = _hide_distance
			hide_within_range(-1)
			_hide_distance = hd
		
		entity = ent
		if entity != null:
			if not entity.position_changed.is_connected(_on_position_changed):
				entity.position_changed.connect(_on_position_changed)
			if not entity.facing_changed.is_connected(_on_facing_changed):
				entity.facing_changed.connect(_on_facing_changed)
			if not entity.removed_from_map.is_connected(_on_ce_removed_from_map):
				entity.removed_from_map.connect(_on_ce_removed_from_map)
			if _schedule_movement_locking:
				if not entity.schedule_started.is_connected(_on_ce_schedule_started):
					entity.schedule_started.connect(_on_ce_schedule_started)
				if not entity.schedule_ended.is_connected(_on_ce_schedule_ended):
					entity.schedule_ended.connect(_on_ce_schedule_ended)
			hide_within_range(_hide_distance) # This will connect (or not) based on _hide_distance
			position = Vector3(entity.position) * cell_size
			_Face(entity.facing, entity.facing, true)
		
		entity_changed.emit()

func set_body_node_path(bnp : NodePath) -> void:
	if bnp != body_node_path:
		body_node_path = bnp
		_body_node = null


# --------------------------------------------------------------------------------------------------
# Override Methods
# --------------------------------------------------------------------------------------------------

func _process(_delta : float) -> void:
	for action_name in _entity_changed_order:
		match action_name:
			&"position":
				if _entity_position_changed.size() == 2:
					var from : Vector3i = _entity_position_changed[0]
					var to : Vector3i = _entity_position_changed[1]
					_entity_position_changed.clear()
					_Translate(from, to)
			&"facing":
				if _entity_facing_changed.size() == 2:
					var from : Crawl.SURFACE = _entity_facing_changed[0]
					var to : Crawl.SURFACE = _entity_facing_changed[1]
					_entity_facing_changed.clear()
					_Face(from, to)
	_entity_changed_order.clear()
	if entity.is_translation_locked() == false and entity.translation_queue_size() > 0:
		entity.process_translation_queue()

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _GetBodyNode() -> Node3D:
	if _body_node == null:
		var bnode = get_node_or_null(body_node_path)
		if not is_instance_of(bnode, Node3D) : return null
		_body_node = bnode
	return _body_node

func _SurfaceToAngle(surface : Crawl.SURFACE) -> float:
	match surface:
		Crawl.SURFACE.North:
			return 0
		Crawl.SURFACE.South:
			return DEG90 * 2
		Crawl.SURFACE.East:
			return -DEG90
		Crawl.SURFACE.West:
			return DEG90
	return 0.0

func _AngleToFace(body : Node3D, surface : Crawl.SURFACE) -> float:
	var cur_surface : Crawl.SURFACE = Crawl.surface_from_direction_vector(body.basis.z)
	return body.rotation.y + Crawl.surface_to_surface_angle(cur_surface, surface)

func _CheckEntityVisible(focus_position : Vector3i) -> void:
	if _hide_distance < 0: return
	var vstate : bool = false
	if _hide_distance == 0:
		if focus_position == entity.position:
			vstate = true
	else:
		var aabb : AABB = AABB(
			Vector3(focus_position.x - _hide_distance, focus_position.y - _hide_distance, focus_position.z - _hide_distance),
			Vector3((_hide_distance * 2)+1, (_hide_distance * 2)+1, (_hide_distance * 2)+1))
		if aabb.has_point(Vector3(entity.position)):
			vstate = true
	
	if not _keep_hidden:
		if visible != vstate:
			visible = vstate

func _DirectionFromPositions(from : Vector3i, to : Vector3i) -> StringName:
	var dist : float = Vector3(from).distance_to(Vector3(to))
	if abs(1.0 - dist) >= 0.1: return &"instant"
	
	if from.x != to.x:
		return &"east" if from.x < to.x else &"west"
	elif from.y != to.y:
		return &"up" if from.y < to.y else &"down"
	return &"north" if from.z < to.z else &"south"

func _Translate(from : Vector3i, to : Vector3i) -> void:
	if entity == null: return
	if from == to: return
	if _tween != null: return
	
	var map : CrawlMap = entity.get_map()
	if map == null: return
	
	if _instant_movement:
		position = to * cell_size
		transition_complete.emit()
		return
	
	entity.lock_translation(true)
	var start_on_stairs : bool = map.is_cell_stairs(from)
	var end_on_stairs : bool = map.is_cell_stairs(to)
	
	var target : Vector3 = Vector3(to) * cell_size
	if end_on_stairs:
		target += Vector3.UP * (cell_size * 0.5)
	
	var direction : StringName = _DirectionFromPositions(from, to)
	var duration : float = h_move_time
	match direction:
		&"up":
			# TODO: Should check if on climbable
			duration = climb_time
		&"down":
			# TODO: Should check if on climbable
			duration = fall_time

	var calc_sub_target : Callable = func(from_position : Vector3i, to_position : Vector3i, ignore_y : bool):
		var xdiff : int = to_position.x - from_position.x
		var ydiff : int = 0 if ignore_y else to_position.y - from_position.y
		var zdiff : int = to_position.z - from_position.z
		return Vector3(
			position.x + (sign(xdiff) * cell_size * 0.5),
			position.y + (sign(ydiff) * cell_size * 0.5),
			position.z + (sign(zdiff) * cell_size * 0.5)
		)
	
	transition_started.emit(direction)
	
	_tween = create_tween()
	# Whether we start/end on stairs or not, if both states are the same, it's a simple
	# transition
	if start_on_stairs == end_on_stairs:
		if start_on_stairs:
			duration = climb_time
		_tween.tween_property(self, "position", target, duration)
	elif start_on_stairs: # We start of stairs and we climb off
		var sub_target : Vector3 = calc_sub_target.call(from, to, false)
		_tween.tween_property(self, "position", sub_target, climb_time * 0.5)
		_tween.chain()
		_tween.tween_property(self, "position", target, h_move_time * 0.5)
	elif end_on_stairs: # We start on ground and end on stairs.
		var sub_target : Vector3 = calc_sub_target.call(from, to, true)
		_tween.tween_property(self, "position", sub_target, h_move_time * 0.5)
		_tween.chain()
		_tween.tween_property(self, "position", target, climb_time * 0.5)
	_tween.finished.connect(_on_tween_completed.bind(entity.facing, target), CONNECT_ONE_SHOT)


func _Face(from : Crawl.SURFACE, to : Crawl.SURFACE, ignore_transition : bool = false) -> void:
	if from == Crawl.SURFACE.Ground or from == Crawl.SURFACE.Ceiling:
		# Can't face the ground or ceiling
		return
	if to == Crawl.SURFACE.Ground or to == Crawl.SURFACE.Ceiling:
		return
	
	var body : Node3D = _GetBodyNode()
	if body == null: return
	
	if _tween != null: return
	
	if quarter_turn_time <= 0.0 or _instant_movement == true or ignore_transition == true:
		body.rotation.y = _SurfaceToAngle(to)
		transition_complete.emit()
		return
	
	entity.lock_translation(true)
	var target_angle : float = _AngleToFace(body, to)
	var angle_between : float = abs(body.rotation.y - target_angle)
	var duration = roundf(angle_between / DEG90) * quarter_turn_time
	_tween = create_tween()
	_tween.tween_property(body, "rotation:y", target_angle, duration)
	_tween.finished.connect(_on_tween_completed.bind(to, position), CONNECT_ONE_SHOT)

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func is_transitioning() -> bool:
	return _tween != null

func enable_schedule_movement_locking(enable : bool) -> void:
	_schedule_movement_locking = enable
	if entity == null: return
	if _schedule_movement_locking:
		if not entity.schedule_started.is_connected(_on_ce_schedule_started):
			entity.schedule_started.connect(_on_ce_schedule_started)
		if not entity.schedule_ended.is_connected(_on_ce_schedule_ended):
			entity.schedule_ended.connect(_on_ce_schedule_ended)
	else:
		if entity.schedule_started.is_connected(_on_ce_schedule_started):
			entity.schedule_started.disconnect(_on_ce_schedule_started)
		if entity.schedule_ended.is_connected(_on_ce_schedule_ended):
			entity.schedule_ended.disconnect(_on_ce_schedule_ended)

func is_schedule_movement_locking_enabled() -> bool:
	return _schedule_movement_locking

func keep_hidden(enabled : bool) -> void:
	_keep_hidden = enabled
	if _keep_hidden:
		visible = false
	elif entity != null:
		_CheckEntityVisible(entity.get_map_focus_position())

func hide_within_range(dist : int) -> void:
	_hide_distance = max(-1, dist)
	_CheckEntityVisible(_focus_position)

func set_focus_position(focus : Vector3i) -> void:
	if focus != _focus_position:
		_focus_position = focus
		_CheckEntityVisible(_focus_position)

func enable_instant_movement(enable : bool) -> void:
	_instant_movement = enable

func is_instant_movement_enabled() -> bool:
	return _instant_movement

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_position_changed(from : Vector3i, to : Vector3i) -> void:
	if _entity_changed_order.size() < 2:
		if _entity_changed_order.is_empty() or _entity_changed_order[0] != &"position":
			_entity_changed_order.append(&"position")
	
	if _entity_position_changed.size() <= 0:
		_entity_position_changed.append(from)
		_entity_position_changed.append(to)
	else:
		_entity_position_changed[1] = to

func _on_facing_changed(from : Crawl.SURFACE, to : Crawl.SURFACE) -> void:
	if _entity_changed_order.size() < 2:
		if _entity_changed_order.is_empty() or _entity_changed_order[0] != &"facing":
			_entity_changed_order.append(&"facing")
	
	if _entity_facing_changed.size() <= 0:
		_entity_facing_changed.append(from)
		_entity_facing_changed.append(to)
	else:
		_entity_facing_changed[1] = to

func _on_tween_completed(surface : Crawl.SURFACE, target_position : Vector3) -> void:
	_tween = null
	var body : Node3D = _GetBodyNode()
	
	# Rotation and position are hardset here to adjust for any floating point
	# errors during tweening.
	if body != null:
		body.rotation.y = _SurfaceToAngle(surface)
	position = Vector3(target_position)
	if entity != null:
		_CheckEntityVisible(_focus_position)
	transition_complete.emit()
	entity.lock_translation(false)

func _on_ce_removed_from_map() -> void:
	queue_free()

func _on_ce_schedule_started(data : Dictionary) -> void:
	entity.lock_translation(false)

func _on_ce_schedule_ended(data : Dictionary) -> void:
	entity.lock_translation(true)


