extends Node2D

# these are the values that are defined in the custom data layer ("tile_type") of the tileset
# tells the code which function is used to draw the nav mesh for that tile
enum { TILE_FLAT=0, TILE_RAMP_NE=1, TILE_RAMP_SE=2, TILE_RAMP_SW=3, TILE_RAMP_NW=4 }

@onready var tilemap = $CustomTileMap
@onready var cat = $Cat

const LAYER_HEIGHT:int = 16

var layer_count:int # number of layers in the tile map
var map_layer_collection:Dictionary # stores the tile data for each layer

var nav_map # navigation map that we will create

func _ready():
	generate_nav_mesh()
	cat.map = nav_map
	cat.game = self
	$CustomTileMap.set_cat(cat)
	cat.tilemap = $CustomTileMap
	$Label.set_text("4")
	tilemap.label = $Label


func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == 1 and event.pressed == true:
			var global_mouse = get_global_mouse_position()
			var clicked_tile = tilemap.tilemap.local_to_map(global_mouse) # map coordinate of tile
			
			# go through the layers from top to bottom until we find a layer which has a tile at the clicked position
			for layer_id in range(layer_count-1, -1, -1):
				if map_layer_collection[layer_id].has(clicked_tile):
					# turn the clicked 2D position in to a 3D position
					var clicked_pos3D = Vector3(global_mouse.x, layer_id*LAYER_HEIGHT, global_mouse.y)
					# get the 3D position of the character
					var character_pos3D = cat.get_pos3D()
					# get the path from the NavigationServer3D
					var path:PackedVector3Array = NavigationServer3D.map_get_path(nav_map, character_pos3D, clicked_pos3D, true)
					# pass the path to the character
					cat.set_path(path)
					tilemap.queue_redraw()
					break


func generate_nav_mesh():
	var new_mesh:NavigationMesh = NavigationMesh.new()
	
	layer_count = tilemap.tilemap.get_layers_count()
	map_layer_collection = {}
	
	# get the tile map data for each layer and store in map_collection_layer
	for layer_id in range(layer_count):
		map_layer_collection[layer_id] = tilemap.tilemap.get_used_cells(layer_id)
	print(map_layer_collection.keys())
	
	for layer_id in range(layer_count):
		# go through each tile in the layer
		for tile in map_layer_collection[layer_id]:
			
			# need to check if there is a tile above this tile, if so don't add it to the nav mesh
			if layer_id+1 < layer_count:
				# the tile above this tile will have the same x coord but the y coord will be 2 smaller
				var stacked_tile = tile
				stacked_tile.y -= 2
				
				if map_layer_collection[layer_id+1].has(stacked_tile):
					# there is a tile above this one so move to next one
					continue
			
			# get the "tile_type" of the current tile so we know how to create it
			var tile_data = tilemap.tilemap.get_cell_tile_data(layer_id, tile)
			var tile_type = tile_data.get_custom_data("tile_type")
			
			match tile_type:
				0: #flat
					add_flat_polygons(tile, layer_id, new_mesh)
				
				1: # NE ramp
					add_ne_ramp_polygons(tile, layer_id, new_mesh)
				
				2: # SE ramp
					add_se_ramp_polygons(tile, layer_id, new_mesh)
				
				3: # SW ramp
					add_sw_ramp_polygons(tile, layer_id, new_mesh)
				
				4: # NW ramp
					add_nw_ramp_polygons(tile, layer_id, new_mesh)
	
	# save the nav mesh - only done so it can be viewed outside of the program for debug purposes
	var save_result = ResourceSaver.save(new_mesh, "nav_mesh.tres", 1)
	print("Nav mesh save result: %s" % save_result)
	
	# create a new navigation map
	nav_map = NavigationServer3D.map_create()
	
	# create a new navigation region and add the mesh to it, then add the region to the map
	var new_region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_navigation_mesh(new_region, new_mesh)
	NavigationServer3D.region_set_map(new_region, nav_map)
	
	# make the new map the active map
	NavigationServer3D.map_set_active(nav_map, true)



func add_flat_polygons(tile:Vector2i, layer:int, mesh:NavigationMesh):
	# get the array of vertices from the nav mesh
	var vertices:PackedVector3Array = mesh.get_vertices()
	
	# calculate the coordinates of the four vertices
	var v1:Vector3
	var v2:Vector3
	var v3:Vector3
	var v4:Vector3
	
	# because of the way the isometric tile map is laid out, the position of the tiles can vary depending on
	# whether the coords are odd or even
	if tile.y % 2 == 0:
		v1 = Vector3( (tile[0]*32), layer*LAYER_HEIGHT, 8+((tile[1])*8) ) # left
		v2 = Vector3( 16+(tile[0]*32), layer*LAYER_HEIGHT, ((tile[1])*8) ) # top
		v3 = Vector3( ((tile[0]+1)*32), layer*LAYER_HEIGHT, 8+((tile[1])*8) ) # right
		v4 = Vector3( 16+(tile[0]*32), layer*LAYER_HEIGHT, 16+((tile[1])*8) ) # bottom
	else:
		v1 = Vector3( 16+(tile[0]*32), layer*LAYER_HEIGHT, 8+((tile[1])*8) ) # left
		v2 = Vector3( 32+(tile[0]*32), layer*LAYER_HEIGHT, ((tile[1])*8) ) # top
		v3 = Vector3( 16+((tile[0]+1)*32), layer*LAYER_HEIGHT, 8+((tile[1])*8) ) # right
		v4 = Vector3( 32+(tile[0]*32), layer*LAYER_HEIGHT, 16+((tile[1])*8) ) # bottom
	
	# this ugly section checks if the vertices already exist in the nav mesh vertices array
	# if the don't exist then we add them
	var a = vertices.find(v1)
	if a == -1:
		vertices.append(v1)
	
	a = vertices.find(v2)
	if a == -1:
		vertices.append(v2)
	
	a = vertices.find(v3)
	if a == -1:
		vertices.append(v3)
	
	a = vertices.find(v4)
	if a == -1:
		vertices.append(v4)
	
	# we set the updated vertices array to the nav mesh
	mesh.set_vertices(vertices)
	# we now add the two polygons that make up this tile, they are defined using the indexes of the vertices
	# so we find the index for each value we want to use from the vertcies array
	mesh.add_polygon(PackedInt32Array([vertices.find(v1), vertices.find(v2), vertices.find(v3)]))
	mesh.add_polygon(PackedInt32Array([vertices.find(v1), vertices.find(v3), vertices.find(v4)]))





func add_ne_ramp_polygons(tile:Vector2i, layer:int, mesh:NavigationMesh):
	# this funtion is similar to the above with a few chnages
	var vertices:PackedVector3Array = mesh.get_vertices()
	
	var v1:Vector3
	var v2:Vector3
	var v3:Vector3
	var v4:Vector3
	
	# the top and right vertices of this tile will be in the same position as the left and bottom vertices of the tile
	# this ramp connects to, so we find the tile that this ramp connects to on the lower layer
	var lower_tile = Vector2i()
	lower_tile.x = tile.x
	lower_tile.y = tile.y + 1
	if tile.y % 2 != 0:
		lower_tile.x += 1
	
	# the left and bottom vertices depend on whether the y coordinate is odd or even as with the flat tile function
	if tile.y % 2 == 0:
		v1 = Vector3( (tile[0]*32), layer*LAYER_HEIGHT, 8+((tile[1])*8) ) # left
		v4 = Vector3( 16+(tile[0]*32), layer*LAYER_HEIGHT, 16+((tile[1])*8) ) # bottom
	else:
		v1 = Vector3( 16+(tile[0]*32), layer*LAYER_HEIGHT, 8+((tile[1])*8) ) # left
		v4 = Vector3( 32+(tile[0]*32), layer*LAYER_HEIGHT, 16+((tile[1])*8) ) # bottom
	
	# the left and bottom vertices depend on whether the y coordinate is odd or even as with the flat tile function
	if lower_tile.y % 2 == 0:
		v2 = Vector3( (lower_tile[0]*32), (layer-1)*LAYER_HEIGHT, 8+((lower_tile[1])*8) ) # top (copied from flat left)
		v3 = Vector3( 16+(lower_tile[0]*32), (layer-1)*LAYER_HEIGHT, 16+((lower_tile[1])*8) ) # right (copied from flat bottom)
	else:
		v2 = Vector3( 16+(lower_tile[0]*32), (layer-1)*LAYER_HEIGHT, 8+((lower_tile[1])*8) ) # top (copied from flat left)
		v3 = Vector3( 32+(lower_tile[0]*32), (layer-1)*LAYER_HEIGHT, 16+((lower_tile[1])*8) ) # right (copied from flat bottom)
	
	var a = vertices.find(v1)
	if a == -1:
		vertices.append(v1)
	
	a = vertices.find(v2)
	if a == -1:
		vertices.append(v2)
	
	a = vertices.find(v3)
	if a == -1:
		vertices.append(v3)
		
	a = vertices.find(v4)
	if a == -1:
		vertices.append(v4)
	
	mesh.set_vertices(vertices)
	mesh.add_polygon(PackedInt32Array([vertices.find(v1), vertices.find(v2), vertices.find(v3)]))
	mesh.add_polygon(PackedInt32Array([vertices.find(v1), vertices.find(v3), vertices.find(v4)]))



func add_se_ramp_polygons(tile:Vector2i, layer:int, mesh:NavigationMesh):
	# this funtion is similar to the above with a few chnages
	var vertices:PackedVector3Array = mesh.get_vertices()
	
	var v1:Vector3
	var v2:Vector3
	var v3:Vector3
	var v4:Vector3
	
	# the right and bottom vertices of this tile will be in the same position as the top and left vertices of the tile
	# this ramp connects to, so we find the tile that this ramp connects to on the lower layer
	var lower_tile = Vector2i()
	lower_tile.x = tile.x
	lower_tile.y = tile.y + 3
	if tile.y % 2 != 0:
		lower_tile.x += 1
	
	# the top and left vertices depend on whether the y coordinate is odd or even as with the flat tile function
	if tile.y % 2 == 0:
		v1 = Vector3( (tile[0]*32), layer*LAYER_HEIGHT, 8+((tile[1])*8) ) # left
		v2 = Vector3( 16+(tile[0]*32), layer*LAYER_HEIGHT, ((tile[1])*8) ) # top
	else:
		v1 = Vector3( 16+(tile[0]*32), layer*LAYER_HEIGHT, 8+((tile[1])*8) ) # left
		v2 = Vector3( 32+(tile[0]*32), layer*LAYER_HEIGHT, ((tile[1])*8) ) # top
	
	# the right and bottom vertices depend on whether the lower tile is odd or even
	if lower_tile.y % 2 == 0:
		v3 = Vector3( 16+(lower_tile[0]*32), (layer-1)*LAYER_HEIGHT, ((lower_tile[1])*8) ) # right (copied from flat top)
		v4 = Vector3( (lower_tile[0]*32), (layer-1)*LAYER_HEIGHT, 8+((lower_tile[1])*8) ) # bottom (copied from flat left)
	else:
		v3 = Vector3( 32+(lower_tile[0]*32), (layer-1)*LAYER_HEIGHT, ((lower_tile[1])*8) ) # right (copied from flat top)
		v4 = Vector3( 16+(lower_tile[0]*32), (layer-1)*LAYER_HEIGHT, 8+((lower_tile[1])*8) )  # bottom (copied from flat left)
	
	var a = vertices.find(v1)
	if a == -1:
		vertices.append(v1)
	
	a = vertices.find(v2)
	if a == -1:
		vertices.append(v2)
	
	a = vertices.find(v3)
	if a == -1:
		vertices.append(v3)
		
	a = vertices.find(v4)
	if a == -1:
		vertices.append(v4)
	
	mesh.set_vertices(vertices)
	mesh.add_polygon(PackedInt32Array([vertices.find(v1), vertices.find(v2), vertices.find(v3)]))
	mesh.add_polygon(PackedInt32Array([vertices.find(v1), vertices.find(v3), vertices.find(v4)]))


func add_sw_ramp_polygons(tile:Vector2i, layer:int, mesh:NavigationMesh):
	# this funtion is similar to the above with a few chnages
	var vertices:PackedVector3Array = mesh.get_vertices()
	
	var v1:Vector3
	var v2:Vector3
	var v3:Vector3
	var v4:Vector3
	
	# the left and bottom vertices of this tile will be in the same position as the top and right vertices of the tile
	# this ramp connects to, so we find the tile that this ramp connects to on the lower layer
	var lower_tile = Vector2i()
	lower_tile.x = tile.x
	lower_tile.y = tile.y + 3
	if tile.y % 2 == 0:
		lower_tile.x -= 1
	
	# the top and right vertices depend on whether the y coordinate is odd or even as with the flat tile function
	if tile.y % 2 == 0:
		v2 = Vector3( 16+(tile[0]*32), layer*LAYER_HEIGHT, ((tile[1])*8) ) # top
		v3 = Vector3( ((tile[0]+1)*32), layer*LAYER_HEIGHT, 8+((tile[1])*8) ) # right
	else:
		v2 = Vector3( 32+(tile[0]*32), layer*LAYER_HEIGHT, ((tile[1])*8) ) # top
		v3 = Vector3( 16+((tile[0]+1)*32), layer*LAYER_HEIGHT, 8+((tile[1])*8) ) # right
	
	# the left and bottom vertices depend on whether the lower tile is odd of even
	if lower_tile.y % 2 == 0:
		v1 = Vector3( 16+(lower_tile[0]*32), (layer-1)*LAYER_HEIGHT, ((lower_tile[1])*8) ) # left (copied from flat top)
		v4 = Vector3( ((lower_tile[0]+1)*32), (layer-1)*LAYER_HEIGHT, 8+((lower_tile[1])*8) ) # bottom (copied from flat right)
	else:
		v1 = Vector3( 32+(lower_tile[0]*32), (layer-1)*LAYER_HEIGHT, ((lower_tile[1])*8) ) # left (copied from flat top)
		v4 = Vector3( 16+((lower_tile[0]+1)*32), (layer-1)*LAYER_HEIGHT, 8+((lower_tile[1])*8) ) # bottom copied from flat right)
	
	var a = vertices.find(v1)
	if a == -1:
		vertices.append(v1)
	
	a = vertices.find(v2)
	if a == -1:
		vertices.append(v2)
	
	a = vertices.find(v3)
	if a == -1:
		vertices.append(v3)
		
	a = vertices.find(v4)
	if a == -1:
		vertices.append(v4)
	
	mesh.set_vertices(vertices)
	mesh.add_polygon(PackedInt32Array([vertices.find(v1), vertices.find(v2), vertices.find(v3)]))
	mesh.add_polygon(PackedInt32Array([vertices.find(v1), vertices.find(v3), vertices.find(v4)]))


func add_nw_ramp_polygons(tile:Vector2i, layer:int, mesh:NavigationMesh):
	# this funtion is similar to the above with a few chnages
	var vertices:PackedVector3Array = mesh.get_vertices()
	
	var v1:Vector3
	var v2:Vector3
	var v3:Vector3
	var v4:Vector3
	
	# the left and bottom vertices of this tile will be in the same position as the top and right vertices of the tile
	# this ramp connects to, so we find the tile that this ramp connects to on the lower layer
	var lower_tile = Vector2i()
	lower_tile.x = tile.x
	lower_tile.y = tile.y + 1
	if tile.y % 2 == 0:
		lower_tile.x -= 1
	
	# the right and bottom vertices depend on whether the y coordinate is odd or even as with the flat tile function
	if tile.y % 2 == 0:
		v3 = Vector3( ((tile[0]+1)*32), layer*LAYER_HEIGHT, 8+((tile[1])*8) ) # right
		v4 = Vector3( 16+(tile[0]*32), layer*LAYER_HEIGHT, 16+((tile[1])*8) ) # bottom
	else:
		v3 = Vector3( 16+((tile[0]+1)*32), layer*LAYER_HEIGHT, 8+((tile[1])*8) ) # right
		v4 = Vector3( 32+(tile[0]*32), layer*LAYER_HEIGHT, 16+((tile[1])*8) ) # bottom
	
	# the left and top vertices depend on whether the lower tile is odd of even
	# l = b, t = r
	if lower_tile.y % 2 == 0:
		v1 = Vector3( 16+(lower_tile[0]*32), (layer-1)*LAYER_HEIGHT, 16+((lower_tile[1])*8) ) # left (copied from flat bottom)
		v2 = Vector3( ((lower_tile[0]+1)*32), (layer-1)*LAYER_HEIGHT, 8+((lower_tile[1])*8) ) # top (copied from flat right)
	else:
		v1 = Vector3( 32+(lower_tile[0]*32), (layer-1)*LAYER_HEIGHT, 16+((lower_tile[1])*8) ) # left (copied from flat bottom)
		v2 = Vector3( 16+((lower_tile[0]+1)*32), (layer-1)*LAYER_HEIGHT, 8+((lower_tile[1])*8) ) # top (copied from flat right)
	
	var a = vertices.find(v1)
	if a == -1:
		vertices.append(v1)
	
	a = vertices.find(v2)
	if a == -1:
		vertices.append(v2)
	
	a = vertices.find(v3)
	if a == -1:
		vertices.append(v3)
		
	a = vertices.find(v4)
	if a == -1:
		vertices.append(v4)
	
	mesh.set_vertices(vertices)
	mesh.add_polygon(PackedInt32Array([vertices.find(v1), vertices.find(v2), vertices.find(v3)]))
	mesh.add_polygon(PackedInt32Array([vertices.find(v1), vertices.find(v3), vertices.find(v4)]))
