extends Window


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal dungeon_loaded(map)
signal dungeon_deleted(id)


# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _item_list : ItemList = %ItemList
@onready var _btn_load : Button = %BtnLoad
@onready var _btn_delete : Button = %BtnDelete


# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	DungeonDatabase.dungeon_entry_updated.connect(_on_dungeon_entry_updated)
	DungeonDatabase.dungeon_entry_removed.connect(_on_dungeon_entry_removed)
	visible = false

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _UpdateDungeonList() -> void:
	if _item_list == null: return
	_btn_load.disabled = true
	_btn_delete.disabled = true
	_item_list.clear()
	
	var dungeons : Array = DungeonDatabase.get_dungeon_list()
	for dungeon in dungeons:
		var idx : int = _item_list.add_item(dungeon["name"])
		_item_list.set_item_metadata(idx, dungeon["id"])

func _IDToIndex(id : StringName) -> int:
	for i in range(_item_list.item_count):
		if _item_list.get_item_metadata(i) == id:
			return i
	return -1

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_visibility_changed() -> void:
	if visible:
		_UpdateDungeonList()

func _on_dungeon_entry_updated(id : StringName) -> void:
	if _item_list == null: return
	var info : Dictionary = DungeonDatabase.get_dungeon_info(id)
	if info.is_empty(): return
	
	var idx : int = _IDToIndex(id)
	if idx < 0:
		idx = _item_list.add_item(info["name"])
		_item_list.set_item_metadata(idx, id)
	else:
		_item_list.set_item_text(idx, info["name"])
		

func _on_dungeon_entry_removed(id : StringName) -> void:
	if _item_list == null: return
	var idx : int = _IDToIndex(id)
	if idx < 0: return
	
	var idxs : PackedInt32Array = _item_list.get_selected_items()
	if idxs.find(idx) >= 0:
		_item_list.deselect_all()
		_item_list.remove_item(idx)
		_btn_load.disabled = true
		_btn_delete.disabled = true


func _on_item_list_item_selected(index : int) -> void:
	_btn_load.disabled = false
	_btn_delete.disabled = false

func _on_item_list_item_activated(index : int) -> void:
	if _item_list == null: return
	var id : StringName = _item_list.get_item_metadata(index)
	var map : CrawlMap = DungeonDatabase.load_dungeon(id)
	if map != null:
		dungeon_loaded.emit(map)
	_item_list.deselect_all()
	_btn_load.disabled = true
	_btn_delete.disabled = true
	visible = false

func _on_btn_load_pressed():
	if _item_list == null: return
	var idxs : Array = _item_list.get_selected_items()
	if idxs.size() > 0:
		_on_item_list_item_activated(idxs[0])

func _on_btn_delete_pressed():
	if _item_list == null: return
	var idxs : Array = _item_list.get_selected_items()
	if idxs.size() > 0:
		var id : StringName = _item_list.get_item_metadata(idxs[0])
		if DungeonDatabase.delete_dungeon(id) == OK:
			dungeon_deleted.emit(id)

func _on_btn_cancel_pressed():
	if _item_list != null:
		_item_list.deselect_all()
		_btn_load.disabled = true
		_btn_delete.disabled = true
	visible = false
