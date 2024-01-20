extends Node

const LAYER_HEIGHT:int = 32

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
