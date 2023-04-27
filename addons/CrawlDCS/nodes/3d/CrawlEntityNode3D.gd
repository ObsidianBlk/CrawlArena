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

signal editor_mode_changed(enabled)


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
@export_range(0, 10, 1) var movement_queue_size : int = 0
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
var _movement_queue : Array = []
var _editor_mode : bool = false
var _entity_direct_update : bool = false

var _hide_distance : int = 4

var _schedule_movement_locking : bool = false
var _movement_locked : bool = false

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
			if _entity_direct_update:
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
			face(entity.facing, true)
		
		entity_changed.emit()

func set_body_node_path(bnp : NodePath) -> void:
	if bnp != body_node_path:
		body_node_path = bnp
		_body_node = null

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

func _AddToQueue(next : Callable) -> void:
	if _movement_queue.size() < movement_queue_size:
		_movement_queue.push_back(next)

func _ProcessQueue() -> void:
	if movement_queue_size <= 0 or _movement_queue.size() <= 0: return
	movement_queue_update.emit(_movement_queue.size() - 1)
	# Because it's possible, after the emitted signal, that the movement queue is flushed...
	if _movement_queue.size() <= 0: return
	var next : Callable = _movement_queue.pop_front()
	next.call()

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

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func set_editor_mode(enable : bool) -> void:
	_editor_mode = enable
	editor_mode_changed.emit(enable)

func use_entity_direct_update(enable : bool) -> void:
	_entity_direct_update = enable
	if entity == null: return
	if _entity_direct_update:
		if not entity.position_changed.is_connected(_on_position_changed):
			entity.position_changed.connect(_on_position_changed)
		if not entity.facing_changed.is_connected(_on_facing_changed):
			entity.facing_changed.connect(_on_facing_changed)
	else:
		if entity.position_changed.is_connected(_on_position_changed):
			entity.position_changed.disconnect(_on_position_changed)
		if entity.facing_changed.is_connected(_on_facing_changed):
			entity.facing_changed.disconnect(_on_facing_changed)

func clear_movement_queue() -> void:
	_movement_queue.clear()

func is_transitioning() -> bool:
	return _tween != null

func face(surface : Crawl.SURFACE, ignore_transition : bool = false) -> void:
	if surface == Crawl.SURFACE.Ground or surface == Crawl.SURFACE.Ceiling:
		# Can't face the ground or ceiling
		return
	var body : Node3D = _GetBodyNode()
	if body == null: return
	if _movement_locked or _tween != null:
		_AddToQueue(face.bind(surface, ignore_transition))
		return
	
	if quarter_turn_time <= 0.0 or ignore_transition == true:
		body.rotation.y = _SurfaceToAngle(surface)
		transition_complete.emit()
	else:
		var target_angle : float = _AngleToFace(body, surface)
		var angle_between : float = abs(body.rotation.y - target_angle)
		var duration = roundf(angle_between / DEG90) * quarter_turn_time
		_tween = create_tween()
		_tween.tween_property(body, "rotation:y", target_angle, duration)
		_tween.finished.connect(_on_tween_completed.bind(surface, position))

func turn(dir : int, ignore_transition : bool = false) -> void:
	if _entity_direct_update: return
	if entity == null: return
	if _movement_locked or _tween != null:
		_AddToQueue(turn.bind(dir, ignore_transition))
		return
	match dir:
		CLOCKWISE:
			entity.turn_right()
			face(entity.facing, ignore_transition)
		COUNTERCLOCKWISE:
			entity.turn_left()
			face(entity.facing, ignore_transition)

func move(direction : StringName, ignore_collision : bool = false, ignore_transition : bool = false) -> void:
	if _entity_direct_update: return
	if entity == null: return
	if _movement_locked or _tween != null:
		_AddToQueue(move.bind(direction, ignore_collision, ignore_transition))
		return
	
	var old_position : Vector3i = entity.position
	var start_on_stairs : bool = entity.on_stairs()
	
	var res : int = entity.move(direction, ignore_collision)
	if ignore_collision == false and res != OK: return
	
	var end_on_stairs : bool = entity.on_stairs()
	
	var target : Vector3 = Vector3(entity.position) * cell_size
	if end_on_stairs and not ignore_collision:
		target += Vector3.UP * (cell_size * 0.5)
	
	var duration : float = 0.0
	match direction:
		&"up":
			# TODO: Should check if on climbable
			duration = climb_time
		&"down":
			# TODO: Should check if on climbable
			duration = fall_time
		_: # This should be horizontal.
			duration = h_move_time

	if duration <= 0.0 or ignore_transition == true:
		position = target
	else:
		var calc_sub_target : Callable = func(from : Vector3i, to : Vector3i, ignore_y : bool):
			var xdiff : int = to.x - from.x
			var ydiff : int = 0 if ignore_y else to.y - from.y
			var zdiff : int = to.z - from.z
			return Vector3(
				position.x + (sign(xdiff) * cell_size * 0.5),
				position.y + (sign(ydiff) * cell_size * 0.5),
				position.z + (sign(zdiff) * cell_size * 0.5)
			)
			
		var announce_direction : StringName = &""
		if entity.position.y != old_position.y:
			announce_direction = &"up" if entity.position.y > old_position.y else &"down"
		transition_started.emit(announce_direction)
		
		_tween = create_tween()
		# Whether we start/end on stairs or not, if both states are the same, it's a simple
		# transition
		if start_on_stairs == end_on_stairs:
			if start_on_stairs:
				duration = climb_time
			_tween.tween_property(self, "position", target, duration)
		elif start_on_stairs: # We start of stairs and we climb off
			var sub_target : Vector3 = calc_sub_target.call(old_position, entity.position, false)
			_tween.tween_property(self, "position", sub_target, climb_time * 0.5)
			_tween.chain()
			_tween.tween_property(self, "position", target, h_move_time * 0.5)
		elif end_on_stairs: # We start on ground and end on stairs.
			var sub_target : Vector3 = calc_sub_target.call(old_position, entity.position, true)
			_tween.tween_property(self, "position", sub_target, h_move_time * 0.5)
			_tween.chain()
			_tween.tween_property(self, "position", target, climb_time * 0.5)
		_tween.finished.connect(_on_tween_completed.bind(entity.facing, target))

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
	if entity == null: return
#	if _hide_distance < 0:
#		if entity.map_focus_position_changed.is_connected(_on_ce_focus_position_changed):
#			entity.map_focus_position_changed.disconnect(_on_ce_focus_position_changed)
#	else:
#		if not entity.map_focus_position_changed.is_connected(_on_ce_focus_position_changed):
#			entity.map_focus_position_changed.connect(_on_ce_focus_position_changed)

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_position_changed(from : Vector3i, to : Vector3i) -> void:
	if not _entity_direct_update: return
	position = Vector3(to) * cell_size

func _on_facing_changed(from : Crawl.SURFACE, to : Crawl.SURFACE) -> void:
	if not _entity_direct_update: return
	face(to, true)

func _on_tween_completed(surface : Crawl.SURFACE, target_position : Vector3) -> void:
	_tween = null
	var body : Node3D = _GetBodyNode()
	
	# Rotation and position are hardset here to adjust for any floating point
	# errors during tweening.
	if body != null:
		body.rotation.y = _SurfaceToAngle(surface)
	position = Vector3(target_position)
	if entity != null:
		_CheckEntityVisible(entity.get_map_focus_position())
	transition_complete.emit()
	
	_ProcessQueue()

func _on_ce_removed_from_map() -> void:
	queue_free()

func _on_ce_focus_position_changed(focus_position : Vector3i) -> void:
	_CheckEntityVisible(focus_position)

func _on_ce_schedule_started(data : Dictionary) -> void:
	_movement_locked = false
	_ProcessQueue()

func _on_ce_schedule_ended(data : Dictionary) -> void:
	_movement_locked = true


