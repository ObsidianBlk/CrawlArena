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

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export var map : CrawlMap = null:								set = set_map
@export var cell_size : float = 16.0:							set = set_cell_size
@export var background_color : Color = Color.DARK_GOLDENROD:	set = set_background_color
@export var background_texture : Texture = null:				set = set_background_texture
@export var wall_color : Color = Color.DARK_OLIVE_GREEN:		set = set_wall_color
@export var cell_color : Color = Color.DARK_SALMON:				set = set_cell_color
@export var stairs_color : Color = Color.YELLOW:				set = set_stairs_color
@export var selection_color : Color = Color.WHITE:				set = set_selection_color
@export var focus_icon : Texture = null:						set = set_focus_icon
@export var ignore_focus : bool = true:							set = set_ignore_focus


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

var _cursor_sprite : TextureRect = null

var _label : Label = null

# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_map(m : CrawlMap) -> void:
	if m != map:
		map = m
		# TODO: Possible signal connections
		queue_redraw()

func set_cell_size(s : float) -> void:
	if s > 0 and s != cell_size:
		cell_size = s
		_UpdateCursor()
		queue_redraw()

func set_background_color(c : Color) -> void:
	if background_color != c:
		background_color = c
		queue_redraw()

func set_background_texture(t : Texture) -> void:
	if background_texture != t:
		background_texture = t
		queue_redraw()

func set_wall_color(c : Color) -> void:
	if wall_color != c:
		wall_color = c
		queue_redraw()

func set_cell_color(c : Color) -> void:
	if cell_color != c:
		cell_color = c
		queue_redraw()

func set_stairs_color(c : Color) -> void:
	if stairs_color != c:
		stairs_color = c
		queue_redraw()

func set_selection_color(c : Color) -> void:
	if selection_color != c:
		selection_color = c
		queue_redraw()

func set_focus_icon(ico : Texture) -> void:
	if focus_icon != ico:
		focus_icon = ico
		_UpdateCursor()

func set_ignore_focus(i : bool) -> void:
	if ignore_focus != i:
		ignore_focus = i
		if _mouse_entered == ignore_focus:
			_mouse_entered = false
			queue_redraw()

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	resized.connect(_on_resized)
	_cursor_sprite = TextureRect.new()
	_cursor_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_cursor_sprite)
	_UpdateCursor()
	
	_on_selection_blink()

func _draw() -> void:
	var canvas_size : Vector2 = get_size()
	var canvas_region : Rect2 = Rect2(Vector2.ZERO, canvas_size)
	
	if background_texture != null:
		draw_texture_rect(background_texture, Rect2(Vector2.ZERO, canvas_size), true)
	else:
		draw_rect(Rect2(Vector2.ZERO, canvas_size), background_color)
	
	var cell_count : Vector2 = Vector2(
		floor(canvas_size.x / cell_size),
		floor(canvas_size.y / cell_size)
	)
	if map == null or cell_count.x <= 0 or cell_count.y <= 0:
		return # Well... there's nothing more to draw! Go figure! :)
	
	if int(cell_count.x) % 2 == 0: # We don't want an even count of cells.
		cell_count.x += 1
	if int(cell_count.y) % 2 == 0:
		cell_count.y += 1
	
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
				var focus_pos : Vector3i = map.get_focus_position()
				var area_end : Vector3i = _ScreenToMap(_last_mouse_position)
				var fx : int = min(_area_start.x, area_end.x)
				var fy : int = min(_area_start.y, area_end.y)
				var fz : int = min(_area_start.z, area_end.z)
				var tx : int = max(_area_start.x, area_end.x)
				var ty : int = max(_area_start.y, area_end.y)
				var tz : int = max(_area_start.z, area_end.z)
				var from : Vector3i = Vector3i(fx,fy,fz) + Vector3i(focus_pos.x, 0, focus_pos.z)
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
			_mouse_entered = not ignore_focus
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
	
	if map.is_cell_surface_blocking(map_position, Crawl.SURFACE.Ground):
		draw_rect(Rect2(screen_position + runit, inner_size), cell_color)
	else:
		draw_rect(Rect2(screen_position + runit, inner_size), cell_color, false, 1.0)
	
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
				]), cell_color)
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
				]), cell_color, 1.0, true)

	
	if map.is_cell_surface_blocking(map_position, Crawl.SURFACE.North):
		draw_line(
			screen_position,
			screen_position + Vector2(cell_size, 0),
			wall_color, 1.0, true
		)
	if map.is_cell_surface_blocking(map_position, Crawl.SURFACE.South):
		draw_line(
			screen_position + Vector2(0, cell_size),
			screen_position + Vector2(cell_size, cell_size),
			wall_color, 1.0, true
		)
	if map.is_cell_surface_blocking(map_position, Crawl.SURFACE.East):
		draw_line(
			screen_position + Vector2(cell_size, 0),
			screen_position + Vector2(cell_size, cell_size),
			wall_color, 1.0, true
		)
	if map.is_cell_surface_blocking(map_position, Crawl.SURFACE.West):
		draw_line(
			screen_position,
			screen_position + Vector2(0, cell_size),
			wall_color, 1.0, true
		)

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
		var focus_pos : Vector3i = map.get_focus_position()
		var map_pos : Vector3i = Vector3i(-pos.x, focus_pos.y, -pos.y)
		if adjust_by_focus:
			print("Map Pos: ", map_pos)
			map_pos = map_pos - Vector3i(focus_pos.x, 0, focus_pos.z)
			print("Adjusted Position: ", map_pos, " | Focus Pos: ", focus_pos)
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

func _UpdateCursor() -> void:
	var vhalf : Vector2 = Vector2.ONE * 0.5
	if _cursor_sprite != null:
		_cursor_sprite.position = (get_size() * 0.5)
		
		if _cursor_sprite.texture != focus_icon:
			_cursor_sprite.texture = focus_icon
		if _cursor_sprite.texture != null:
			var tsize : Vector2 = _cursor_sprite.texture.get_size()
			_cursor_sprite.pivot_offset = tsize * 0.5
			_cursor_sprite.scale = Vector2(cell_size, cell_size) / tsize
			_cursor_sprite.position -= tsize * 0.5

func _UpdateCursorFacing() -> void:
	if _cursor_sprite == null: return
	var fdir : Vector3i = Crawl.surface_to_direction_vector(_facing)
	var direction : Vector2 = Vector2(fdir.x, fdir.z)
	_cursor_sprite.rotation = Vector2.DOWN.angle_to(direction)

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func start_selection(position : Vector3i) -> void:
	_area_start = position
	_area_enabled = true

func end_selection() -> void:
	_area_enabled = false

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_resized() -> void:
	_UpdateCursor()

func _on_focus_position_changed(focus_position : Vector3i) -> void:
	_origin = focus_position
	queue_redraw()

func _on_focus_facing_changed(focus_facing : Crawl.SURFACE) -> void:
	_facing = focus_facing
	_UpdateCursorFacing()

func _on_selection_blink() -> void:
	if Engine.is_editor_hint(): return

	_selectors_visible = not _selectors_visible
	var timer : SceneTreeTimer = get_tree().create_timer(SELECTION_BLINK_INTERVAL)
	timer.timeout.connect(_on_selection_blink)
	queue_redraw()
