extends Node2D

@onready var tilemap:TileMap = $TileMap
@onready var navigation_links:Node2D = $NavigationLinks

var steps = [ "", "Draw base layer only.", "Draw base layer and area behind character.", "Draw base layer, area behind character, and character.", "Draw everything." ]

var tileset:TileSet

var layer_count:int # number of layers in the tile map
var map_layer_collection:Dictionary # stores the tile data for each layer

var cat
var d = true

var draw_step = 4
var label

################
## Navmesh variables
################

const LAYER_HEIGHT:int = 16

enum { LEFT_VERTEX=0, TOP_VERTEX, RIGHT_VERTEX, BOTTOM_VERTEX }

enum EdgeType { STANDARD, INDENTED }

enum { TILE_RAMP_NW=0, TILE_RAMP_NE=1, TILE_RAMP_SE=2, TILE_RAMP_SW=3, TILE_FLAT=4 }

enum { NW_EDGE=0, NE_EDGE, SE_EDGE, SW_EDGE }
enum { N_CORNER=0, S_CORNER, E_CORNER, W_CORNER }

var ramp_type:Array[Array] = [ [3, 1], [0, 2], [3, 1], [0, 2] ]

var adjacent_tiles_even:Array[Vector2i] = [  Vector2i(-1,-1), Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,1) ]
var adjacent_tiles_odd:Array[Vector2i] = [  Vector2i(0,-1), Vector2i(1,-1), Vector2i(1,1), Vector2i(0,1) ]
var adjacent_tiles:Array[Array] = [adjacent_tiles_even, adjacent_tiles_odd]

# these are both in the same order as the corner enum values - N S E W
var corner_vectors:Array[Vector2i] = [  Vector2i(0,-2), Vector2i(0,2), Vector2i(1,0), Vector2i(-1,0) ] # N, S, E, W
var corner_sides:Array[Array] = [ [NW_EDGE, NE_EDGE], [SE_EDGE, SW_EDGE], [NE_EDGE, SE_EDGE], [NW_EDGE, SW_EDGE] ]

var opposite_ramp:Array[int] = [ TILE_RAMP_SE, TILE_RAMP_SW, TILE_RAMP_NW, TILE_RAMP_NE ]
var opposite_edge:Array[int] = [ SE_EDGE, SW_EDGE, NW_EDGE, NE_EDGE ]

var navigation_map:RID # navigation map that we will create


func _ready():
	# first we generate the 3D nav mesh
	generate_nav_mesh(true, "saved_navmesh.tres")
	NavigationServer2D.map_force_update(navigation_map)
	# now get the navigation links and add them to NavigationServer3D
	add_navigation_links()
	
	#drawing stuff
	tilemap.hide()
	tileset = tilemap.tile_set
	$Entities/Cat.hide()

func _draw():
	##draw_back_triangle()
	#draw_triangle_surround()
	new_draw_with_stairs()

func _input(event):
	if event.is_action_released("ui_end"):
		if d:
			d = false
		else:
			d=true
	
	if event.is_action_released("ui_page_down"):
		draw_step = draw_step + 1
		if draw_step == 5:
			draw_step = 1
		label.set_text(steps[draw_step])
		queue_redraw()
	
	if event.is_action_released("ui_right"):
		print(cat.character_vertical_position)
		print(cat.get_layer())
	
	if event.is_action_released("ui_home"):
		print(cat.get_layer())
		print(tilemap.local_to_map(cat.position))
	
	if event is InputEventMouseButton:
		if event.button_index == 1 and event.pressed == true:
			var global_mouse = get_global_mouse_position()
			var clicked_tile = tilemap.local_to_map(global_mouse) # map coordinate of tile
			
			# go through the layers from top to bottom until we find a layer which has a tile at the clicked position
			for layer_id in range(layer_count-1, -1, -1):
				if map_layer_collection[layer_id].has(clicked_tile):
					# turn the clicked 2D position in to a 3D position
					var clicked_pos3D = Vector3(global_mouse.x, layer_id*LAYER_HEIGHT, global_mouse.y)
					# get the 3D position of the character
					var character_pos3D = cat.get_pos3D()
					# get the path from the NavigationServer3D
					var path:PackedVector3Array = NavigationServer3D.map_get_path(navigation_map, character_pos3D, clicked_pos3D, true)
					# pass the path to the character
					cat.set_path(path)
					queue_redraw()
					break





func set_cat(c):
	cat = c
	cat.map = navigation_map
	#cat.get_node("Sprite2D").hide()




# takes a 3D vector and returns the x and z coords as a 2D vector
func V3_to_V2(v3:Vector3):
	var v2 = Vector2()
	v2.x = v3.x
	v2.y = v3.z
	return v2

######################################
##
## Navmesh Functions
##
######################################


# Entry point for navmesh generation
func generate_nav_mesh(save_navmesh:bool=false, navmesh_filename:String="saved_navmesh.tres") -> void:
	var new_mesh:NavigationMesh = NavigationMesh.new()
	
	layer_count = tilemap.get_layers_count()
	
	# get the tile map data for each layer and store in map_collection_layer
	map_layer_collection = {}
	for layer:int in range(layer_count):
		map_layer_collection[layer] = tilemap.get_used_cells(layer)
		# sort the layer collection by y - for use in drawing functions
		map_layer_collection[layer].sort_custom(sort_y_low_to_high)
	
	for layer in range(layer_count):
		# go through each tile in the layer
		for tile in map_layer_collection[layer]:
			# need to check if there is a tile above this tile, if so don't add it to the nav mesh as it will be blocked
			if layer+1 < layer_count:
				# the tile above this tile will have the same x coord but the y coord will be 2 smaller
				var stacked_tile:Vector2i = tile
				stacked_tile.y -= 2
				
				if map_layer_collection[layer+1].has(stacked_tile):
					# there is a tile above this one so skip it
					continue
			
			# get the "tile_type" of the current tile so we know how to create it
			var tile_data:TileData = tilemap.get_cell_tile_data(layer, tile)
			var tile_type:int = tile_data.get_custom_data("tile_type")
			
			create_tile_polygon(tile, layer, new_mesh, tile_type)
	
	# save the nav mesh if required
	if save_navmesh:
		var save_result:Error = ResourceSaver.save(new_mesh, navmesh_filename, 1)
		print("Nav mesh save result: %s" % save_result)
	
	# create a new navigation map
	navigation_map = NavigationServer3D.map_create()
	
	# create a new navigation region and add the mesh to it, then add the region to the map
	var new_region:RID = NavigationServer3D.region_create()
	NavigationServer3D.region_set_navigation_mesh(new_region, new_mesh)
	NavigationServer3D.region_set_map(new_region, navigation_map)
	
	# make the new map the active map
	NavigationServer3D.map_set_active(navigation_map, true)


# Creates a polygon for a tile
func create_tile_polygon(tile:Vector2i, layer:int, navmesh:NavigationMesh, tile_type:int) -> void:
	# get the array of vertices from the navmesh
	var navmesh_vertices:PackedVector3Array = navmesh.get_vertices()
	
	var tile_data:Dictionary = {}
	# calculate the vertices for the tile
	if tile_type == TILE_FLAT:
		tile_data = calculate_tile_vertices_flat(tile, layer)
	else:
		tile_data = calculate_tile_vertices_ramp(tile, layer, tile_type)
	
	var tile_vertices:PackedVector3Array = tile_data["vertices"]
	var tile_directions:Array[Vector2i] = tile_data["directions"]
	
	# calculate the triangles for the tile
	var tile_triangles:Array[PackedInt32Array] = calculate_triangles(tile_data)
	
	# this checks if the vertices already exist in navmesh_vertices, if they don't exist we add them
	# we also save the index of the vertex within navmesh_vertices in the vertex_index array
	var vertex_indices:Array = []
	for vertex in tile_vertices:
		var vertex_index = navmesh_vertices.find(vertex)
		if vertex_index == -1:
			# vertex doesn't exist so add it
			vertex_indices.append(navmesh_vertices.size())
			navmesh_vertices.append(vertex)
		else:
			vertex_indices.append(vertex_index)
	
	# we set the updated vertices array to the nav mesh
	navmesh.set_vertices(navmesh_vertices)
	
	# add the triangles - make sure to use the indices stored in vertex_indices as they are the ones in navmesh_vertices
	for triangle:PackedInt32Array in tile_triangles:
		var updated_triangle:PackedInt32Array
		for index:int in triangle:
			updated_triangle.append(vertex_indices[index])
		navmesh.add_polygon(updated_triangle)


# Calculates the vertices for a flat tile
func calculate_tile_vertices_flat(tile:Vector2i, layer:int) -> Dictionary:
	var tile_vertices:PackedVector3Array = []
	var tile_directions:Array[Vector2i] = []
	
	var edge_data:Dictionary = get_edge_margins(tile, layer)
	var edge_types:Array[int] = edge_data["edges"]
	var corner_types:Array[bool] = edge_data["corners"]
	
	# check if the tile y value is even as this affects the x position of the tile
	var even_y:bool = false
	if tile.y % 2 == 0:
		even_y = true
	
	# get the vertices of the tile polygon
	var left_vertex_data:Dictionary = left_vertex_calc(tile, layer, even_y, edge_types[SW_EDGE], edge_types[NW_EDGE], corner_types[W_CORNER])
	tile_vertices.append_array(left_vertex_data["vertices"])
	tile_directions.append_array(left_vertex_data["directions"])
	
	var top_vertex_data:Dictionary = top_vertex_calc(tile, layer, even_y, edge_types[NW_EDGE], edge_types[NE_EDGE], corner_types[N_CORNER])
	tile_vertices.append_array(top_vertex_data["vertices"])
	tile_directions.append_array(top_vertex_data["directions"])
	
	var right_vertex_data:Dictionary = right_vertex_calc(tile, layer, even_y, edge_types[NE_EDGE], edge_types[SE_EDGE], corner_types[E_CORNER])
	tile_vertices.append_array(right_vertex_data["vertices"])
	tile_directions.append_array(right_vertex_data["directions"])
	
	var bottom_vertex_data:Dictionary = bottom_vertex_calc(tile, layer, even_y, edge_types[SE_EDGE], edge_types[SW_EDGE], corner_types[S_CORNER])
	tile_vertices.append_array(bottom_vertex_data["vertices"])
	tile_directions.append_array(bottom_vertex_data["directions"])
	
	return { "vertices": tile_vertices, "directions": tile_directions }


# Calculates the vertices for a ramp tile
func calculate_tile_vertices_ramp(tile:Vector2i, layer:int, ramp_direction:int) -> Dictionary:
	var tile_vertices:PackedVector3Array = []
	var tile_directions:Array[Vector2i] = []
	
	var edge_data:Dictionary = get_edge_margins_ramp(tile, layer, ramp_direction)
	var edge_types:Array[int] = edge_data["edges"]
	var corner_types:Array[bool] = edge_data["corners"]
	
	# check if the tile y value is even as this affects the x position of the tile
	var even_y:bool = false
	if tile.y % 2 == 0:
		even_y = true
	
	# bottom of ramp has 2 vertices which are on the layer below so we work out which they are and save the info in
	# arrays which we will pass to the functions that calculate the vertices
	var corner_layers:Array[int] = [layer, layer, layer, layer]
	var tile_coords:Array[Vector2i] = [tile, tile, tile, tile]
	
	match ramp_direction:
		TILE_RAMP_NE:
			corner_layers[LEFT_VERTEX] -= 1
			corner_layers[BOTTOM_VERTEX] -= 1
			tile_coords[LEFT_VERTEX].y += 2
			tile_coords[BOTTOM_VERTEX].y += 2
		
		TILE_RAMP_NW:
			corner_layers[RIGHT_VERTEX] -= 1
			corner_layers[BOTTOM_VERTEX] -= 1
			tile_coords[RIGHT_VERTEX].y += 2
			tile_coords[BOTTOM_VERTEX].y += 2
		
		TILE_RAMP_SE:
			corner_layers[LEFT_VERTEX] -= 1
			corner_layers[TOP_VERTEX] -= 1
			tile_coords[LEFT_VERTEX].y += 2
			tile_coords[TOP_VERTEX].y += 2
		
		TILE_RAMP_SW:
			corner_layers[RIGHT_VERTEX] -= 1
			corner_layers[TOP_VERTEX] -= 1
			tile_coords[RIGHT_VERTEX].y += 2
			tile_coords[TOP_VERTEX].y += 2
	
	# get the vertices of the tile polygon
	var left_vertex_data:Dictionary = left_vertex_calc(tile_coords[LEFT_VERTEX], corner_layers[LEFT_VERTEX], even_y, edge_types[SW_EDGE], edge_types[NW_EDGE], corner_types[W_CORNER])
	tile_vertices.append_array(left_vertex_data["vertices"])
	tile_directions.append_array(left_vertex_data["directions"])
	
	var top_vertex_data:Dictionary = top_vertex_calc(tile_coords[TOP_VERTEX], corner_layers[TOP_VERTEX], even_y, edge_types[NW_EDGE], edge_types[NE_EDGE], corner_types[N_CORNER])
	tile_vertices.append_array(top_vertex_data["vertices"])
	tile_directions.append_array(top_vertex_data["directions"])
	
	var right_vertex_data:Dictionary = right_vertex_calc(tile_coords[RIGHT_VERTEX], corner_layers[RIGHT_VERTEX], even_y, edge_types[NE_EDGE], edge_types[SE_EDGE], corner_types[E_CORNER])
	tile_vertices.append_array(right_vertex_data["vertices"])
	tile_directions.append_array(right_vertex_data["directions"])
	
	var bottom_vertex_data:Dictionary = bottom_vertex_calc(tile_coords[BOTTOM_VERTEX], corner_layers[BOTTOM_VERTEX], even_y, edge_types[SE_EDGE], edge_types[SW_EDGE], corner_types[S_CORNER])
	tile_vertices.append_array(bottom_vertex_data["vertices"])
	tile_directions.append_array(bottom_vertex_data["directions"])
	
	return { "vertices": tile_vertices, "directions": tile_directions }


# Works out which edges need a margin
# TODO: Clean up!
func get_edge_margins(tile:Vector2i, layer:int) -> Dictionary:

	var edge_types:Array[int]
	for i in range(4):
		edge_types.append(EdgeType.STANDARD)
	
	var corner_blocked:Array[bool]
	for i in range(4):
		corner_blocked.append(false)
	
	# tells us which of the two adjacent tile arrays we should use to find the adjacent edge tiles.
	# will be 0 for even or 1 for odd
	var adjacent_tile_array:int = tile.y % 2
	
	# go through the flat edges
	for i:int in range(adjacent_tiles[adjacent_tile_array].size()):
		# calculate the tile coordinate of the adjacent tile
		var test_tile:Vector2i = tile + adjacent_tiles[adjacent_tile_array][i]
		# check if the tiles exists
		if map_layer_collection[layer].has(test_tile):
			# tile exists so check if it is blocked by checking the tile above it
			if layer+1 < layer_count:
				# tile we are checking will have a y value 2 lower as it is in above layer
				var test_tile_above:Vector2i = test_tile
				test_tile_above.y -= 2
				if map_layer_collection[layer+1].has(test_tile_above):
					# has a stacked tile so need to add margin
					var tile_data:TileData = tilemap.get_cell_tile_data(layer+1, test_tile_above)
					var tile_type:int = tile_data.get_custom_data("tile_type")
					if tile_type == TILE_FLAT:
						# normal flat tile
						edge_types[i] = EdgeType.INDENTED
					else:
						# ramp so check if it's facing this edge - if not indent it
						if tile_type != i:
							edge_types[i] = EdgeType.INDENTED
				else:
					# doesn't have stacked tile so now need to check if it's a ramp
					var tile_data:TileData = tilemap.get_cell_tile_data(layer, test_tile)
					var tile_type:int = tile_data.get_custom_data("tile_type")
					if tile_type == TILE_FLAT:
						# flat tile so don't do anything
						pass
					else:
						# ramp tile so is it conencting? on same layer so it needs to be opposite direction
						if tile_type != opposite_ramp[i]:
							edge_types[i] = EdgeType.INDENTED
			else: # SAME AS SECTION ABOVE IF NO TILE ABOVE
				# doesn't have stacked tile so now need to check if it's a ramp
				var tile_data:TileData = tilemap.get_cell_tile_data(layer, test_tile)
				var tile_type:int = tile_data.get_custom_data("tile_type")
				if tile_type == TILE_FLAT:
					# flat tile so don't do anything
					pass
				else:
					# ramp tile so is it conencting? on same layer so it needs to be opposite direction
					if tile_type != opposite_ramp[i]:
						edge_types[i] = EdgeType.INDENTED
		
		else:
			# tile doesn't exist but check if the tile above is a ramp as then we still need to connect
			if layer+1 < layer_count:
				# tile we are checking will have a y value 2 lower as it is in above layer
				test_tile.y -= 2
				if map_layer_collection[layer+1].has(test_tile):
					# has a stacked tile so need to add margin
					var tile_data:TileData = tilemap.get_cell_tile_data(layer+1, test_tile)
					var tile_type:int = tile_data.get_custom_data("tile_type")
					if tile_type == TILE_FLAT:
						# not ramp so indent
						edge_types[i] = EdgeType.INDENTED
					else:
						# ramp so check if it's facing this edge - if not indent it
						if tile_type != i:
							edge_types[i] = EdgeType.INDENTED
				else:
					# no tile above so need to indent stil
					edge_types[i] = EdgeType.INDENTED
			else:
				# top layer so no ramp above and indent
				edge_types[i] = EdgeType.INDENTED
	if (tile == Vector2i(0,-1) and layer == 1):
		print(edge_types)
	# Go through the corners to see if the tile needs a corner wedge
	for i:int in range(corner_vectors.size()):
		var test_tile:Vector2i = tile + corner_vectors[i]
		if map_layer_collection[layer].has(test_tile):
			#tile exists so check if it is blocked
			if layer+1 < layer_count:
				var test_tile_above:Vector2i = test_tile
				test_tile_above.y -= 2
				if map_layer_collection[layer+1].has(test_tile_above):
					# has a sstacked tile
					# check if it's a ramp in this direction
					var tile_data:TileData = tilemap.get_cell_tile_data(layer+1, test_tile_above)
					var tile_type:int = tile_data.get_custom_data("tile_type")
					
					if tile_type == TILE_FLAT:
						# tile is a normal flat tile so it's blocked
						
						corner_blocked[i] = true
					else:
						# tile is a ramp so see if its a ramp in the same direction as one connecting to the main tile
						for side:int in corner_sides[i]:
							var rt_test_tile:Vector2i = tile + adjacent_tiles[adjacent_tile_array][side]
							var rt_test_tile_above:Vector2i = rt_test_tile
							rt_test_tile_above.y -= 2
							if map_layer_collection[layer+1].has(rt_test_tile_above):
								# there is a tile in the layer above
								var rt_tile_data_above:TileData = tilemap.get_cell_tile_data(layer+1, rt_test_tile_above)
								var rt_tile_type_above:int = rt_tile_data_above.get_custom_data("tile_type")
								if (rt_tile_type_above == side) and (rt_tile_type_above == tile_type):
									# ramp in same direction as the corner ramp and main tile is connected to the side ramp
									# don't need to block
									pass
								else:
									corner_blocked[i] = true
				else:
					# check if current layer tile is a ramp
					var tile_data:TileData = tilemap.get_cell_tile_data(layer, test_tile)
					var tile_type:int = tile_data.get_custom_data("tile_type")
					if tile_type == TILE_FLAT:
						# test_tile is a flat tile, but if tile is connection to a ramp then the corner will be
						# blocked
						for side:int in corner_sides[i]:
							var rt_test_tile:Vector2i = tile + adjacent_tiles[adjacent_tile_array][side]
							var rt_test_tile_above:Vector2i = rt_test_tile
							rt_test_tile_above.y -= 2
							if (layer+1 < layer_count) and (map_layer_collection[layer+1].has(rt_test_tile_above)):
								var rt_tile_data_above:TileData = tilemap.get_cell_tile_data(layer+1, rt_test_tile_above)
								var rt_tile_type_above:int = rt_tile_data_above.get_custom_data("tile_type")
								if (rt_tile_type_above == side):
									corner_blocked[i] = true
								
							elif map_layer_collection[layer].has(rt_test_tile):
								var rt_tile_data:TileData = tilemap.get_cell_tile_data(layer, rt_test_tile)
								var rt_tile_type:int = rt_tile_data.get_custom_data("tile_type")
								
								if rt_tile_type != TILE_FLAT:
									# the connecting tile is a ramp
									
									if edge_types[side] == EdgeType.STANDARD:
										
										# the ramp must connect to the tile as it isn't indented
										corner_blocked[i] = true
					else:
						
						# see if eithr of the tiles next to the corner are a ramp, and then see if 
						# they are in same direction as the corner tile towards [tile]
						var valid:bool = false
						for side:int in corner_sides[i]:
							var rt_test_tile:Vector2i = tile + adjacent_tiles[adjacent_tile_array][side]
							if map_layer_collection[layer].has(rt_test_tile):
								var rt_tile_data:TileData = tilemap.get_cell_tile_data(layer, rt_test_tile)
								var rt_tile_type:int = rt_tile_data.get_custom_data("tile_type")
								if (rt_tile_type == opposite_edge[side]) and (rt_tile_type == tile_type):
									valid = true
						if valid == false:
							corner_blocked[i] = true
		else:
			# no tile but check if there is a tile above
			# if there is a ramp above then it may be ok
			# check if it's a ramp in this direction
			if layer+1 < layer_count:
				var test_tile_above:Vector2i = test_tile
				test_tile_above.y -= 2
				if map_layer_collection[layer+1].has(test_tile_above):
					var tile_data:TileData = tilemap.get_cell_tile_data(layer+1, test_tile_above)
					var tile_type:int = tile_data.get_custom_data("tile_type")
					
					
					if tile_type == TILE_FLAT:
						# tile is a normal flat tile so it's blocked
						
						corner_blocked[i] = true
					else:
						# tile is a ramp so see if its a ramp in the same direction as one connecting to the main tile
						for side:int in corner_sides[i]:
							var rt_test_tile:Vector2i = tile + adjacent_tiles[adjacent_tile_array][side]
							var rt_test_tile_above:Vector2i = rt_test_tile
							rt_test_tile_above.y -= 2
							if map_layer_collection[layer+1].has(rt_test_tile_above):
								# there is a tile in the layer above
								var rt_tile_data_above:TileData = tilemap.get_cell_tile_data(layer+1, rt_test_tile_above)
								var rt_tile_type_above:int = rt_tile_data_above.get_custom_data("tile_type")
								if (rt_tile_type_above == side) and (rt_tile_type_above == tile_type):
									# ramp in same direction as the corner ramp and main tile is connected to the side ramp
									# don't need to block
									pass
								else:
									corner_blocked[i] = true
				else:
					if tile == Vector2i(0,-1) and layer == 1:
						print("Here")
						# no tile and nothing above but now need to see if it connects to tiles either side
						print(edge_types)
					if edge_types[corner_sides[i][0]] == EdgeType.STANDARD and edge_types[corner_sides[i][1]] == EdgeType.STANDARD:
						if tile == Vector2i(0,-1) and layer == 1:
							print("Blocked")
						corner_blocked[i] = true
			else:
				# no tile and nothing above but now need to see if it connects to tiles either side
				if edge_types[corner_sides[i][0]] == EdgeType.STANDARD and edge_types[corner_sides[i][1]] == EdgeType.STANDARD:
					corner_blocked[i] = true
	
	return { "edges": edge_types, "corners": corner_blocked}


# Works out the edge margins for a ramp, slightly less complicated than a normal tile!
# TODO: Clean up!
func get_edge_margins_ramp(tile:Vector2i, layer:int, ramp_direction:int) -> Dictionary:
	var edge_types:Array[int]
	for i in range(4):
		edge_types.append(EdgeType.STANDARD)
	
	# adding this just to make it compatible with the coordinate functions - will all be false
	var corner_blocked:Array[bool]
	for i in range(4):
		corner_blocked.append(false)
	
	# tells us which of the two adjacent tile arrays we should use to find the adjacent edge tiles.
	# will be 0 for even or 1 for odd
	var adjacent_tile_array:int = tile.y % 2
	var options:Array = ramp_type[ramp_direction]
	
	for i:int in options:
		# calculate the tile coordinate of the adjacent tile
		var test_tile:Vector2i = tile + adjacent_tiles[adjacent_tile_array][i]
		# check if the tiles exists
		if map_layer_collection[layer].has(test_tile):
			# tile exists so check if it is blocked by checking the tile above it
			if layer+1 < layer_count:
				# tile we are checking will have a y value 2 lower as it is in above layer
				var test_tile_above:Vector2i = test_tile
				test_tile_above.y -= 2
				if map_layer_collection[layer+1].has(test_tile_above):
					# has a stacked tile so need to add margin
					edge_types[i] = EdgeType.INDENTED
				else:
					# SAME AS BELOW SECTION "A"
					# top layer (no tile above) so just check if test_tile is a ramp or not
					var test_tile_data:TileData = tilemap.get_cell_tile_data(layer, test_tile)
					var test_tile_type:int = test_tile_data.get_custom_data("tile_type")
					if test_tile_type == TILE_FLAT:
						# tile is flat so indent
						edge_types[i] = EdgeType.INDENTED
					else:
						# tile is a ramp so check if it's a ramp in the same direction
						var tile_data:TileData = tilemap.get_cell_tile_data(layer, tile)
						var tile_type:int = tile_data.get_custom_data("tile_type")
						if tile_type != test_tile_type:
							# ramps don't match so add a margin
							edge_types[i] = EdgeType.INDENTED
			else: # SECTION "A"
				# top layer (no tile above) so just check if test_tile is a ramp or not
				var test_tile_data:TileData = tilemap.get_cell_tile_data(layer, test_tile)
				var test_tile_type:int = test_tile_data.get_custom_data("tile_type")
				if test_tile_type == TILE_FLAT:
					# tile is flat so indent
					edge_types[i] = EdgeType.INDENTED
				else:
					# tile is a ramp so check if it's a ramp in the same direction
					var tile_data:TileData = tilemap.get_cell_tile_data(layer, tile)
					var tile_type:int = tile_data.get_custom_data("tile_type")
					if tile_type != test_tile_type:
						# ramps don't match so add a margin
						edge_types[i] = EdgeType.INDENTED
		else:
			# tile doesn't exist so need to add margin
			edge_types[i] = EdgeType.INDENTED
	
	return { "edges": edge_types, "corners": corner_blocked}


# Calculates the vertices for the left corner of a tile
func left_vertex_calc(tile:Vector2i, layer:int, even_y:bool, sw_margin:EdgeType, nw_margin:EdgeType, corner_blocked:bool) -> Dictionary:
	var angle:float = atan(2.0)
	var vertices:PackedVector3Array = []
	var directions:Array[Vector2i] = []
	
	if sw_margin == EdgeType.STANDARD and nw_margin == EdgeType.STANDARD and corner_blocked == true:
		# will be a wedge shape with 3 vertices
		var vertex_1:Vector3 = Vector3.ZERO # same as just NW
		vertex_1.x = tile.x * 32
		if even_y == false:
			vertex_1.x += 16
		vertex_1.y = layer * LAYER_HEIGHT
		vertex_1.z = (tile.y * 8) + 8
		vertex_1.x += (sin(angle) * 3)
		vertex_1.z += (cos(angle) * 3)
		
		var vertex_2:Vector3 = Vector3.ZERO # same as both NW and SW
		vertex_2.x = tile.x * 32
		if even_y == false:
			vertex_2.x += 16
		vertex_2.y = layer * LAYER_HEIGHT
		vertex_2.z = (tile.y * 8) + 8
		vertex_2.x += (sin(angle) * 6)
		
		var vertex_3:Vector3 = Vector3.ZERO # same as just SW
		vertex_3.x = tile.x * 32
		if even_y == false:
			vertex_3.x += 16
		vertex_3.y = layer * LAYER_HEIGHT
		vertex_3.z = (tile.y * 8) + 8
		vertex_3.x += (sin(angle) * 3)
		vertex_3.z -= (cos(angle) * 3)
		
		vertices.append(vertex_1)
		vertices.append(vertex_2)
		vertices.append(vertex_3)
		
		directions.append(Vector2i(1,0))
		directions.append(Vector2i(0,0))
		directions.append(Vector2i(1,0))
		
		return { "vertices": vertices, "directions": directions }
	
	# at this point so will just be a single vertex
	var vertex:Vector3
	vertex.x = tile.x * 32
	
	if even_y == false:
		vertex.x += 16
	
	if nw_margin == EdgeType.INDENTED:
		if sw_margin == EdgeType.INDENTED:
			# both nw and sw margins
			vertex.x += (sin(angle) * 6)
		else:
			# just nw margin
			vertex.x += (sin(angle) * 3)
	elif sw_margin == EdgeType.INDENTED:
		# just sw margin
		vertex.x += (sin(angle) * 3)
	
	vertex.y = layer * LAYER_HEIGHT
	
	vertex.z = (tile.y * 8) + 8
	
	if nw_margin == EdgeType.INDENTED:
		if sw_margin == EdgeType.INDENTED:
			# both nw and sw margins - z stays the same
			pass
		else:
			# just nw margin
			vertex.z += (cos(angle) * 3)
	elif sw_margin == EdgeType.INDENTED:
		# just sw margin
		vertex.z -= (cos(angle) * 3)
	
	vertices.append(vertex)
	directions.append(Vector2i(1,0))
	
	return { "vertices": vertices, "directions": directions }


# Calculates the vertices for the top corner of a tile
func top_vertex_calc(tile:Vector2i, layer:int, even_y:bool, nw_margin:EdgeType, ne_margin:EdgeType, corner_blocked:bool) -> Dictionary:
	var angle:float = atan(2.0)
	var vertices:PackedVector3Array
	var directions:Array[Vector2i]
	
	if nw_margin == EdgeType.STANDARD and ne_margin == EdgeType.STANDARD and corner_blocked == true:
		# 3 vertices
		var vertex_1:Vector3 # same as just ne
		vertex_1.x = (tile.x * 32) + 16
		if even_y == false:
			vertex_1.x += 16
		vertex_1.y = layer * LAYER_HEIGHT
		vertex_1.z = tile.y * 8
		vertex_1.x -= (sin(angle) * 3)
		vertex_1.z += (cos(angle) * 3)
		
		var vertex_2:Vector3 # same as both
		vertex_2.x = (tile.x * 32) + 16
		if even_y == false:
			vertex_2.x += 16
		vertex_2.y = layer * LAYER_HEIGHT
		vertex_2.z = tile.y * 8
		vertex_2.z += (cos(angle) * 6)
		
		var vertex_3:Vector3 # same as just nw
		vertex_3.x = (tile.x * 32) + 16
		if even_y == false:
			vertex_3.x += 16
		vertex_3.y = layer * LAYER_HEIGHT
		vertex_3.z = tile.y * 8
		vertex_3.x += (sin(angle) * 3)
		vertex_3.z += (cos(angle) * 3)
		
		vertices.append(vertex_1)
		vertices.append(vertex_2)
		vertices.append(vertex_3)
		
		directions.append(Vector2i(0,1))
		directions.append(Vector2i(0,0))
		directions.append(Vector2i(0,1))
		
		return { "vertices": vertices, "directions": directions }
	
	# just 1 vertex
	var vertex:Vector3
	vertex.x = (tile.x * 32) + 16
	
	if even_y == false:
		vertex.x += 16
	
	if nw_margin == EdgeType.INDENTED:
		if ne_margin == EdgeType.INDENTED:
			# both nw and ne margins - x stays the same
			pass
		else:
			# just nw margin
			vertex.x += (sin(angle) * 3)
	elif ne_margin == EdgeType.INDENTED:
		# just ne margin
		vertex.x -= (sin(angle) * 3)
	
	vertex.y = layer * LAYER_HEIGHT
	
	vertex.z = tile.y * 8
	
	if nw_margin == EdgeType.INDENTED:
		if ne_margin == EdgeType.INDENTED:
			# both nw and ne margins
			vertex.z += (cos(angle) * 6)
		else:
			# just nw margin
			vertex.z += (cos(angle) * 3)
	elif ne_margin == EdgeType.INDENTED:
		# just ne margin
		vertex.z += (cos(angle) * 3)
	
	vertices.append(vertex)
	directions.append(Vector2i(0,1))
	
	return { "vertices": vertices, "directions": directions }


# Calculates the vertices for the right corner of a tile
func right_vertex_calc(tile:Vector2i, layer:int, even_y:bool, ne_margin:EdgeType, se_margin:EdgeType, corner_blocked:bool) -> Dictionary:
	var angle:float = atan(2.0)
	var vertices:PackedVector3Array
	var directions:Array[Vector2i]
	
	if ne_margin == EdgeType.STANDARD and se_margin == EdgeType.STANDARD and corner_blocked == true:
		# 3 vertices
		var vertex_1:Vector3 # same as just se
		vertex_1.x = (tile.x + 1) * 32
		if even_y == false:
			vertex_1.x += 16
		vertex_1.y = layer * LAYER_HEIGHT
		vertex_1.z = (tile.y * 8) + 8
		vertex_1.x -= (sin(angle) * 3)
		vertex_1.z -= (cos(angle) * 3)
		
		var vertex_2:Vector3 # same as both
		vertex_2.x = (tile.x + 1) * 32
		if even_y == false:
			vertex_2.x += 16
		vertex_2.y = layer * LAYER_HEIGHT
		vertex_2.z = (tile.y * 8) + 8
		vertex_2.x -= (sin(angle) * 6)
		
		var vertex_3:Vector3 # same as just ne
		vertex_3.x = (tile.x + 1) * 32
		if even_y == false:
			vertex_3.x += 16
		vertex_3.y = layer * LAYER_HEIGHT
		vertex_3.z = (tile.y * 8) + 8
		vertex_3.x -= (sin(angle) * 3)
		vertex_3.z += (cos(angle) * 3)
		
		vertices.append(vertex_1)
		vertices.append(vertex_2)
		vertices.append(vertex_3)
		
		directions.append(Vector2i(-1,0))
		directions.append(Vector2i(0,0))
		directions.append(Vector2i(-1,0))
		
		return { "vertices": vertices, "directions": directions }
	
	var vertex:Vector3
	vertex.x = (tile.x + 1) * 32
	
	if even_y == false:
		vertex.x += 16
	
	if ne_margin == EdgeType.INDENTED:
		if se_margin == EdgeType.INDENTED:
			# both ne and se margins
			vertex.x -= (sin(angle) * 6)
		else:
			# just ne margin
			vertex.x -= (sin(angle) * 3)
	elif se_margin == EdgeType.INDENTED:
		# just se margin
		vertex.x -= (sin(angle) * 3)
	
	vertex.y = layer * LAYER_HEIGHT
	
	vertex.z = (tile.y * 8) + 8
	
	if ne_margin == EdgeType.INDENTED:
		if se_margin == EdgeType.INDENTED:
			# both ne and se margins - z stays the same
			pass
		else:
			# just ne margin
			vertex.z += (cos(angle) * 3)
	elif se_margin == EdgeType.INDENTED:
		# just se margin
		vertex.z -= (cos(angle) * 3)
	
	vertices.append(vertex)
	directions.append(Vector2i(-1,0))
	
	return { "vertices": vertices, "directions": directions }


# Calculates the vertices for the bottom corner of a tile
func bottom_vertex_calc(tile:Vector2i, layer:int, even_y:bool, se_margin:EdgeType, sw_margin:EdgeType, corner_blocked:bool) -> Dictionary:
	var angle:float = atan(2.0)
	var vertices:PackedVector3Array
	var directions:Array[Vector2i]
	
	if se_margin == EdgeType.STANDARD and sw_margin == EdgeType.STANDARD and corner_blocked == true:
		# 3 vertices
		var vertex_1:Vector3 # same as just sw
		vertex_1.x = (tile.x * 32) + 16
		if even_y == false:
			vertex_1.x += 16
		vertex_1.y = layer * LAYER_HEIGHT
		vertex_1.z = (tile.y * 8) + 16
		vertex_1.x += (sin(angle) * 3)
		vertex_1.z -= (cos(angle) * 3)
		
		var vertex_2:Vector3 # same as both
		vertex_2.x = (tile.x * 32) + 16
		if even_y == false:
			vertex_2.x += 16
		vertex_2.y = layer * LAYER_HEIGHT
		vertex_2.z = (tile.y * 8) + 16
		vertex_2.z -= (cos(angle) * 6)
		
		var vertex_3:Vector3 # same as just se
		vertex_3.x = (tile.x * 32) + 16
		if even_y == false:
			vertex_3.x += 16
		vertex_3.y = layer * LAYER_HEIGHT
		vertex_3.z = (tile.y * 8) + 16
		vertex_3.x -= (sin(angle) * 3)
		vertex_3.z -= (cos(angle) * 3)
		
		vertices.append(vertex_1)
		vertices.append(vertex_2)
		vertices.append(vertex_3)
		
		directions.append(Vector2i(0,-1))
		directions.append(Vector2i(0,0))
		directions.append(Vector2i(0,-1))
		
		return { "vertices": vertices, "directions": directions }
	
	# just 1 vertex
	var vertex:Vector3
	vertex.x = (tile.x * 32) + 16
	
	if even_y == false:
		vertex.x += 16
	
	if sw_margin == EdgeType.INDENTED:
		if se_margin == EdgeType.INDENTED:
			# both sw and se margins - x stays the same
			pass
		else:
			# just sw margin
			vertex.x += (sin(angle) * 3)
	elif se_margin == EdgeType.INDENTED:
		# just se margin
		vertex.x -= (sin(angle) * 3)
	
	vertex.y = layer * LAYER_HEIGHT
	
	vertex.z = (tile.y * 8) + 16
	
	if sw_margin == EdgeType.INDENTED:
		if se_margin == EdgeType.INDENTED:
			# both sw and se margins
			vertex.z -= (cos(angle) * 6)
		else:
			# just sw margin
			vertex.z -= (cos(angle) * 3)
	elif se_margin == EdgeType.INDENTED:
		# just se margin
		vertex.z -= (cos(angle) * 3)
	
	vertices.append(vertex)
	directions.append(Vector2i(0,-1))
	
	return { "vertices": vertices, "directions": directions }


# This function works out the triangles that make a mesh from the supplied list of vertices
# tile_vertices needs to contain the vertices in a clockwise order
func calculate_triangles(tile_data:Dictionary) -> Array[PackedInt32Array]:
	var triangles:Array[PackedInt32Array] = []
	var edges:Array[Vector2i] = [] # stores a list of all the existing edges so we can check easilly if they exist yet
	
	var tile_vertices:PackedVector3Array = tile_data["vertices"]
	var tile_directions:Array[Vector2i] = tile_data["directions"]
	
	# if there are only 4 vertices then we can just use the triangles [0,1,2] [0,2,3]
	var vertex_count:int = tile_vertices.size()
	if vertex_count == 4:
		return [PackedInt32Array([0,1,2]), PackedInt32Array([0,2,3])]
	
	
	# there are more than 4 vertices so we need to calculate the traingles	
	# begin by adding all the outside edges - makes it easier to check if an edge is valid in certain situations
	for n:int in range(vertex_count):
		# make sure if n is the final vertex it is joined to vertex 0
		if n+1 == vertex_count:
			edges.append(Vector2i(n, 0))
		else:
			edges.append(Vector2i(n, n+1))
	
	for i:int in range(vertex_count):
		var vertex_1_id:int = i
		
		for j:int in range(vertex_count-1):
			var vertex_2_id:int = i+1 + j
			if vertex_2_id >= vertex_count:
				vertex_2_id -= vertex_count
			
			var triangle_completed:bool = false # lets us know whether we found a valid triangle
			var triangle:PackedInt32Array = []
			
			# loop through every remaining vertex to see if it makes a valid triangle
			for k:int in range(vertex_count-2):
				# calculate the index of the vertex_3 we want to check and handle any overflow
				var vertex_3_id:int = (vertex_2_id+1) + k
				if vertex_3_id >= vertex_count:
					vertex_3_id -= vertex_count
				
				if vertex_3_id == vertex_1_id:
					break
				# make our test triangle
				triangle = [vertex_1_id, vertex_2_id, vertex_3_id]
				
				# check if the triangle already exists - if so then we move on to the next vertex_1
				# as this one has already been accounted for
				var exists:bool = false
				for t in triangles:
					if t.has(triangle[0]) and t.has(triangle[1]) and t.has(triangle[2]):
						exists = true
				
				if exists == true:
					break
					
				# triangle doesn't exist yet so check if it is valid
				var triangle_valid = test_triangle(triangle, tile_vertices, tile_directions, edges)
				
				# if triangle is valid exit the loop now, otherwise we move on to the next possible vertex_3
				if triangle_valid:
					# add the new adges
					if not edges.has(Vector2i(triangle[0], triangle[1])) and not edges.has(Vector2i(triangle[1],triangle[0])):
						edges.append(Vector2i(triangle[0], triangle[1]))
					if not edges.has(Vector2i(triangle[1], triangle[2])) and not edges.has(Vector2i(triangle[2],triangle[1])):
						edges.append(Vector2i(triangle[1], triangle[2]))
					if not edges.has(Vector2i(triangle[2], triangle[0])) and not edges.has(Vector2i(triangle[0],triangle[2])):
						edges.append(Vector2i(triangle[2], triangle[0]))
					
					triangle_completed = true
					break
			
			# check if we managed to make a triangle
			# if so we add it to the list of triangles, if not then we can just do nothing and move on to the next vertex_1
			if triangle_completed:
				triangles.append(triangle)
	
	# we have now built our triangles so just send back the triangles array
	return triangles


# Checks whether the triangle we have calculated is valid
func test_triangle(triangle:PackedInt32Array, vertices:PackedVector3Array, directions:Array[Vector2i], edges:Array[Vector2i], debug:bool = false) -> bool:
	var v1_point:Vector2 #v1
	var v2_point:Vector2 #v2
	var v3_point:Vector2 #v2
	
	# turn the Vector3 values in to Vector2s
	v1_point.x = vertices[triangle[0]].x
	v1_point.y = vertices[triangle[0]].z
	v2_point.x = vertices[triangle[1]].x
	v2_point.y = vertices[triangle[1]].z
	v3_point.x = vertices[triangle[2]].x
	v3_point.y = vertices[triangle[2]].z
	
	# first test test that edges dont intersect each other, can do this by making sure they aren't parallel -
	# as the 3 edges are connected to each other we shouldn't be in a situation where they are parallel but
	# not coincident 
	# v1->v2 & v2->v3
	if are_lines_parallel(v1_point, v2_point, v2_point, v3_point):
		return false
	
	# v1->v2 & v3->1
	if are_lines_parallel(v1_point, v2_point, v3_point, v1_point):
		return false
	
	# v2->v3 & v3->v1
	if are_lines_parallel(v2_point, v3_point, v3_point, v1_point):
		return false
	
	# test if any of the edges go outside the boundary of the tile
	#v1->v2
	var v1_dir:Vector2i = directions[triangle[0]]
	if v1_dir.x != 0:
		var x_change:float = v1_point.x - v2_point.x
		if is_zero_approx(x_change):
			return false
	if v1_dir.y != 0:
		var y_change:float = v1_point.y - v2_point.y
		if is_zero_approx(y_change):
			return false
	
	#v2->v3
	var v2_dir:Vector2i = directions[triangle[1]]
	if v2_dir.x != 0:
		var x_change:float = v2_point.x - v3_point.x
		if is_zero_approx(x_change):
			return false
	if v2_dir.y != 0:
		var y_change:float = v2_point.y - v3_point.y
		if is_zero_approx(y_change):
			return false
	
	#v3->v1
	var v3_dir:Vector2i = directions[triangle[2]]
	if v3_dir.x != 0:
		var x_change:float = v3_point.x - v1_point.x
		if is_zero_approx(x_change):
			return false
	if v3_dir.y != 0:
		var y_change:float = v3_point.y - v1_point.y
		if is_zero_approx(y_change):
			return false
	
	# test if the edges of the traingle intersect any existing edges
	for edge in edges:
		var edge_point_1:Vector2
		var edge_point_2:Vector2
		
		edge_point_1.x = vertices[edge[0]].x
		edge_point_1.y = vertices[edge[0]].z
		edge_point_2.x = vertices[edge[1]].x
		edge_point_2.y = vertices[edge[1]].z
		
		# edge 1 - v1-v2
		if edge != Vector2i(triangle[0], triangle[1]) and edge != Vector2i(triangle[1], triangle[0]):
			if do_lines_intersect(v1_point, v2_point, edge_point_1, edge_point_2, debug):
				return false
		
		# edge 2 - v2-v3
		if edge != Vector2i(triangle[1], triangle[2]) and edge != Vector2i(triangle[2], triangle[1]):
			if do_lines_intersect(v2_point, v3_point, edge_point_1, edge_point_2, debug):
				return false
		
		#edge 3 - v3-v1
		if edge != Vector2i(triangle[2], triangle[0]) and edge != Vector2i(triangle[0], triangle[2]):
			if do_lines_intersect(v3_point, v1_point, edge_point_1, edge_point_2, debug):
				return false
		
	return true


# Checks if lines are parallel
func are_lines_parallel(P1:Vector2, P2:Vector2, P3:Vector2, P4:Vector2) -> bool:
	# work this out by checking if they have the same slope
	var slope1:float = (P2.y-P1.y)/(P2.x-P1.x)
	var slope2:float = (P3.y-P2.y)/(P3.x-P2.x)
	
	if is_equal_approx(slope1, slope2):
		return true
	return false


# Checks if two lines (L1 & L2) intersect - L1 is defined by the points P1 and P2, L2 is defined by points P3 and P4
func do_lines_intersect(P1:Vector2, P2:Vector2, P3:Vector2, P4:Vector2, debug:bool=false) -> bool:
	var denominator:float = ((P1.x - P2.x) * (P3.y - P4.y)) - ((P1.y - P2.y) * (P3.x - P4.x))
	
	# this is meant to test if lines are parallel or coincident... I don't know if it actually does as I've had some
	# weird situations in testing (resulting in requiring the parallel function above) but it seems to work 
	# so keeping it!
	if is_zero_approx(snapped(denominator, 0.0001)):
		if ((P1.x == P3.x) and (P2.x == P3.x)) or ((P1.y == P3.y) and (P2.y == P3.y)):
			# lines are coincident 
			return true
		# lines are parallel
		return false
	
	var numerator_x:float = ((P1.x*P2.y - P1.y*P2.x)*(P3.x-P4.x)) - ((P1.x-P2.x)*(P3.x*P4.y - P3.y*P4.x))
	var numerator_y:float = ((P1.x*P2.y - P1.y*P2.x)*(P3.y-P4.y)) - ((P1.y-P2.y)*(P3.x*P4.y - P3.y*P4.x))
	
	var intersect_x:float = snapped(numerator_x / denominator, 0.00001)
	var intersect_y:float = snapped(numerator_y / denominator, 0.00001)
	
	if is_equal_approx(intersect_x, P1.x) and is_equal_approx(intersect_y, P1.y):
		return false
	
	if is_equal_approx(intersect_x, P2.x) and is_equal_approx(intersect_y, P2.y):
		return false
	
	# check if the intersect point is inside the line segments
	if P1.x < P2.x:
		if intersect_x < P1.x or intersect_x > P2.x:
			return false
	elif P1.x > P2.x:
		if intersect_x > P1.x or intersect_x < P2.x:
			return false
	
	if P3.x < P4.x:
		if intersect_x < P3.x or intersect_x > P4.x:
			return false
	elif P3.x > P4.x:
		if intersect_x > P3.x or intersect_x < P4.x:
			return false
	
	if P1.y < P2.y:
		if intersect_y < P1.y or intersect_y > P2.y:
			return false
	elif P1.y > P2.y:
		if intersect_y > P1.y or intersect_y < P2.y:
			return false
	
	if P3.y < P4.y:
		if intersect_y < P3.y or intersect_y > P4.y:
			return false
	elif P3.y > P4.y:
		if intersect_y > P3.y or intersect_y < P4.y:
			return false
	
	# we got here so they should intersect
	return true



#########################
##
## Navigation link functions
##
#########################

# Adds the navigation links to NavigationServer3D
func add_navigation_links() -> void:
	for link:CustomNavigationLink in navigation_links.get_children():
		link.create_3D_link(navigation_map, LAYER_HEIGHT, get_instance_id())



########################
##
## Drawing functions
##
########################



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
	var cat_layer = 1#cat.get_layer()
	var is_on_ramp = cat.on_ramp
	#print("In tilemap: %s" % cat_layer)
	
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


# custom array sort - sorts the array by y value low to high
func sort_y_low_to_high(a:Vector2i, b:Vector2i) -> bool:
	if a.y < b.y:
		return true
	return false






func new_draw_with_stairs():
	var temp_tile_collection_1 = map_layer_collection.duplicate(true)
	var temp_tile_collection_2 = []
	var extra_tiles = []
	
	# get cat locations
	var cat_position:Vector2 = cat.position
	var cat_tile = tilemap.local_to_map(cat_position)
	
	var cat_layer:int = cat.get_layer()
	
	# work out if the y tile coord is even - affects manipulation of tile coords
	var even_y = true
	if cat_tile.y % 2 != 0:
		even_y = false
	
	var right_of:bool = false
	
	# work out if cat is on ramp
	# ------ ONLY WORKS FOR RAMPS IN NE DIRECTION AT THE MOMENT
	# first get the character coordinates adjusted so that they are based on the cat being in tile [0,0]
	# (so that it is between 0-32 for x and 0-16 for y)
	var adjusted_cat_position:Vector2
	adjusted_cat_position.x = cat.position.x - (cat_tile.x * 32)
	adjusted_cat_position.y = cat.position.y * 8
	if not even_y:
		adjusted_cat_position.x += 16
	
	# potential_ramp_tile is the tile that the cat could be standing on if it's on a ramp
	# will be a lower y than the cats actual position and varies depending where it is on the current tile
	var potential_ramp_tile:Vector2i = cat_tile
	var potential_ramp_tile2:Vector2i = cat_tile # assuming its the top of the ramp
	
	# x position on the stair slope !!!!!!!!!!!!!!!!!!!!!!!!!!!! THIS ONLY WORKS FOR NE STAIRS!!!!
	# gets the x position of the edge of the ramp based on the y position of the character
	# x = (y-c)/m
	var slope_x_position:float = (adjusted_cat_position.y - 40) / -1.5
	# we now check whether the characters x position is to the left or right of the ramp edge
	if (adjusted_cat_position.x <= slope_x_position):
		# left of stair edge - stair would be tile y-2
		potential_ramp_tile.y -= 2
	else:
		# right of stair edge - stair would be tile y-1
		potential_ramp_tile.y -= 1
		if not even_y:
			potential_ramp_tile.x -= 1
		right_of = true
	
	
	
	
	#var slope_x_position_2:float = (adjusted_cat_position.y - 24) / -1.5
	## we now check whether the characters x position is to the left or right of the ramp edge
	#if (adjusted_cat_position.x <= slope_x_position_2):
		## left of stair edge - stair would be tile y-2
		#potential_ramp_tile2.y -= 1
		#if even_y:
			#potential_ramp_tile2.x -= 1
	#else:
		## right of stair edge - stair would be tile y-1
		#potential_ramp_tile2.y -= 1
	
	
	
	var potential_ramp_layer = cat_layer# + 1
	
	var test_tile_type1:int = -1
	var test_tile_type2:int = -1
	var ramp_tile
	
	var test_tile_data:TileData = tilemap.get_cell_tile_data(potential_ramp_layer, potential_ramp_tile)
	if test_tile_data:
		test_tile_type1 = test_tile_data.get_custom_data("tile_type")
	
	
	
	test_tile_data = tilemap.get_cell_tile_data(potential_ramp_layer, potential_ramp_tile2)
	if test_tile_data:
		test_tile_type2 = test_tile_data.get_custom_data("tile_type")
	
	var draw_ramp:bool = false
	
	if test_tile_type2 == TILE_RAMP_NE:
		draw_ramp = true
		ramp_tile = potential_ramp_tile2
	else:
		if right_of:
			cat_tile.y -= 1
			if not even_y:
				cat_tile.x += 1
		else:
			cat_tile.y -= 2
	
	#elif test_tile_type1 == TILE_RAMP_NE:
		#draw_ramp = true
		#ramp_tile = potential_ramp_tile
	
	
	
	print("Cat tile: %s" % cat_tile)
	print("Potential ramp tile 1: %s" % potential_ramp_tile)
	print("Potential ramp tile 2: %s" % potential_ramp_tile2)
	print("Potential ramp layer: %s" % potential_ramp_layer)
	print("Draw ramp: %s" % draw_ramp)
	print("Ramp tile: %s" % ramp_tile)
	
	
	
	

	
	## NOT DOING YET
	## the coords are the tile that is in the layer the cat is standing on, we need it to be the tile that it is standing in
	## rather than the tile below it, so the y position is 2 lower
	
	
	# get the layer the cat is within - if the cat is on a ramp or stairs then this will be the layer above the stairs
	# so they are drawn below it
	#var cat_layer = 1#cat.get_layer()
	#var is_on_ramp = cat.on_ramp
	#print("In tilemap: %s" % cat_layer)
	
	# these are set for testing the drawing
	#cat_tile = Vector2i(-1,-21)
	#cat_layer = 1
	var base_tile= cat_tile
	base_tile.y += 1
	
	
	var calc_tile
	
	# draw the full layer of layers below the character
	for layer in range(0, cat_layer):
		temp_tile_collection_2.append([])
		draw_full_layer(layer, temp_tile_collection_1[layer])
		print("L1: %s" % layer)
	
	if draw_step > 1:
		for layer in range(cat_layer, layer_count):
			print("L2: %s" % layer)
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
	
		#if draw_ramp:
			#draw_tile(potential_ramp_layer, ramp_tile)
			#temp_tile_collection_2[potential_ramp_layer].erase(ramp_tile)
	
	if draw_step > 2:
		var txt = cat.get_node("Sprite2D").get_texture()
		draw_texture_rect(txt, Rect2(cat.position.x-8, cat.position.y-16, 16, 16), false)
	
	if draw_step > 3:
		# TODO: offset y can be layer * 2
		
		for layer in range(cat_layer, layer_count):
			
			for tile in temp_tile_collection_2[layer]:
				draw_tile(layer, tile)




func yet_another_draw_function():
	pass
