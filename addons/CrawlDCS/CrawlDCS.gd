@tool
extends EditorPlugin

const AUTOLOAD_NAME_CRAWL : String = "Crawl"
const AUTOLOAD_NAME_DSV : String = "DSV"
const AUTOLOAD_NAME_UUID : String = "UUID"

func _enter_tree():
	add_autoload_singleton(AUTOLOAD_NAME_DSV, "res://addons/CrawlDCS/autoloads/DSV.gd")
	add_autoload_singleton(AUTOLOAD_NAME_UUID, "res://addons/CrawlDCS/autoloads/UUID.gd")
	add_autoload_singleton(AUTOLOAD_NAME_CRAWL, "res://addons/CrawlDCS/autoloads/Crawl.gd")


func _exit_tree():
	remove_autoload_singleton(AUTOLOAD_NAME_CRAWL)
	remove_autoload_singleton(AUTOLOAD_NAME_UUID)
	remove_autoload_singleton(AUTOLOAD_NAME_DSV)
