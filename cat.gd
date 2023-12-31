extends CharacterBody2D

const MOVE_SPEED:float = 50.0

var path:PackedVector3Array
var target:Vector2
var has_target:bool = false

var cat_vertical = 0 # this is the current vertical position of the cat
var target_vertical # this will be the vertical position of the target position

var map # stores RID of nav map
var game
var tilemap



func set_path(new_path:PackedVector3Array):
	path = new_path
	if path.size() > 0:
		target_vertical = path[0].y # save the vertcial position of the target point
		target = v3_to_v2(path[0]) # convert the targer position to a 2D position
		path.remove_at(0) # remove the target position from the path
		has_target = true # 

func _physics_process(_delta):
	if has_target:
		
		# see if we have reached the target - I just guessed at 2 being ok
		if position.distance_to(target) < 2:
			# check if there are more points in the path
			if path.size() > 0:
				# update the cat vertical position
				cat_vertical = target_vertical
				# get the new target/remove path/etc
				target = v3_to_v2(path[0])
				target_vertical = path[0].y
				path.remove_at(0)
				velocity = position.direction_to(target)*MOVE_SPEED
			else:
				# no more points in path so target is reached
				has_target = false
				velocity = Vector2.ZERO
		else:
			velocity = position.direction_to(target)*MOVE_SPEED
	
		move_and_slide()
		tilemap.queue_redraw()
		#test()

func get_layer():
	return floor(cat_vertical/16.0)+1

func get_cat_vertical():
	var cat_layer = ceil(cat_vertical/16.0)
	var cat_tile = game.tilemap.local_to_map(position)
	
	var tile_data = game.tilemap.get_cell_tile_data(cat_layer, cat_tile)
	var tile_num = tile_data.get_custom_data("tile_type")
	
	if tile_num != 0: # so is a ramp - chnage this if other shaped tiles are used
		return (cat_layer * 16) + 1
	else:
		return (cat_layer * 16)

func test():
	var cat_layer = ceil(cat_vertical/16.0)
	
	var cat_tile = game.tilemap.local_to_map(position)
	
	if game.map_layer_collection[int(cat_layer)].has(cat_tile):
		var tile_data = game.tilemap.get_cell_tile_data(cat_layer, cat_tile)
		var tile_num = tile_data.get_custom_data("tile_type")
	
		if tile_num != 0:
			cat_layer += 1
	
	var left_tile = cat_tile
	left_tile.y -= 1
	if cat_tile.y % 2 == 0:
		left_tile.x -= 1
	
	var right_tile = cat_tile
	right_tile.y -= 1
	if cat_tile.y % 2 != 0:
		right_tile.x += 1
	
	var tiles = [cat_tile, left_tile, right_tile]
	
	var found = false
	
	for i in tiles:
		for layer_id in range(game.layer_count-1, cat_layer, -1): # dont count bottom layer
			if layer_id < cat_layer:
				game.tilemap.set_layer_z_index(layer_id, 0)
			else:
				game.tilemap.set_layer_z_index(layer_id, 1)
			if game.map_layer_collection[layer_id].has(i):
				z_index = 0
				found = true
				break
	
	if not found:
		z_index = 1

# returns the 3D positon of the cat
func get_pos3D():
	var v = Vector3()
	v.x = position.x
	v.z = position.y
	v.y = cat_vertical
	return v

# takes a 3D vector and returns the x and z coords as a 2D vector
func v3_to_v2(v3:Vector3):
	var v2 = Vector2()
	v2.x = v3.x
	v2.y = v3.z
	return v2
