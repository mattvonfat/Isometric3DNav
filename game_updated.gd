extends Node2D

# these are the values that are defined in the custom data layer ("tile_type") of the tileset
# tells the code which function is used to draw the nav mesh for that tile

enum { LEFT_VERTEX=0, TOP_VERTEX, RIGHT_VERTEX, BOTTOM_VERTEX }

class mVector3:
	var x:float:
		get:
			return snapped(x, decimals)
		set(value):
			x = value
	var y:float:
		get:
			return snapped(x, decimals)
		set(value):
			y = value
	var z:float:
		get:
			return snapped(x, decimals)
		set(value):
			z = value
	
	var decimals:float = 0.000001
	
	func _init(_x:float=0.0, _y:float=0.0, _z:float=0.0):
		x = _x
		y = _y
		z = _z
	
	func _to_string():
		return "(%s, %s, %s)" % [snapped(x, decimals), snapped(y, decimals), snapped(z, decimals)]

@onready var tilemap = $CustomTileMap
@onready var cat = $Cat

const LAYER_HEIGHT:int = 16

var layer_count:int # number of layers in the tile map
var map_layer_collection:Dictionary # stores the tile data for each layer

var nav_map # navigation map that we will create




var corner_options = [ [0,3],  [0,1],  [1,2],  [2,3] ]


var ramp_type = [[], [0, 2], [1, 3], [0, 2], [1, 3]]

enum { TILE_RAMP_NW=0, TILE_RAMP_NE=1, TILE_RAMP_SE=2, TILE_RAMP_SW=3, TILE_FLAT=4 }

### HAPPYISH WITH:
enum EdgeType { STANDARD, INDENTED }

enum { NW_EDGE=0, NE_EDGE, SE_EDGE, SW_EDGE }
var adjacent_tiles_even = [  Vector2i(-1,-1), Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,1) ]
var adjacent_tiles_odd = [  Vector2i(0,-1), Vector2i(1,-1), Vector2i(1,1), Vector2i(0,1) ]
var adjacent_tiles = [adjacent_tiles_even, adjacent_tiles_odd]

enum { N_CORNER=0, S_CORNER, E_CORNER, W_CORNER }
var corner_vectors = [  Vector2i(0,-2), Vector2i(0,2), Vector2i(1,0), Vector2i(-1,0) ] # N, S, E, W

func _ready():
	#print(Vector3(1.123456789, 10.123456789, 100.123456789))
	generate_nav_mesh()
	cat.map = nav_map
	cat.game = self
	$CustomTileMap.set_cat(cat)
	cat.tilemap = $CustomTileMap
	$Label.set_text(tilemap.steps[4])
	tilemap.label = $Label
	
	#print(bottom_vertex_calc(Vector2i(0,0), 0, true, false, true))
	#print(left_vertex_calc(Vector2i(0,1), 0, false, true, false))
	



func left_vertex_calc(tile:Vector2i, layer:int, even:bool, sw_margin:EdgeType, nw_margin:EdgeType, corner_blocked:bool) -> Dictionary:
	var angle = atan(2.0)
	var vertices:PackedVector3Array = []
	var directions:Array[Vector2i] = []
	
	if sw_margin == EdgeType.STANDARD and nw_margin == EdgeType.STANDARD and corner_blocked == true:
		# will be a wedge shape with 3 vertices
		var vertex_1:Vector3 = Vector3.ZERO # same as just NW
		vertex_1.x = tile.x * 32
		if even == false:
			vertex_1.x += 16
		vertex_1.y = layer * LAYER_HEIGHT
		vertex_1.z = (tile.y * 8) + 8
		vertex_1.x += (sin(angle) * 3)
		vertex_1.z += (cos(angle) * 3)
		
		var vertex_2:Vector3 = Vector3.ZERO # same as both NW and SW
		vertex_2.x = tile.x * 32
		if even == false:
			vertex_2.x += 16
		vertex_2.y = layer * LAYER_HEIGHT
		vertex_2.z = (tile.y * 8) + 8
		vertex_2.x += (sin(angle) * 6)
		
		var vertex_3:Vector3 = Vector3.ZERO # same as just SW
		vertex_3.x = tile.x * 32
		if even == false:
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
	
	if even == false:
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

func top_vertex_calc(tile:Vector2i, layer:int, even:bool, nw_margin:EdgeType, ne_margin:EdgeType, corner_blocked:bool) -> Dictionary:
	var angle = atan(2.0)
	var vertices:PackedVector3Array
	var directions:Array[Vector2i]
	
	if nw_margin == EdgeType.STANDARD and ne_margin == EdgeType.STANDARD and corner_blocked == true:
		# 3 vertices
		var vertex_1:Vector3 # same as just ne
		vertex_1.x = (tile.x * 32) + 16
		if even == false:
			vertex_1.x += 16
		vertex_1.y = layer * LAYER_HEIGHT
		vertex_1.z = tile.y * 8
		vertex_1.x -= (sin(angle) * 3)
		vertex_1.z += (cos(angle) * 3)
		
		var vertex_2:Vector3 # same as both
		vertex_2.x = (tile.x * 32) + 16
		if even == false:
			vertex_2.x += 16
		vertex_2.y = layer * LAYER_HEIGHT
		vertex_2.z = tile.y * 8
		vertex_2.z += (cos(angle) * 6)
		
		var vertex_3:Vector3 # same as just nw
		vertex_3.x = (tile.x * 32) + 16
		if even == false:
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
	
	if even == false:
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

func right_vertex_calc(tile:Vector2i, layer:int, even:bool, ne_margin:EdgeType, se_margin:EdgeType, corner_blocked:bool) -> Dictionary:
	var angle = atan(2.0)
	var vertices:PackedVector3Array
	var directions:Array[Vector2i]
	
	if ne_margin == EdgeType.STANDARD and se_margin == EdgeType.STANDARD and corner_blocked == true:
		# 3 vertices
		var vertex_1:Vector3 # same as just se
		vertex_1.x = (tile.x + 1) * 32
		if even == false:
			vertex_1.x += 16
		vertex_1.y = layer * LAYER_HEIGHT
		vertex_1.z = (tile.y * 8) + 8
		vertex_1.x -= (sin(angle) * 3)
		vertex_1.z -= (cos(angle) * 3)
		
		var vertex_2:Vector3 # same as both
		vertex_2.x = (tile.x + 1) * 32
		if even == false:
			vertex_2.x += 16
		vertex_2.y = layer * LAYER_HEIGHT
		vertex_2.z = (tile.y * 8) + 8
		vertex_2.x -= (sin(angle) * 6)
		
		var vertex_3:Vector3 # same as just ne
		vertex_3.x = (tile.x + 1) * 32
		if even == false:
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
	
	if even == false:
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

func bottom_vertex_calc(tile:Vector2i, layer:int, even:bool, se_margin:EdgeType, sw_margin:EdgeType, corner_blocked:bool) -> Dictionary:
	var angle = atan(2.0)
	var vertices:PackedVector3Array
	var directions:Array[Vector2i]
	
	if se_margin == EdgeType.STANDARD and sw_margin == EdgeType.STANDARD and corner_blocked == true:
		# 3 vertices
		var vertex_1:Vector3 # same as just sw
		vertex_1.x = (tile.x * 32) + 16
		if even == false:
			vertex_1.x += 16
		vertex_1.y = layer * LAYER_HEIGHT
		vertex_1.z = (tile.y * 8) + 16
		vertex_1.x += (sin(angle) * 3)
		vertex_1.z -= (cos(angle) * 3)
		
		var vertex_2:Vector3 # same as both
		vertex_2.x = (tile.x * 32) + 16
		if even == false:
			vertex_2.x += 16
		vertex_2.y = layer * LAYER_HEIGHT
		vertex_2.z = (tile.y * 8) + 16
		vertex_2.z -= (cos(angle) * 6)
		
		var vertex_3:Vector3 # same as just se
		vertex_3.x = (tile.x * 32) + 16
		if even == false:
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
	
	if even == false:
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
	
	# get the tile map data for each layer and store in map_collection_layer
	map_layer_collection = {}
	for layer_id in range(layer_count):
		map_layer_collection[layer_id] = tilemap.tilemap.get_used_cells(layer_id)
	
	for layer_id in range(layer_count):
		# go through each tile in the layer
		for tile in map_layer_collection[layer_id]:
			# need to check if there is a tile above this tile, if so don't add it to the nav mesh
			if layer_id+1 < layer_count:
				# the tile above this tile will have the same x coord but the y coord will be 2 smaller
				var stacked_tile = tile
				stacked_tile.y -= 2
				
				if map_layer_collection[layer_id+1].has(stacked_tile):
					# there is a tile above this one so skip it
					continue
			
			# get the "tile_type" of the current tile so we know how to create it
			var tile_data = tilemap.tilemap.get_cell_tile_data(layer_id, tile)
			var tile_type = tile_data.get_custom_data("tile_type")
			
			match tile_type:
				TILE_FLAT: #flat
					create_tile_polygon(tile, layer_id, new_mesh)
				
				TILE_RAMP_NE: # NE ramp
					print("\nNE")
					print(tile)
					create_ramp_polygon(tile, layer_id, new_mesh, TILE_RAMP_NE)
				
				TILE_RAMP_SE: # SE ramp
					print("\nSE")
					print(tile)
					create_ramp_polygon(tile, layer_id, new_mesh, TILE_RAMP_SE)
				
				TILE_RAMP_SW: # SW ramp
					print("\nSW")
					print(tile)
					create_ramp_polygon(tile, layer_id, new_mesh, TILE_RAMP_SW)
				
				TILE_RAMP_NW: # NW ramp
					print("\nNW")
					print(tile)
					create_ramp_polygon(tile, layer_id, new_mesh, TILE_RAMP_NW)
	
	# save the nav mesh - only done so it can be viewed outside of the program for debug purposes
	var save_result = ResourceSaver.save(new_mesh, "nav_mesh_experimental.tres", 1)
	print("Nav mesh save result: %s" % save_result)
	
	# create a new navigation map
	nav_map = NavigationServer3D.map_create()
	
	# create a new navigation region and add the mesh to it, then add the region to the map
	var new_region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_navigation_mesh(new_region, new_mesh)
	NavigationServer3D.region_set_map(new_region, nav_map)
	
	# make the new map the active map
	NavigationServer3D.map_set_active(nav_map, true)


# This function works out the triangles that make a mesh from the supplied list of vertices
# tile_vertices needs to contain the vertices in a clockwise order
func calculate_triangles(tile_data:Dictionary) -> Array[PackedInt32Array]:
	var triangles:Array[PackedInt32Array]
	var edges:Array[Vector2i] # stores a list of all the existing edges so we can check easilly if they exist yet
	
	var tile_vertices:PackedVector3Array = tile_data["vertices"]
	var tile_directions:Array[Vector2i] = tile_data["directions"]
	
	#print("\nNEW TRIANGLE")
	#print(tile_vertices)
	
	var vertex_count:int = tile_vertices.size()
	
	# begin by adding all the outside edges - makes it easier to check if an edge is valid in certain situations
	for n:int in range(vertex_count):
		# make sure if n is the final vertex it is joined to vertex 0
		if n+1 == vertex_count:
			edges.append(Vector2i(n, 0))
		else:
			edges.append(Vector2i(n, n+1))
	
	for n:int in range(vertex_count):
		var vertex_1_id:int = n
		
		for j:int in range(vertex_count-1):
			var vertex_2_id:int = n+1 + j
			if vertex_2_id >= vertex_count:
				vertex_2_id -= vertex_count
			
			# !!!! - FIRST EDGES ARE ADDED AT START SO NOT CURRENTLY CHECKING THE FIRST EDGE - !!!!
			# !!!! - SHOULDN'T AFFECT THE ALGORITHM BUT WANT TO KEEP THIS IN CASE I WANT TO REVERT - !!!!
			# if the first edge already exists then we can skip this vertex
			# only need to check this for the first edge of the triangle as other edges can share with other triangles
			#if edges.has(Vector2i(vertex_1_id, vertex_2_id)):
			#	continue
			
			var triangle_completed:bool = false # lets us know whether we found a valid triangle
			var triangle:PackedInt32Array
			
			# loop through every remaining vertex to see if it makes a valid triangle
			for i:int in range(vertex_count-2):
				# calculate the index of the vertex_3 we want to check and handle any overflow
				var vertex_3_id:int = (vertex_2_id+1) + i
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
	
	#print(triangles)
	# we have now built our triangles so just send back the triangles array
	return triangles

# Tests if edges intersect and if edges go outside polygon
func test_triangle(triangle:PackedInt32Array, vertices:PackedVector3Array, directions:Array[Vector2i], edges:Array[Vector2i]) -> bool:
	var v1_point:Vector2 #v1
	var v2_point:Vector2 #v2
	var v3_point:Vector2 #v2
	
	v1_point.x = vertices[triangle[0]].x
	v1_point.y = vertices[triangle[0]].z
	v2_point.x = vertices[triangle[1]].x
	v2_point.y = vertices[triangle[1]].z
	v3_point.x = vertices[triangle[2]].x
	v3_point.y = vertices[triangle[2]].z
	
	# TESTS IF EDGES ARE OUTSIDE BOUNDARY
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
	
	var debug = false
	
	# TESTS IF EDGES INTERSECT
	for edge in edges:
		var edge_point_1:Vector2
		var edge_point_2:Vector2
		
		edge_point_1.x = vertices[edge[0]].x
		edge_point_1.y = vertices[edge[0]].z
		edge_point_2.x = vertices[edge[1]].x
		edge_point_2.y = vertices[edge[1]].z
		if debug:
				print(edge)
		
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

# Checks if two lines (L1 & L2) intersect - L1 is defined by the points P1 and P2, L2 is defined by points P3 and P4
func do_lines_intersect(P1:Vector2, P2:Vector2, P3:Vector2, P4:Vector2, debug:bool=false) -> bool:
	var denominator:float = ((P1.x - P2.x) * (P3.y - P4.y)) - ((P1.y - P2.y) * (P3.x - P4.x))
	
	if debug:
		print("Denom: %s" % denominator)
	
	if is_zero_approx(denominator):
		if ((P1.x == P3.x) and (P2.x == P3.x)) or ((P1.y == P3.y) and (P2.y == P3.y)):
			# lines are coincident 
			return true
		# lines are parallel
		return false
	
	if debug:
		print("Denom passed.")
	
	var numerator_x:float = ((P1.x*P2.y - P1.y*P2.x)*(P3.x-P4.x)) - ((P1.x-P2.x)*(P3.x*P4.y - P3.y*P4.x))
	var numerator_y:float = ((P1.x*P2.y - P1.y*P2.x)*(P3.y-P4.y)) - ((P1.y-P2.y)*(P3.x*P4.y - P3.y*P4.x))
	
	var intersect_x:float = snapped(numerator_x / denominator, 0.00001)
	var intersect_y:float = snapped(numerator_y / denominator, 0.00001)
	if debug:
		print("I-X: %s" % intersect_x)
		print("I-Y: %s" % intersect_y)
	
	if is_equal_approx(intersect_x, P1.x) and is_equal_approx(intersect_y, P1.y):
		return false
	
	if is_equal_approx(intersect_x, P2.x) and is_equal_approx(intersect_y, P2.y):
		return false
	
	# check if the intersect point is inside the line segments
	if P1.x < P2.x:
		if intersect_x < P1.x or intersect_x > P2.x:
			#print("i1")
			return false
	elif P1.x > P2.x:
		if intersect_x > P1.x or intersect_x < P2.x:
			#print("i2")
			return false

	
	if P3.x < P4.x:
		if intersect_x < P3.x or intersect_x > P4.x:
			#print("i3")
			return false
	elif P3.x > P4.x:
		if intersect_x > P3.x or intersect_x < P4.x:
			#print("i4")
			return false
	
	if P1.y < P2.y:
		if intersect_y < P1.y or intersect_y > P2.y:
			#print("i5")
			return false
	elif P1.y > P2.y:
		if intersect_y > P1.y or intersect_y < P2.y:
			#print("i6")
			return false
	
	if P3.y < P4.y:
		if intersect_y < P3.y or intersect_y > P4.y:
			#print("i7")
			return false
	elif P3.y > P4.y:
		if intersect_y > P3.y or intersect_y < P4.y:
			#print("i8")
			return false
	
	# we got here so they should intersect
	#print("within")
	return true

# creates a polygon for a tile in the nav mesh
func create_tile_polygon(tile:Vector2i, layer:int, mesh:NavigationMesh) -> void:
	# get the array of vertices from the nav mesh
	var vertices:PackedVector3Array = mesh.get_vertices()
	
	var tile_data:Dictionary = calculate_tile_coords_flat(tile, layer)
	var tile_vertices:PackedVector3Array = tile_data["vertices"]
	var tile_directions:Array[Vector2i] = tile_data["directions"]
	
	
	var triangles:Array[PackedInt32Array] = calculate_triangles(tile_data)
	
	var vertex_indices:Array
	
	# this checks if the vertices already exist in the nav mesh vertices array
	# if they don't exist then we add them
	for vertex in tile_vertices:
		var vertex_index = vertices.find(vertex)
		if vertex_index == -1:
			# vertex doesn't exist so add it
			vertex_indices.append(vertices.size())
			vertices.append(vertex)
		else:
			vertex_indices.append(vertex_index)
	
	# we set the updated vertices array to the nav mesh
	mesh.set_vertices(vertices)
	
	# add the triangles - make sure to use the indices stored in vertex_indices as they relate to the navmesh vertex list
	for triangle in triangles:
		var updated_triangle:PackedInt32Array
		for index in triangle:
			updated_triangle.append(vertex_indices[index])
		mesh.add_polygon(updated_triangle)
	
	# !!!! - SUPERCEDED BUT WANT TO KEEP FOR FUTURE REFERENCE - !!!!
	# we now add the two polygons that make up this tile, they are defined using the indexes of the vertices
	# so we find the index for each value we want to use from the vertcies array
	#mesh.add_polygon(PackedInt32Array([vertices.find(tile_coordinates[LEFT_VERTEX]), vertices.find(tile_coordinates[TOP_VERTEX]), vertices.find(tile_coordinates[RIGHT_VERTEX])]))
	#mesh.add_polygon(PackedInt32Array([vertices.find(tile_coordinates[LEFT_VERTEX]), vertices.find(tile_coordinates[RIGHT_VERTEX]), vertices.find(tile_coordinates[BOTTOM_VERTEX])]))


func create_ramp_polygon(tile:Vector2i, layer:int, mesh:NavigationMesh, direction:int) -> void:
	# get the array of vertices from the nav mesh
	var vertices:PackedVector3Array = mesh.get_vertices()
	
	var tile_data:Dictionary = calculate_tile_coords_ramp(tile, layer, direction)
	var tile_vertices:PackedVector3Array = tile_data["vertices"]
	var tile_directions:Array[Vector2i] = tile_data["directions"]
	
	
	var triangles:Array[PackedInt32Array] = calculate_triangles(tile_data)
	
	var vertex_indices:Array
	
	# this checks if the vertices already exist in the nav mesh vertices array
	# if they don't exist then we add them
	for vertex in tile_vertices:
		var vertex_index = vertices.find(vertex)
		if vertex_index == -1:
			# vertex doesn't exist so add it
			vertex_indices.append(vertices.size())
			vertices.append(vertex)
		else:
			vertex_indices.append(vertex_index)
	
	# we set the updated vertices array to the nav mesh
	mesh.set_vertices(vertices)
	
	# add the triangles - make sure to use the indices stored in vertex_indices as they relate to the navmesh vertex list
	for triangle in triangles:
		var updated_triangle:PackedInt32Array
		for index in triangle:
			updated_triangle.append(vertex_indices[index])
		mesh.add_polygon(updated_triangle)


# ramp direction is the direction that you walk UP it - the direction is the edge that is riased to the next level
func calculate_tile_coords_ramp(tile:Vector2i, layer:int, ramp_direction:int) -> Dictionary:
	var tile_vertices:PackedVector3Array
	var tile_directions:Array[Vector2i]
	
	var edge_data = get_edge_margins_ramp(tile, layer, ramp_direction)
	var edge_types = edge_data["edges"]
	var corner_types = edge_data["corners"]
	print(edge_data)
	var even = false
	if tile.y % 2 == 0:
		even = true
	
	var corner_layers:Array = [layer, layer, layer, layer]
	var tile_coords = [tile, tile, tile, tile]
	
	match ramp_direction:
		TILE_RAMP_NE:
			corner_layers[LEFT_VERTEX] -= 1
			corner_layers[BOTTOM_VERTEX] -= 1
			tile_coords[LEFT_VERTEX].y += 2
			tile_coords[BOTTOM_VERTEX].y += 2
			#if not even:
			#	tile_coords[LEFT_VERTEX].x += 1
			#	tile_coords[BOTTOM_VERTEX].x += 1
		
		TILE_RAMP_NW:
			corner_layers[RIGHT_VERTEX] -= 1
			corner_layers[BOTTOM_VERTEX] -= 1
			tile_coords[RIGHT_VERTEX].y += 2
			tile_coords[BOTTOM_VERTEX].y += 2
			#if not even:
			#	tile_coords[RIGHT_VERTEX].x += 1
			#	tile_coords[BOTTOM_VERTEX].x += 1
		
		TILE_RAMP_SE:
			corner_layers[LEFT_VERTEX] -= 1
			corner_layers[TOP_VERTEX] -= 1
			tile_coords[LEFT_VERTEX].y += 2
			tile_coords[TOP_VERTEX].y += 2
			#if not even:
			#	tile_coords[LEFT_VERTEX].x += 1
			#	tile_coords[TOP_VERTEX].x += 1
		
		TILE_RAMP_SW:
			corner_layers[RIGHT_VERTEX] -= 1
			corner_layers[TOP_VERTEX] -= 1
			tile_coords[RIGHT_VERTEX].y += 2
			tile_coords[TOP_VERTEX].y += 2
			#if not even:
			#	tile_coords[RIGHT_VERTEX].x += 1
			#	tile_coords[TOP_VERTEX].x += 1
	
	var left_vertex_data:Dictionary = left_vertex_calc(tile_coords[LEFT_VERTEX], corner_layers[LEFT_VERTEX], even, edge_types[SW_EDGE], edge_types[NW_EDGE], corner_types[W_CORNER])
	tile_vertices.append_array(left_vertex_data["vertices"])
	tile_directions.append_array(left_vertex_data["directions"])
	
	var top_vertex_data:Dictionary = top_vertex_calc(tile_coords[TOP_VERTEX], corner_layers[TOP_VERTEX], even, edge_types[NW_EDGE], edge_types[NE_EDGE], corner_types[N_CORNER])
	tile_vertices.append_array(top_vertex_data["vertices"])
	tile_directions.append_array(top_vertex_data["directions"])
	
	var right_vertex_data:Dictionary = right_vertex_calc(tile_coords[RIGHT_VERTEX], corner_layers[RIGHT_VERTEX], even, edge_types[NE_EDGE], edge_types[SE_EDGE], corner_types[E_CORNER])
	tile_vertices.append_array(right_vertex_data["vertices"])
	tile_directions.append_array(right_vertex_data["directions"])
	
	var bottom_vertex_data:Dictionary = bottom_vertex_calc(tile_coords[BOTTOM_VERTEX], corner_layers[BOTTOM_VERTEX], even, edge_types[SE_EDGE], edge_types[SW_EDGE], corner_types[S_CORNER])
	tile_vertices.append_array(bottom_vertex_data["vertices"])
	tile_directions.append_array(bottom_vertex_data["directions"])
	
	return { "vertices": tile_vertices, "directions": tile_directions }

func get_edge_margins_ramp(tile:Vector2i, layer:int, ramp_direction:int):
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
	var options = ramp_type[ramp_direction]
	
	for i:int in options:
		# calculate the tile coordinate of the adjacent tile
		var test_tile = tile + adjacent_tiles[adjacent_tile_array][i]
		# check if the tiles exists
		if map_layer_collection[layer].has(test_tile):
			# tile exists so check if it is blocked by checking the tile above it
			if layer+1 < layer_count:
				# tile we are checking will have a y value 2 lower as it is in above layer
				test_tile.y -= 2
				if map_layer_collection[layer+1].has(test_tile):
					# has a stacked tile so need to add margin
					edge_types[i] = EdgeType.INDENTED
		
		else:
			# tile doesn't exist so need to add margin
			edge_types[i] = EdgeType.INDENTED
	
	return { "edges": edge_types, "corners": corner_blocked}


func calculate_tile_coords_flat(tile:Vector2i, layer:int) -> Dictionary:
	var tile_vertices:PackedVector3Array
	var tile_directions:Array[Vector2i]
	
	var edge_data = get_edge_margins(tile, layer)
	var edge_types = edge_data["edges"]
	var corner_types = edge_data["corners"]
	
	var even = false
	if tile.y % 2 == 0:
		even = true
	
	var left_vertex_data:Dictionary = left_vertex_calc(tile, layer, even, edge_types[SW_EDGE], edge_types[NW_EDGE], corner_types[W_CORNER])
	tile_vertices.append_array(left_vertex_data["vertices"])
	tile_directions.append_array(left_vertex_data["directions"])
	
	var top_vertex_data:Dictionary = top_vertex_calc(tile, layer, even, edge_types[NW_EDGE], edge_types[NE_EDGE], corner_types[N_CORNER])
	tile_vertices.append_array(top_vertex_data["vertices"])
	tile_directions.append_array(top_vertex_data["directions"])
	
	var right_vertex_data:Dictionary = right_vertex_calc(tile, layer, even, edge_types[NE_EDGE], edge_types[SE_EDGE], corner_types[E_CORNER])
	tile_vertices.append_array(right_vertex_data["vertices"])
	tile_directions.append_array(right_vertex_data["directions"])
	
	var bottom_vertex_data:Dictionary = bottom_vertex_calc(tile, layer, even, edge_types[SE_EDGE], edge_types[SW_EDGE], corner_types[S_CORNER])
	tile_vertices.append_array(bottom_vertex_data["vertices"])
	tile_directions.append_array(bottom_vertex_data["directions"])
	
	return { "vertices": tile_vertices, "directions": tile_directions }

# works out which edges need a margin
func get_edge_margins(tile:Vector2i, layer:int):
	var debug_tile
	debug_tile = Vector2i(-2,-3)
	
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
	for i in range(adjacent_tiles[adjacent_tile_array].size()):
		# calculate the tile coordinate of the adjacent tile
		var test_tile = tile + adjacent_tiles[adjacent_tile_array][i]
		# check if the tiles exists
		if map_layer_collection[layer].has(test_tile):
			# tile exists so check if it is blocked by checking the tile above it
			if layer+1 < layer_count:
				# tile we are checking will have a y value 2 lower as it is in above layer
				test_tile.y -= 2
				if map_layer_collection[layer+1].has(test_tile):
					# has a stacked tile so need to add margin
					var tile_data = tilemap.tilemap.get_cell_tile_data(layer+1, test_tile)
					var tile_type = tile_data.get_custom_data("tile_type")
					if tile_type == TILE_FLAT:
						# normal flat tile
						edge_types[i] = EdgeType.INDENTED
					else:
						# ramp so check if it's facing this edge - if not indent it
						if tile_type != i:
							edge_types[i] = EdgeType.INDENTED
		
		else:
			# tile doesn't exist but check if the tile above is a ramp as then we still need to connect
			if layer+1 < layer_count:
				# tile we are checking will have a y value 2 lower as it is in above layer
				test_tile.y -= 2
				if map_layer_collection[layer+1].has(test_tile):
					# has a stacked tile so need to add margin
					var tile_data = tilemap.tilemap.get_cell_tile_data(layer+1, test_tile)
					var tile_type = tile_data.get_custom_data("tile_type")
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
	
	if tile == debug_tile:
		print("Edge types after side testing:")
		print(edge_types)
		print("")
	
	
	for i in range(corner_vectors.size()):
		var test_tile:Vector2i = tile + corner_vectors[i]
		if map_layer_collection[layer].has(test_tile):
			#tile exists so check if it is blocked
			if layer+1 < layer_count:
				test_tile.y -= 2
				if map_layer_collection[layer+1].has(test_tile):
					# has a sstacked tile
					corner_blocked[i] = true
		else:
			# tile doesn't exist
			corner_blocked[i] = true
	
	
	
	if tile == debug_tile:
		print("Final edge indents:")
		print(edge_types)
		print("")
	
	return { "edges": edge_types, "corners": corner_blocked}


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
