@tool
extends Control
class_name CrawlMiniMap


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal cell_pressed(cell_position)
signal selection_finished(sel_position, sel_size)

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const SELECTION_BLINK_INTERVAL : float = 0.08
const DEFAULT_ENTITY_ICON : Texture = preload("res://addons/CrawlDCS/assets/icons/entity.svg")

const DEFAULT_THEME_TYPE : StringName = &"CrawlMiniMap"
const THEME_STYLE_BACKGROUND : StringName = &"background"
const THEME_COLOR_SOLID_WALL : StringName = &"solid_wall"
const THEME_COLOR_INVISIBLE_WALL : StringName = &"invisible_wall"
const THEME_COLOR_ILLUSION_WALL : StringName = &"illusion_wall"
const THEME_COLOR_GROUND : StringName = &"ground"
const THEME_COLOR_STAIRS : StringName = &"stairs"
const THEME_COLOR_SELECTION : StringName = &"selection"

const DEFAULT_COLOR_SOLID_WALL : Color = Color.STEEL_BLUE
const DEFAULT_COLOR_INVISIBLE_WALL : Color = Color.SKY_BLUE
const DEFAULT_COLOR_ILLUSION_WALL : Color = Color.VIOLET
const DEFAULT_COLOR_GROUND : Color = Color.SIENNA
const DEFAULT_COLOR_STAIRS : Color = Color.CORAL
const DEFAULT_COLOR_SELECTION : Color = Color.THISTLE

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export_category("Crawl Mini-Map")
@export var map : CrawlMap = null:								set = set_map
@export var cell_size : float = 16.0:							set = set_cell_size
@export var focus_entity_uuid : StringName = &"":				set = set_focus_entity_uuid
@export var focus_entity_icon : Texture = null
@export var show_entity_types : Array[StringName] = []:			set = set_show_entity_types
@export var show_invisible_walls : bool = false:				set = set_show_invisible_walls
@export var show_illusion_walls : bool = false:					set = set_show_illusion_walls
#@export var entity_type_icons : Array[Texture] = []


# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _origin : Vector3i = Vector3i.ZERO
var _facing : Crawl.SURFACE = Crawl.SURFACE.North

var _mouse_entered : bool = false
var _last_mouse_position : Vector2 = Vector2.ZERO

var _area_start : Vector3i = Vector3i.ZERO
var _area_enabled : bool = false

var _selectors_visible : bool = false

var _entity_items : Dictionary = {}

var _label : Label = null

# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_map(m : CrawlMap) -> void:
	if m != map:
		if map != null:
			if map.entity_added.is_connected(_on_map_entity_added):
				map.entity_added.disconnect(_on_map_entity_added)
			if map.entity_removed.is_connected(_on_map_entity_removed):
				map.entity_removed.disconnect(_on_map_entity_removed)
			for uuid in _entity_items.keys():
				_UntrackEntity(_entity_items[uuid]["entity"])
			
		map = m
		if map != null:
			if not map.entity_added.is_connected(_on_map_entity_added):
				map.entity_added.connect(_on_map_entity_added)
			if not map.entity_removed.is_connected(_on_map_entity_removed):
				map.entity_removed.connect(_on_map_entity_removed)
			_UpdateTrackedTypes([], show_entity_types)
			set_focus_entity_uuid(focus_entity_uuid)
		queue_redraw()

func set_cell_size(s : float) -> void:
	if s > 0 and s != cell_size:
		cell_size = s
		#_UpdateCursor()
		queue_redraw()

func set_show_entity_types(et : Array[StringName]) -> void:
	_UpdateTrackedTypes(show_entity_types, et)
	show_entity_types = et

func set_focus_entity_uuid(uuid : StringName) -> void:
	if focus_entity_uuid in _entity_items:
		var ent : CrawlEntity = _entity_items[focus_entity_uuid]
		if not show_entity_types.has(ent.type):
			_UntrackEntity(ent)
	focus_entity_uuid = uuid
	if focus_entity_uuid != &"" and not focus_entity_uuid in _entity_items:
		if map == null: return
		var ent : CrawlEntity = map.get_entity(focus_entity_uuid)
		if ent == null: return
		_TrackEntity(ent)

func set_focus_entity_icon(ico : Texture) -> void:
	if ico != focus_entity_icon:
		focus_entity_icon = ico
		if focus_entity_uuid in _entity_items:
			var ei : TextureRect = _entity_items[focus_entity_uuid]["ctrl"]
			ei.texture = DEFAULT_ENTITY_ICON if focus_entity_icon == null else focus_entity_icon

func set_show_invisible_walls(s : bool) -> void:
	if s != show_invisible_walls:
		show_invisible_walls = s
		queue_redraw()

func set_show_illusion_walls(s : bool) -> void:
	if s != show_illusion_walls:
		show_illusion_walls = s
		queue_redraw()

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	resized.connect(_on_resized)
	theme_changed.connect(queue_redraw)
	_UpdateTrackedTypes([], show_entity_types)
	set_focus_entity_uuid(focus_entity_uuid)
	_on_selection_blink()

func _draw() -> void:
	var canvas_size : Vector2 = get_size()
	var canvas_region : Rect2 = Rect2(Vector2.ZERO, canvas_size)
	
	var bgstyle : StyleBox = _GetThemeStyleBox(THEME_STYLE_BACKGROUND)
	draw_style_box(bgstyle, Rect2(Vector2.ZERO, canvas_size))
	
	if map == null: return
	var cell_count : Vector2 = _CalcCellCount()
	
	var ox = (canvas_size.x * 0.5) - (cell_size * 0.5)
	var oy = (canvas_size.y * 0.5) - (cell_size * 0.5)
	
	var cell_range : Vector2i = Vector2i(floor(cell_count.x * 0.5), floor(cell_count.y * 0.5))
	
	var mouse_map_position : Vector3i = _ScreenToMap(_last_mouse_position)
	var mouse_position : Vector2i = Vector2i(mouse_map_position.x, mouse_map_position.z)#Vector2i(_last_mouse_position / cell_size) - cell_range
	
	# Area region. May not be needed :)
	var area_region : Rect2i = _CalcSelectionRegion(
		Vector2i(_area_start.x, _area_start.z), 
		mouse_position
	)
	
	var selection_color : Color = _GetThemeColor(THEME_COLOR_SELECTION)
	
	for cy in range(-(cell_range.y + 1), cell_range.y):
		for cx in range(-(cell_range.x + 1), cell_range.x):
			var map_position : Vector3i = _origin + Vector3i(cx, 0, cy)
			var screen_position : Vector2 = Vector2(ox - (cx * cell_size), oy - (cy * cell_size))
			
			# Drawing area selector one cell at a time.
			if _selectors_visible and _area_enabled and area_region.has_point(Vector2i(cx, cy)):
				if canvas_region.encloses(Rect2(screen_position, Vector2(cell_size, cell_size))):
					draw_rect(Rect2(screen_position, Vector2(cell_size, cell_size)), selection_color, false, 1.0)
				
			# Otherwise draw the cell as normal
			elif map.has_cell(map_position):
				if canvas_region.encloses(Rect2(screen_position, Vector2(cell_size, cell_size))):
					_DrawCell(map_position, screen_position)
					if map.is_cell_stairs(map_position):
						_DrawStairs(map_position, screen_position)
			
			# Draw mouse cursor if mouse in the scene...
			if _selectors_visible and _mouse_entered and mouse_position == Vector2i(cx, cy):
				draw_rect(Rect2(screen_position, Vector2(cell_size, cell_size)), selection_color, false, 1.0)

func _gui_input(event : InputEvent) -> void:
	if not _mouse_entered: return
	if is_instance_of(event, InputEventMouseMotion):
		_last_mouse_position = get_local_mouse_position()
		queue_redraw()
		accept_event()
	elif is_instance_of(event, InputEventMouseButton):
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				_area_start = _ScreenToMap(_last_mouse_position)
			elif _area_enabled != event.is_pressed():
				var area_end : Vector3i = _ScreenToMap(_last_mouse_position)
				var fx : int = min(_area_start.x, area_end.x)
				var fy : int = min(_area_start.y, area_end.y)
				var fz : int = min(_area_start.z, area_end.z)
				var tx : int = max(_area_start.x, area_end.x)
				var ty : int = max(_area_start.y, area_end.y)
				var tz : int = max(_area_start.z, area_end.z)
				var from : Vector3i = Vector3i(fx,fy,fz) + Vector3i(_origin.x, 0, _origin.z)
				var to : Vector3i = Vector3i(tx-fx, ty-fy, tz-fz) + Vector3i.ONE
				selection_finished.emit(from, to)
			_area_enabled = event.is_pressed()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.is_pressed():
				_area_enabled = false
				accept_event()

func _notification(what : int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_mouse_entered = true #not ignore_focus
		NOTIFICATION_MOUSE_EXIT:
			_mouse_entered = false
		NOTIFICATION_FOCUS_ENTER:
			pass
		NOTIFICATION_FOCUS_EXIT:
			pass
		NOTIFICATION_THEME_CHANGED:
			queue_redraw()
		NOTIFICATION_VISIBILITY_CHANGED:
			if visible:
				queue_redraw()
		NOTIFICATION_RESIZED:
			queue_redraw()

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _DrawStairs(map_position : Vector3i, screen_position : Vector2) -> void:
	var cell_size_v : Vector2 = Vector2.ONE * cell_size
	var step_size : Vector2 = cell_size_v * 0.3333
	
	var stairs_color : Color = _GetThemeColor(THEME_COLOR_STAIRS)
	
	var start : Vector2 = Vector2(
		screen_position.x,
		screen_position.y + (step_size.y * 2)
	)

	draw_line(start, start + Vector2(step_size.x, 0), stairs_color, 1.0, true)
	start.x += step_size.x
	
	draw_line(start, start - Vector2(0, step_size.y), stairs_color, 1.0, true)
	start.y -= step_size.y
	
	draw_line(start, start + Vector2(step_size.x, 0), stairs_color, 1.0, true)
	start.x += step_size.x
	
	draw_line(start, start - Vector2(0, step_size.y), stairs_color, 1.0, true)


func _DrawCell(map_position : Vector3i, screen_position : Vector2) -> void:
	var cell_size_v : Vector2 = Vector2.ONE * cell_size
	var inner_size : Vector2 = cell_size_v * 0.3
	var runit : Vector2 = (cell_size_v - inner_size) * 0.5
	
	var ground_color : Color = _GetThemeColor(THEME_COLOR_GROUND)
	var wall_solid_color : Color = _GetThemeColor(THEME_COLOR_SOLID_WALL)
	
	if map.is_cell_surface_blocking(map_position, Crawl.SURFACE.Ground):
		draw_rect(Rect2(screen_position + runit, inner_size), ground_color)
	else:
		draw_rect(Rect2(screen_position + runit, inner_size), ground_color, false, 1.0)
	
	if map.is_cell_surface_blocking(map_position, Crawl.SURFACE.Ceiling):
		var points : Array = [
			Vector2(-cell_size_v.x * 0.5, -cell_size_v.y * 0.5),
			Vector2(cell_size_v.x * 0.5, -cell_size_v.y * 0.5),
			Vector2((cell_size_v.x * 0.5) - runit.x, (-cell_size_v.y * 0.5) + runit.y),
			Vector2((-cell_size_v.x * 0.5) + runit.x, (-cell_size_v.y * 0.5) + runit.y)
		]
		
		var pos : Vector2 = screen_position + (cell_size_v * 0.5)
		for r in range(4):
			var rad : float = deg_to_rad(90.0 * r)
			draw_colored_polygon(PackedVector2Array([
					pos + points[0].rotated(rad),
					pos + points[1].rotated(rad),
					pos + points[2].rotated(rad),
					pos + points[3].rotated(rad)
				]), ground_color)
	else:
		var points : Array = [
			Vector2(-cell_size_v.x * 0.5, -cell_size_v.y * 0.5),
			Vector2(cell_size_v.x * 0.5, -cell_size_v.y * 0.5),
			Vector2((cell_size_v.x * 0.5) - runit.x, (-cell_size_v.y * 0.5) + runit.y),
			Vector2((-cell_size_v.x * 0.5) + runit.x, (-cell_size_v.y * 0.5) + runit.y)
		]
		
		var pos : Vector2 = screen_position + (cell_size_v * 0.5)
		for r in range(4):
			var rad : float = deg_to_rad(90.0 * r)
			draw_polyline(PackedVector2Array([
					pos + points[0].rotated(rad),
					pos + points[1].rotated(rad),
					pos + points[2].rotated(rad),
					pos + points[3].rotated(rad)
				]), ground_color, 1.0, true)

	_DrawWall(map_position, screen_position, Crawl.SURFACE.North)
	_DrawWall(map_position, screen_position, Crawl.SURFACE.South)
	_DrawWall(map_position, screen_position, Crawl.SURFACE.East)
	_DrawWall(map_position, screen_position, Crawl.SURFACE.West)


func _DrawWall(map_position : Vector3i, screen_position : Vector2, surface : Crawl.SURFACE) -> void:
	var is_blocking : bool = map.is_cell_surface_blocking(map_position, surface)
	var is_visible : bool = map.get_cell_surface_resource(map_position, surface) != &""
	var from : Vector2 = screen_position
	var to : Vector2 = screen_position
	match surface:
		Crawl.SURFACE.North:
			to += Vector2(cell_size, 0)
		Crawl.SURFACE.South:
			from += Vector2(0, cell_size)
			to += Vector2.ONE * cell_size
		Crawl.SURFACE.East:
			from += Vector2(cell_size, 0)
			to += Vector2.ONE * cell_size
		Crawl.SURFACE.West:
			to += Vector2(0, cell_size)
	
	if is_blocking and is_visible:
		var color = _GetThemeColor(THEME_COLOR_SOLID_WALL)
		draw_line(from, to, color, 1.0, true)
	elif is_blocking and not is_visible and show_invisible_walls:
		var color = _GetThemeColor(THEME_COLOR_INVISIBLE_WALL)
		draw_line(from, to, color, 1.0, true)
	elif not is_blocking and is_visible and show_illusion_walls:
		var color = _GetThemeColor(THEME_COLOR_ILLUSION_WALL)
		draw_line(from, to, color, 1.0, true)


func _GetThemeType() -> StringName:
	if theme_type_variation != &"":
		return theme_type_variation
	return DEFAULT_THEME_TYPE

func _GetThemeStyleBox(style_name : StringName) -> StyleBox:
	return get_theme_stylebox(style_name, _GetThemeType())

func _GetThemeFont(font_name : StringName) -> Font:
	return get_theme_font(font_name, _GetThemeType())

func _GetThemeFontSize(font_size_name : StringName) -> int:
	return get_theme_font_size(font_size_name, _GetThemeType())

func _GetThemeColor(color_name : StringName) -> Color:
	var tt : StringName = _GetThemeType()
	if has_theme_color(color_name, tt):
		return get_theme_color(color_name, tt)
	match color_name:
		THEME_COLOR_GROUND:
			return DEFAULT_COLOR_GROUND
		THEME_COLOR_ILLUSION_WALL:
			return DEFAULT_COLOR_ILLUSION_WALL
		THEME_COLOR_INVISIBLE_WALL:
			return DEFAULT_COLOR_INVISIBLE_WALL
		THEME_COLOR_SOLID_WALL:
			return DEFAULT_COLOR_SOLID_WALL
		THEME_COLOR_STAIRS:
			return DEFAULT_COLOR_STAIRS
		THEME_COLOR_SELECTION:
			return DEFAULT_COLOR_SELECTION
	return Color.BLACK

func _GetThemeConstant(const_name : StringName) -> int:
	return get_theme_constant(const_name, _GetThemeType())


func _CalcCellCount() -> Vector2i:
	var canvas_size : Vector2 = get_size()
	var cell_count : Vector2 = Vector2(
		floor(canvas_size.x / cell_size),
		floor(canvas_size.y / cell_size)
	)
	
	if int(cell_count.x) % 2 == 0: # We don't want an even count of cells.
		cell_count.x -= 1
	if int(cell_count.y) % 2 == 0:
		cell_count.y -= 1
	
	return Vector2i(cell_count)

func _ScreenToMap(p : Vector2, adjust_by_focus : bool = false) -> Vector3i:
	var canvas_size : Vector2 = get_size()
	var cell_count : Vector2 = Vector2(
		floor(canvas_size.x / cell_size),
		floor(canvas_size.y / cell_size)
	)
	var cell_range : Vector2i = Vector2i(floor(cell_count.x * 0.5), floor(cell_count.y * 0.5))
	
	# The mouse's map position. May not be needed :)
	var pos : Vector2i = Vector2i(_last_mouse_position / cell_size) - cell_range
	if map != null:
		var map_pos : Vector3i = Vector3i(-pos.x, _origin.y, -pos.y)
		if adjust_by_focus:
			print("Map Pos: ", map_pos)
			map_pos = map_pos - Vector3i(_origin.x, 0, _origin.z)
			print("Adjusted Position: ", map_pos, " | Focus Pos: ", _origin)
		return map_pos
	return Vector3i(-pos.x, 0, -pos.y)

func _CalcSelectionRegion(from : Vector2i, to : Vector2i) -> Rect2i:
	var fx : int = min(from.x, to.x)
	var tx : int= max(from.x, to.x)
	var fy : int = min(from.y, to.y)
	var ty : int = max(from.y, to.y)
	var sx : int = (tx - fx) + 1
	var sy : int = (ty - fy) + 1
	return Rect2i(fx, fy, sx, sy)

func _UpdateTrackedTypes(otypes : Array[StringName], ntypes : Array[StringName]) -> void:
	var added : Array[StringName] = ntypes.filter(func(item): return not otypes.has(item))
	var rem : Array[StringName] = otypes.filter(func(item): return not ntypes.has(item))
	
	for item in _entity_items:
		if rem.has(item["entity"].type) and item["entity"].uuid != focus_entity_uuid:
			_UntrackEntity(item["entity"].uuid)
	
	if map == null: return
	for type in added:
		var elist : Array = map.get_entities({"type":type})
		for entity in elist:
			_TrackEntity(entity)


func _TrackEntity(entity : CrawlEntity) -> void:
	if entity.uuid in _entity_items: return
	if entity.uuid != focus_entity_uuid and show_entity_types.find(entity.type) < 0: return
	
	_entity_items[entity.uuid] = {"entity":entity, "ctrl":null}
	var etr : TextureRect = TextureRect.new()
	etr.stretch_mode = TextureRect.STRETCH_SCALE
	etr.texture = DEFAULT_ENTITY_ICON
	if entity.uuid == focus_entity_uuid and focus_entity_icon != null:
		etr.texture = focus_entity_icon
	add_child(etr)
	_entity_items[entity.uuid]["ctrl"] = etr
	
	if not entity.position_changed.is_connected(_on_entity_position_changed.bind(entity.uuid)):
		entity.position_changed.connect(_on_entity_position_changed.bind(entity.uuid))
	if not entity.facing_changed.is_connected(_on_entity_facing_changed.bind(entity.uuid)):
		entity.facing_changed.connect(_on_entity_facing_changed.bind(entity.uuid))
	
	_UpdateEntityIcon(entity.uuid)
	_UpdateEntityIconFacing(entity.uuid)


func _UntrackEntity(entity : CrawlEntity) -> void:
	if not entity.uuid in _entity_items: return
	
	if entity.position_changed.is_connected(_on_entity_position_changed.bind(entity.uuid)):
		entity.position_changed.disconnect(_on_entity_position_changed.bind(entity.uuid))
	if entity.facing_changed.is_connected(_on_entity_facing_changed.bind(entity.uuid)):
		entity.facing_changed.disconnect(_on_entity_facing_changed.bind(entity.uuid))
	
	if _entity_items[entity.uuid]["ctrl"] != null:
		remove_child(_entity_items[entity.uuid]["ctrl"])
		_entity_items[entity.uuid]["ctrl"].queue_free()
	
	_entity_items.erase(entity.uuid)

func _UpdateEntityIcon(uuid : StringName) -> void:
	if not uuid in _entity_items: return
	if _entity_items[uuid]["ctrl"] == null: return
	
	var vhalf : Vector2 = Vector2.ONE * 0.5
	var canvas_size : Vector2 = get_size()
	var cell_count : Vector2i = _CalcCellCount()
	var entity : CrawlEntity = _entity_items[uuid]["entity"]
	var ico : TextureRect = _entity_items[uuid]["ctrl"]
	
	if entity.position.y != _origin.y:
		ico.visible = false
		return
	
	var dx : int = entity.position.x - _origin.x
	var dy : int = entity.position.z - _origin.z
	if abs(dx) > cell_count.x or abs(dy) > cell_count.y:
		ico.visible = false
		return
	
	ico.visible = true
	var canv_origin : Vector2 = canvas_size * 0.5
	ico.position = canv_origin + (Vector2(dx, dy) * cell_size)
	
	if ico.texture != null:
		var tsize : Vector2 = ico.texture.get_size()
		ico.pivot_offset = tsize * 0.5
		ico.scale = (Vector2.ONE * cell_size) / tsize
		ico.position -= tsize * 0.5


func _UpdateEntityIconFacing(uuid : StringName) -> void:
	if not uuid in _entity_items: return
	if _entity_items[uuid]["ctrl"] == null: return
	
	var entity : CrawlEntity = _entity_items[uuid]["entity"]
	var ico : TextureRect = _entity_items[uuid]["ctrl"]
	
	var fdir : Vector3i = Crawl.surface_to_direction_vector(entity.facing)
	var direction : Vector2 = Vector2(fdir.x, fdir.z)
	ico.rotation = Vector2.DOWN.angle_to(direction)


# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func start_selection(position : Vector3i) -> void:
	_area_start = position
	_area_enabled = true

func end_selection() -> void:
	_area_enabled = false

func get_focus_entity() -> CrawlEntity:
	if focus_entity_uuid in _entity_items:
		return _entity_items[focus_entity_uuid]["entity"]
	return null

func set_origin(origin : Vector3i) -> void:
	if focus_entity_uuid in _entity_items: return
	_origin = origin

func set_facing(facing : Crawl.SURFACE) -> void:
	if focus_entity_uuid in _entity_items: return
	_facing = facing

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_resized() -> void:
	for uuid in _entity_items.keys():
		_UpdateEntityIcon(uuid)

func _on_selection_blink() -> void:
	if Engine.is_editor_hint(): return

	_selectors_visible = not _selectors_visible
	var timer : SceneTreeTimer = get_tree().create_timer(SELECTION_BLINK_INTERVAL)
	timer.timeout.connect(_on_selection_blink)
	queue_redraw()

func _on_map_entity_added(entity : CrawlEntity) -> void:
	if entity.uuid == focus_entity_uuid or show_entity_types.find(entity.type) >= 0:
		_TrackEntity(entity)

func _on_map_entity_removed(entity : CrawlEntity) -> void:
	_UntrackEntity(entity)

func _on_entity_position_changed(from : Vector3i, to : Vector3i, uuid : StringName) -> void:
	if uuid == focus_entity_uuid:
		_origin = to
	_UpdateEntityIcon(uuid)

func _on_entity_facing_changed(from : Crawl.SURFACE, to : Crawl.SURFACE, uuid : StringName) -> void:
	if uuid == focus_entity_uuid:
		_facing = to
	_UpdateEntityIconFacing(uuid)

