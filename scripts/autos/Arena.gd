extends Node

func _ready() -> void:
	var lglt : CrawlMRLT = CrawlMRLT.new()
	lglt.register_from_dictionary({
		"ground":{
			"default":{
				"src":"res://assets/models/Default/Ground.glb",
				"description":"A basic ground floor. Nothing Special."
			},
			"Cobble Blood 01":{
				"src":"res://assets/models/Dungeon_01/Ground/Cobble_Blood_01.glb",
				"description": "Cobblestone ground."
			}
		},
		"ceiling":{
			"default":{
				"src":"res://assets/models/Default/Ceiling.glb",
				"description":"A basic ceiling. Nothing to see here."
			},
			"Tomb 0":{
				"src":"res://assets/models/Dungeon_01/Ceiling/Tomb_01.glb",
				"description":"Tomb ceiling."
			}
		},
		"wall":{
			"default":{
				"src":"res://assets/models/Default/Wall.glb",
				"description":"A basic wall. Don't walk into it."
			},
			"Catacombs 0":{
				"src":"res://assets/models/Dungeon_01/Walls/Catacombs_0.glb",
				"description":"Catacomb wall."
			}
		}
	})
	Crawl.store_lookup_table(&"level_geometry", lglt)
	
	var elt : CrawlMRLT = CrawlMRLT.new()
	elt.register_from_dictionary({
		"unique":{
			"editor":{
				"src":"res://addons/CrawlDCS/nodes/3d/objects/crawl_viewer_3d/CrawlViewer3D.tscn",
				"description":"Dungeon Editor"
			},
			"player":{
				"src":"res://entities/player/Player.tscn",
				"description":"Dungeon Player",
				"ui":"res://entities/player/ui/PlayerEntityUI.tscn"
			}
		}
	})
	Crawl.store_lookup_table(&"entities", elt)
