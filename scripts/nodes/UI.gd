extends CanvasLayer
class_name UI

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal action_requested(action_name, payload)

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export_category("UI Control")
@export var initial_menu : StringName = &""

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _breadcrumb : Array = []

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	_InitUI()

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _InitUI() -> void:
	if child_entered_tree.is_connected(_on_child_entered_tree): return
	
	child_entered_tree.connect(_on_child_entered_tree)
	for child in get_children():
		if is_instance_of(child, UIMenu):
			_on_child_entered_tree(child)
			if child.name == initial_menu:
				child.visible = true
				_breadcrumb.append(child.name)

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func breadcrumb_count() -> int:
	return _breadcrumb.size()

func get_current_menu() -> StringName:
	if _breadcrumb.size() > 0:
		return _breadcrumb[-1]
	return &""

func get_previous_menu() -> StringName:
	if _breadcrumb.size() > 1:
		return _breadcrumb[-2]
	return &""

func get_breadcrumbs() -> PackedStringArray:
	return PackedStringArray(_breadcrumb)

func clear_breadcrumbs() -> void:
	_breadcrumb.clear()

func hide_ui(clear_breadcrumbs : bool = false) -> void:
	if clear_breadcrumbs:
		clear_breadcrumbs()
	show_menu(&"")

func show_ui() -> void:
	if _breadcrumb.size() <= 0: return
	show_menu(_breadcrumb[-1])

func show_menu(menu_name : StringName) -> int:
	var res : int = ERR_DOES_NOT_EXIST
	for child in get_children():
		if is_instance_of(child, UIMenu):
			child.visible = (child.name == menu_name)
			if child.visible:
				res = OK
				if _breadcrumb.size() <= 0 or _breadcrumb[-1] != menu_name:
					_breadcrumb.append(menu_name)
	return res

func back() -> int:
	if _breadcrumb.size() <= 1: return ERR_DOES_NOT_EXIST
	_breadcrumb.pop_back()
	return show_menu(_breadcrumb[-1])

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_child_entered_tree(child : Node) -> void:
	if not is_instance_of(child, UIMenu): return
	child.visible = false
	if not child.action_requested.is_connected(_on_menu_action_requested):
		child.action_requested.connect(_on_menu_action_requested)

func _on_menu_action_requested(action_name : StringName, payload : Variant) -> void:
	match action_name:
		&"show_menu":
			if typeof(payload) == TYPE_STRING_NAME:
				show_menu(payload)
		&"menu_back":
			back()
		_:
			action_requested.emit(action_name, payload)

