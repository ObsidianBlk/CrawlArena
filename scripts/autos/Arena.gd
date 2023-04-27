extends Node


func _ready() -> void:
	var lglt : CrawlMRLT = CrawlMRLT.new()
	lglt.register_from_dictionary({
		"ground":{
			"default":{
				"src":"res://assets/models/Default/Ground.glb",
				"description":"A basic ground floor. Nothing Special."
			}
		},
		"ceiling":{
			"default":{
				"src":"res://assets/models/Default/Ceiling.glb",
				"description":"A basic ceiling. Nothing to see here."
			}
		},
		"wall":{
			"default":{
				"src":"res://assets/models/Default/Wall.glb",
				"description":"A basic wall. Don't walk into it."
			}
		}
	})
	Crawl.store_lookup_table(&"level_geometry", lglt)
	
	var elt : CrawlMRLT = CrawlMRLT.new()
	elt.register_from_dictionary({
		"unique":{
			"editor":{
				"src":"res://addons/CrawlDCS/nodes/3d/objects/crawl_viewer_3d/CrawlViewer3D.tscn",
				"description":"Dungeon Editor Node."
			}
		}
	})
	Crawl.store_lookup_table(&"entities", elt)
