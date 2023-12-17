extends Node2D

@onready var tilemap:TileMap = $TileMap

var tileset:TileSet

var layer_count:int # number of layers in the tile map
var map_layer_collection:Dictionary # stores the tile data for each layer

var cat
var d = true

var draw_step = 4
var label

func _ready():
	tilemap.hide()
	
	layer_count = tilemap.get_layers_count()
	map_layer_collection = {}
	
	# get the tile map data for each layer and store in map_collection_layer
	for layer_id in range(layer_count):
		map_layer_collection[layer_id] = tilemap.get_used_cells(layer_id)
		map_layer_collection[layer_id].sort_custom(sort_y_low_to_high) # sort low y to high y
	
	
	
	tileset = tilemap.get_tileset()

func _input(event):
	if event.is_action_released("ui_end"):
		if d:
			d = false
			#tilemap.show()
		else:
			d=true
			#tilemap.hide()
	
	if event.is_action_released("ui_page_down"):
		draw_step = draw_step + 1
		if draw_step == 5:
			draw_step = 1
		label.set_text("%s" % draw_step)
		queue_redraw()

func _draw():
	var temp_tile_collection = map_layer_collection.duplicate(true)
	
	var cat_tile = tilemap.local_to_map(cat.position)
	
	# TODO: draw lower layers first
	# TODO: need diags
	#cat_tile = Vector2i(-1,-19)
	print(cat_tile)
	var cat_layer = 1
	
	var drawing_y:int = cat_tile.y
	
	var base_tile= cat_tile
	base_tile.y += 1
	var even_y = true
	if cat_tile.y % 2 != 0:
		even_y = false
	
	var calc_tile
	
	if d == true:
		
		# draw the full layer of layers below the character
		for layer in range(0, cat_layer):
			draw_full_layer(layer, temp_tile_collection[layer])
		
		if draw_step > 1:
			for layer in range(cat_layer, layer_count):
				
				for tile in temp_tile_collection[layer]:
					if (even_y == true):
						if (tile.x < cat_tile.x):
							calc_tile = base_tile
						else:
							calc_tile = cat_tile
					else: # even_tile = false
						if (tile.x > base_tile.x):
							calc_tile = base_tile
							
						else:
							calc_tile = cat_tile
					
					
					if tile.y <= (calc_tile.y-(layer * 2))-(2*abs(calc_tile.x-tile.x)):
						var source_id = tilemap.get_cell_source_id(layer, tile)
						var coords = tilemap.get_cell_atlas_coords(layer, tile)
						var source = tileset.get_source(source_id)
						var texture = source.texture
						
						var drawing_rect = Rect2(0, 0, 32, 32)
						
						if tile.y % 2 == 0:
							drawing_rect.position.x = (tile.x*32)
							drawing_rect.position.y = (tile.y*8)
						else:
							drawing_rect.position.x = 16+(tile.x*32)
							drawing_rect.position.y = (tile.y*8) 
						
						draw_texture_rect_region(texture, drawing_rect, Rect2(coords.x*32, coords.y*32, 32, 32))
			
		if draw_step > 2:
			var txt = cat.get_node("Sprite2D").get_texture()
			draw_texture_rect(txt, Rect2(cat.position.x-16, cat.position.y-32, 32, 32), false)
		
		if draw_step > 3:
			# TODO: offset y can be layer * 2
			
			for layer in range(cat_layer, layer_count):
				
				for tile in temp_tile_collection[layer]:
					if (even_y == true):
						if (tile.x < cat_tile.x):
							calc_tile = base_tile
						else:
							calc_tile = cat_tile
					else: # even_tile = false
						if (tile.x > base_tile.x):
							calc_tile = base_tile
							
						else:
							calc_tile = cat_tile
					
					if tile.y > (calc_tile.y-(layer*2))-(2*abs(calc_tile.x-tile.x)):
						var source_id = tilemap.get_cell_source_id(layer, tile)
						var coords = tilemap.get_cell_atlas_coords(layer, tile)
						var source = tileset.get_source(source_id)
						var texture = source.texture
						
						var drawing_rect = Rect2(0, 0, 32, 32)
						
						if tile.y % 2 == 0:
							drawing_rect.position.x = (tile.x*32)
							drawing_rect.position.y = (tile.y*8)
						else:
							drawing_rect.position.x = 16+(tile.x*32)
							drawing_rect.position.y = (tile.y*8) 
						
						draw_texture_rect_region(texture, drawing_rect, Rect2(coords.x*32, coords.y*32, 32, 32))


func draw_full_layer(layer, tile_collection):
	for tile in tile_collection:
		var source_id = tilemap.get_cell_source_id(layer, tile)
		var coords = tilemap.get_cell_atlas_coords(layer, tile)
		var source = tileset.get_source(source_id)
		var texture = source.texture
		
		var drawing_rect = Rect2(0, 0, 32, 32)
		
		if tile.y % 2 == 0:
			drawing_rect.position.x = (tile.x*32)
			drawing_rect.position.y = (tile.y*8)
		else:
			drawing_rect.position.x = 16+(tile.x*32)
			drawing_rect.position.y = (tile.y*8) 
		
		draw_texture_rect_region(texture, drawing_rect, Rect2(coords.x*32, coords.y*32, 32, 32))


func set_cat(c):
	cat = c
	cat.get_node("Sprite2D").hide()

# custom array sort - sorts the array by y value low to high
func sort_y_low_to_high(a:Vector2i, b:Vector2i) -> bool:
	if a.y < b.y:
		return true
	return false


