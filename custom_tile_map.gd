extends Node2D

@onready var tilemap:TileMap = $TileMap

var steps = [ "", "Draw base layer only.", "Draw base layer and area behind character.", "Draw base layer, area behind character, and character.", "Draw everything." ]

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
		label.set_text(steps[draw_step])
		queue_redraw()
	
	if event.is_action_released("ui_home"):
		print(cat.get_layer())
		print(tilemap.local_to_map(cat.position))


func _draw():
	#draw_back_triangle()
	draw_triangle_surround()

func _draw_new():
	var temp_tile_collection_1 = map_layer_collection.duplicate(true)
	var temp_tile_collection_2 = []
	var extra_tiles = []
	
	var cat_tile = tilemap.local_to_map(cat.position)
	print(cat_tile)
	
	# TODO: draw lower layers first
	# TODO: need diags
	#cat_tile = Vector2i(0,-14)
	#cat_tile = Vector2i(5,-33)
	
	var cat_layer = cat.get_layer()
	#cat_layer = 2
	#print(cat_layer)
	
	
	var start_tile = cat_tile
	#start_tile.y -= 2
	
	
	var base_tile= start_tile
	base_tile.y += 1
	var even_y = true
	if start_tile.y % 2 != 0:
		even_y = false
	
	var calc_tile
	
	# draw the full layer of layers below the character
	for layer in range(0, layer_count):
		# add a new layer to temp_tile_collection_2
		temp_tile_collection_2.append([])
		
		# if this layer is below the cat then draw the whole thing
		if layer < cat_layer:
			draw_full_layer(layer, temp_tile_collection_1[layer])
		# if the layer is above the cat then also draw it
		elif  layer > cat_layer:
			draw_full_layer(layer, temp_tile_collection_1[layer])

	if draw_step > 1:
		for layer in range(cat_layer, layer_count):
			temp_tile_collection_2.append([])
			
			for tile in temp_tile_collection_1[layer]:
				if (even_y == true):
					calc_tile = base_tile
				else: # even_tile = false
					calc_tile = start_tile
					calc_tile.x += 1
				
				if tile.y < (calc_tile.y)+(2*(calc_tile.x-tile.x)):
					draw_tile(layer, tile)
					
					var test
					if even_y:
						if tile.x <= cat_tile.x:
							test = floor((cat_tile.y-1 - tile.y) / 2)
						else:
							test = floor((cat_tile.y - tile.y) / 2)
					else:
						if tile.x <= cat_tile.x:
							test = floor((cat_tile.y - tile.y) / 2)
						else:
							test = floor(((cat_tile.y+1) - tile.y) / 2)
					
					if ((cat_tile.x + test) == tile.x) and tile.x > cat_tile.x:
						#print(tile)
						# this tile is in the lowest row so lets draw stuff connected to it
						# find the next tile down which is attached
						var lower_tile = tile
						lower_tile.y += 1
						if tile.y % 2 != 0:
							lower_tile.x += 1
							
						while temp_tile_collection_1[layer].has(lower_tile):
							# this tile exists
							extra_tiles.append(tile)
							draw_tile(layer, lower_tile)
							if lower_tile.y % 2 != 0:
								lower_tile.x += 1
							lower_tile.y += 1
				
				else:
					if extra_tiles.has(tile) == false:
					
						temp_tile_collection_2[layer].append(tile)
	
	if draw_step > 2:
		var txt = cat.get_node("Sprite2D").get_texture()
		draw_texture_rect(txt, Rect2(cat.position.x-16, cat.position.y-32, 32, 32), false)
	
	if draw_step > 3:
		
		for layer in range(cat_layer, layer_count):
			
			for tile in temp_tile_collection_2[layer]:
				if (even_y == true):
					#if (tile.x < start_tile.x):
					calc_tile = base_tile
					#else:
						#calc_tile = start_tile
						#calc_tile.x -= 1
				else: # even_tile = false
					#if (tile.x > base_tile.x):
						#calc_tile = base_tile
						#
					#else:
					calc_tile = start_tile
					calc_tile.x += 1
				
				if tile.y >= (calc_tile.y-(layer * 2))+(2*(calc_tile.x-tile.x)):
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


func _draw_old():
	var temp_tile_collection_1 = map_layer_collection.duplicate(true)
	var temp_tile_collection_2 = []
	var extra_tiles = []
	
	var cat_tile = tilemap.local_to_map(cat.position)
	print(cat_tile)
	
	# TODO: draw lower layers first
	# TODO: need diags
	#cat_tile = Vector2i(0,-14)
	#cat_tile = Vector2i(5,-33)
	
	var cat_layer = cat.get_layer()
	#cat_layer = 2
	#print(cat_layer)
	
	
	var start_tile = cat_tile
	#start_tile.y -= 2
	
	
	var base_tile= start_tile
	base_tile.y += 1
	var even_y = true
	if start_tile.y % 2 != 0:
		even_y = false
	
	var calc_tile
	
	# draw the full layer of layers below the character
	for layer in range(0, cat_layer):
		temp_tile_collection_2.append([])
		draw_full_layer(layer, temp_tile_collection_1[layer])

	if draw_step > 1:
		for layer in range(cat_layer, layer_count):
			temp_tile_collection_2.append([])
			
			for tile in temp_tile_collection_1[layer]:
				if (even_y == true):
					calc_tile = base_tile
				else: # even_tile = false
					calc_tile = start_tile
					calc_tile.x += 1
				
				if tile.y < (calc_tile.y)+(2*(calc_tile.x-tile.x)):
					draw_tile(layer, tile)
					
					var test
					if even_y:
						if tile.x <= cat_tile.x:
							test = floor((cat_tile.y-1 - tile.y) / 2)
						else:
							test = floor((cat_tile.y - tile.y) / 2)
					else:
						if tile.x <= cat_tile.x:
							test = floor((cat_tile.y - tile.y) / 2)
						else:
							test = floor(((cat_tile.y+1) - tile.y) / 2)
					
					if ((cat_tile.x + test) == tile.x) and tile.x > cat_tile.x:
						#print(tile)
						# this tile is in the lowest row so lets draw stuff connected to it
						# find the next tile down which is attached
						var lower_tile = tile
						lower_tile.y += 1
						if tile.y % 2 != 0:
							lower_tile.x += 1
							
						while temp_tile_collection_1[layer].has(lower_tile):
							# this tile exists
							extra_tiles.append(tile)
							draw_tile(layer, lower_tile)
							if lower_tile.y % 2 != 0:
								lower_tile.x += 1
							lower_tile.y += 1
				
				else:
					if extra_tiles.has(tile) == false:
					
						temp_tile_collection_2[layer].append(tile)
	
	if draw_step > 2:
		var txt = cat.get_node("Sprite2D").get_texture()
		draw_texture_rect(txt, Rect2(cat.position.x-16, cat.position.y-32, 32, 32), false)
	
	if draw_step > 3:
		
		for layer in range(cat_layer, layer_count):
			
			for tile in temp_tile_collection_2[layer]:
				if (even_y == true):
					#if (tile.x < start_tile.x):
					calc_tile = base_tile
					#else:
						#calc_tile = start_tile
						#calc_tile.x -= 1
				else: # even_tile = false
					#if (tile.x > base_tile.x):
						#calc_tile = base_tile
						#
					#else:
					calc_tile = start_tile
					calc_tile.x += 1
				
				if tile.y >= (calc_tile.y-(layer * 2))+(2*(calc_tile.x-tile.x)):
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


func draw_triangle_surround():
	var temp_tile_collection_1 = map_layer_collection.duplicate(true)
	var temp_tile_collection_2 = []
	var extra_tiles = []
	
	# get the tile coords of the cat
	var cat_tile = tilemap.local_to_map(cat.position)
	# the coords are the tile that is in the layer the cat is standing on, we need it to be the tile that it is standing in
	# rather than the tile below it, so the y position is 2 lower
	cat_tile.y -= 2
	
	# get the layer the cat is within - if the cat is on a ramp or stairs then this will be the layer above the stairs
	# so they are drawn below it
	var cat_layer = cat.get_layer()
	
	
	# these are set for testing the drawing
	#cat_tile = Vector2i(-1,-21)
	#cat_layer = 1
	
	
	
	var base_tile= cat_tile
	base_tile.y += 1
	var even_y = true
	if cat_tile.y % 2 != 0:
		even_y = false
	
	var calc_tile

	# draw the full layer of layers below the character
	for layer in range(0, cat_layer):
		temp_tile_collection_2.append([])
		draw_full_layer(layer, temp_tile_collection_1[layer])
	
	if draw_step > 1:
		for layer in range(cat_layer, layer_count):
			temp_tile_collection_2.append([])
			for tile in temp_tile_collection_1[layer]:
				if (even_y == true):
					if (tile.x < cat_tile.x):
						calc_tile = base_tile
						#calc_tile.y -= 1
						calc_tile.x -= 1
					else:
						calc_tile = cat_tile
				else: # even_tile = false
					if (tile.x > base_tile.x):
						calc_tile = base_tile
						calc_tile.x += 1
					else:
						calc_tile = cat_tile
				
				if (layer == cat_layer) and (tile == cat_tile):
					draw_tile(layer, tile)
				
				elif tile.y < (calc_tile.y-((layer-cat_layer)*2))+(2*abs(calc_tile.x-tile.x)):
					draw_tile(layer, tile)
				
				else:
					temp_tile_collection_2[layer].append(tile)
	
	if draw_step > 2:
		var txt = cat.get_node("Sprite2D").get_texture()
		draw_texture_rect(txt, Rect2(cat.position.x-8, cat.position.y-16, 16, 16), false)
	
	if draw_step > 3:
		# TODO: offset y can be layer * 2
		
		for layer in range(cat_layer, layer_count):
			
			for tile in temp_tile_collection_2[layer]:
				draw_tile(layer, tile)

func draw_back_triangle():
	var temp_tile_collection = map_layer_collection.duplicate(true)
	
	var cat_tile = tilemap.local_to_map(cat.position)
	
	# TODO: draw lower layers first
	# TODO: need diags
	cat_tile = Vector2i(-1,-19)
	print(cat_tile)
	var cat_layer = 0
	
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
		draw_tile(layer, tile)


func draw_tile(layer:int, tile:Vector2i) -> void:
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


