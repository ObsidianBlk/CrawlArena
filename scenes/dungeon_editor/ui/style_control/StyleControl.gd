extends Control


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const DSR_FILEPATH : String = "user://dungeon_styles.tres"

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _dsr : DungeonStylesResource = null

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _mcc_styles : Control = %MCCStyles
@onready var _option_styles : OptionButton = %OptionStyles

@onready var _style_name_window : Window = %StyleNameWindow
@onready var _line_style_name : LineEdit = %Line_StyleName

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	if FileAccess.file_exists(DSR_FILEPATH):
		_dsr = ResourceLoader.load(DSR_FILEPATH)
	if _dsr == null:
		_dsr = DungeonStylesResource.new()
		_dsr.init()
		_dsr.add_style("Default")
		
		_dsr.add_style("Tomb")
		var style_position : Vector3i = _dsr.get_style_position("Tomb")
		_dsr.set_surface_at(style_position, Crawl.SURFACE.North, &"Catacombs 0", true)
		_dsr.set_surface_at(style_position, Crawl.SURFACE.South, &"Catacombs 0", true)
		_dsr.set_surface_at(style_position, Crawl.SURFACE.East, &"Catacombs 0", true)
		_dsr.set_surface_at(style_position, Crawl.SURFACE.West, &"Catacombs 0", true)
		_dsr.set_surface_at(style_position, Crawl.SURFACE.Ground, &"Cobble Blood 01", true)
		_dsr.set_surface_at(style_position, Crawl.SURFACE.Ceiling, &"Tomb 0", true)
	
	_mcc_styles.map = _dsr.get_map()
	var tracker : CrawlEntity = _dsr.get_tracking_entity()
	if tracker != null:
		tracker.position_changed.connect(_on_tracker_position_changed)
		print("Tracker Position: ", tracker.position)
		_mcc_styles.map_position = tracker.position
	_UpdateStyleOptions()

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _UpdateStyleOptions() -> void:
	if _option_styles == null: return
	
	var active_style : String = _dsr.get_active_style()
	var active_idx : int = 0
	
	_option_styles.clear()
	for style in _dsr.get_styles():
		var idx : int = _option_styles.item_count
		_option_styles.add_item(style)
		if style == active_style:
			active_idx = idx
	
	_option_styles.select(active_idx)

func _GetStyleOptionIndex(style_name : String) -> int:
	for idx in range(_option_styles.item_count):
		if _option_styles.get_item_text(idx):
			return idx
	return -1

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func copy_style_to_map(map : CrawlMap, map_position : Vector3i, options : Dictionary = {}, bi_directional : bool = false) -> void:
	if map == null: return
	if _dsr == null: return
	_dsr.copy_style_to_map(map, map_position, options, bi_directional)

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_tracker_position_changed(_from : Vector3i, to: Vector3i) -> void:
	_mcc_styles.map_position = to


func _on_option_styles_item_selected(idx : int) -> void:
	if _option_styles == null : return
	var style_name : String = _option_styles.get_item_text(idx)
	_dsr.set_active_style(style_name)
	_option_styles.release_focus()


func _on_mcc_styles_surface_resource_selected(surface : Crawl.SURFACE, resource_name : StringName) -> void:
	if _dsr == null: return
	_dsr.set_surface_resource(surface, resource_name)


func _on_mcc_styles_surface_blocking_toggled(surface : Crawl.SURFACE) -> void:
	if _dsr == null: return
	var blocking : bool = _dsr.get_surface_is_blocking(surface)
	_dsr.set_surface_blocking(surface, not blocking)


func _on_btn_request_add_style_pressed() -> void:
	if _style_name_window.visible: return
	_style_name_window.popup_centered()


func _on_btn_style_name_cancel_pressed() -> void:
	_line_style_name.text = ""
	_style_name_window.visible = false


func _on_btn_style_name_ok_pressed() -> void:
	if _line_style_name.text.is_empty():
		_on_btn_style_name_cancel_pressed()
		return
	
	if not _dsr.has_style(_line_style_name.text):
		_dsr.add_style(_line_style_name.text)
		_option_styles.add_item(_line_style_name.text)
	
	var oidx : int = _GetStyleOptionIndex(_line_style_name.text)
	if oidx >= 0:
		_option_styles.select(oidx)
	_dsr.set_active_style(_line_style_name.text)
	_on_btn_style_name_cancel_pressed()
