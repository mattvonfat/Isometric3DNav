extends CharacterBody2D

const MOVE_SPEED:float = 50.0

var path:PackedVector3Array
var target:Vector2
var has_target:bool = false

var cat_vertical = 0 # this is the current vertical position of the cat
var target_vertical # this will be the vertical position of the target position

var map # stored the RID of the navigation map

func set_path(new_path:PackedVector3Array):
	path = new_path
	if path.size() > 0:
		target_vertical = path[0].y # save the vertcial position of the target point
		target = v3_to_v2(path[0]) # convert the targer position to a 2D position
		path.remove_at(0) # remove the target position from the path
		has_target = true # 

func _physics_process(_delta):
	if has_target:
		#z_index = ceil(cat_vertical/16)
		
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
