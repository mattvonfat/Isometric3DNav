extends Node2D

@onready var tilemap = $CustomTileMap
@onready var cat = tilemap.get_node("Entities").get_node("Cat")

func _ready():
	cat.game = self
	$CustomTileMap.set_cat(cat)
	cat.tilemap = $CustomTileMap
	$Label.set_text(tilemap.steps[4])
	tilemap.label = $Label
