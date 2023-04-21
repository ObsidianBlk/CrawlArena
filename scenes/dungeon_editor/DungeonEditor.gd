extends Control


# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _editor_entity : CrawlEntity = null
var _dig_mode : bool = true
var _dig_direction : int = 1 # 0 = Down | 1 = Foreward | 2 = Up

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _crawl_mini_map : CrawlMiniMap = $CrawlMiniMap


# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	var map : CrawlMap = CrawlMap.new()
	map.add_resource(&"basic")
	map.add_cell(Vector3i.ZERO)
	
	_editor_entity = CrawlEntity.new()
	_editor_entity.type = &"editor"
	_editor_entity.uuid = UUID.v7()
	
	map.add_entity(_editor_entity)
	
	_crawl_mini_map.map = map
	_crawl_mini_map.focus_entity_uuid = _editor_entity.uuid

func _input(event : InputEvent) -> void:
	if _editor_entity == null: return
	if event.is_action_pressed("foreward", false, true):
		_editor_entity.move(&"foreward", true)
		accept_event()
	if event.is_action_pressed("backward", false, true):
		_editor_entity.move(&"backward", true)
		accept_event()
	if event.is_action_pressed("step_left", false, true):
		_editor_entity.move(&"left", true)
		accept_event()
	if event.is_action_pressed("step_right", false, true):
		_editor_entity.move(&"right", true)
		accept_event()
	if event.is_action_pressed("turn_left", false, true):
		_editor_entity.turn_left()
		accept_event()
	if event.is_action_pressed("turn_right", false, true):
		_editor_entity.turn_right()
		accept_event()
	if event.is_action_pressed("dig", false, true):
		var map : CrawlMap = _editor_entity.get_map()
		if map == null: return
		var surf : Crawl.SURFACE = _editor_entity.facing
		if _dig_direction != 1:
			surf = Crawl.SURFACE.Ground if _dig_direction == 0 else Crawl.SURFACE.Ceiling
		if _dig_mode:
			map.dig(_editor_entity.position, surf)
		else:
			map.fill(_editor_entity.position, surf)
		accept_event()
	if event.is_action_pressed("toggle_dig_direction", false, true):
		_dig_direction += 1
		if _dig_direction > 2:
			_dig_direction = 0
		accept_event()
	if event.is_action_pressed("toggle_dig_mode", false, true):
		_dig_mode = not _dig_mode
		accept_event()

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------

