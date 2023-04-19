extends Control


@onready var _crawl_mini_map : CrawlMiniMap = $CrawlMiniMap


func _ready() -> void:
	var map : CrawlMap = CrawlMap.new()
	map.add_resource(&"basic")
	map.add_cell(Vector3i.ZERO)
	
	var entity : CrawlEntity = CrawlEntity.new()
	entity.type = &"editor"
	entity.uuid = UUID.v7()
	
	map.add_entity(entity)
	
	_crawl_mini_map.map = map
	_crawl_mini_map.focus_entity_uuid = entity.uuid


