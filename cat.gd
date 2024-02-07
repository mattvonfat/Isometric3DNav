extends CharacterBody2D

const MOVE_SPEED:float = 50.0


@onready var sprite:Sprite2D = $Sprite2D
@onready var collision_shape:CollisionShape2D = $CollisionShape2D


var path:PackedVector3Array
var target:Vector2
var has_target:bool = false

var cat_vertical = 0 # this is the current vertical position of the cat
var target_vertical # this will be the vertical position of the target position

var map # stores RID of nav map
var game
var tilemap

var on_ramp:bool = false
var ramp_tile:Vector2i


const BASE_OFFSET:int = -8
var intended_position:Vector2

##
## New nav vars
##
var navigation_path:PackedVector3Array
var target_3D:Vector3
var target_2D:Vector2
var adjusted_target_2D:Vector2

var character_vertical_position:int = 0




# called when the navigation path is updated
func set_path(new_path:PackedVector3Array) -> void:
	navigation_path = new_path
	if navigation_path.size() > 0:
		has_target = true
		get_next_target()


# get the next target in the path
func get_next_target() -> void:
	target_3D = navigation_path[0]
	navigation_path.remove_at(0)
	
	target_2D = V3_to_V2(target_3D)
	
	adjusted_target_2D = target_2D
	adjusted_target_2D.y += target_3D.y
	
	sprite.position.y = BASE_OFFSET - target_3D.y


func process_movement() -> void:
	if position.distance_to(adjusted_target_2D) < 2:
		# reached the target
		if navigation_path.size() > 0:
			# more points in the path
			character_vertical_position = target_3D.y
			get_next_target()
			velocity = position.direction_to(adjusted_target_2D) * MOVE_SPEED
		
		else:
			# reached final point, remove target and reset velocity
			has_target = false
			velocity = Vector2.ZERO
	
	else:
		# still moving to current target
		velocity = position.direction_to(adjusted_target_2D) * MOVE_SPEED
	
	move_and_slide()





func set_path_old(new_path:PackedVector3Array):
	path = new_path
	if path.size() > 0:
		target_vertical = path[0].y # save the vertcial position of the target point
		target = V3_to_V2(path[0]) # convert the targer position to a 2D position
		path.remove_at(0) # remove the target position from the path
		has_target = true # 

func _physics_process(_delta):
	if has_target:
		process_movement()



func update_movement():
	# see if we have reached the target - I just guessed at 2 being ok
	if intended_position.distance_to(target) < 2:
		# check if there are more points in the path
		if path.size() > 0:
			# update the cat vertical position
			cat_vertical = target_vertical
			# get the new target/remove path/etc
			target = V3_to_V2(path[0])
			target_vertical = path[0].y
			path.remove_at(0)
			velocity = adjust_target_position(intended_position.direction_to(target)*MOVE_SPEED)
		else:
			# no more points in path so target is reached
			has_target = false
			velocity = Vector2.ZERO
	else:
		velocity = adjust_target_position(intended_position.direction_to(target)*MOVE_SPEED)
	update_offsets()

func adjust_target_position(target_position:Vector2):
	var adjusted_target_position:Vector2 = target_position
	adjusted_target_position.y = target_position.y + (target_vertical/2)
	return adjusted_target_position

func update_offsets():
	sprite.position.y = BASE_OFFSET - (target_vertical/2) # T_V/16*8
	collision_shape.position.y = BASE_OFFSET - (target_vertical/2) # T_V/16*8



func update_movement_2():
	pass




# returns the 3D positon of the cat
func get_pos3D():
	var v = Vector3()
	v.x = sprite.global_position.x
	v.z = sprite.global_position.y - BASE_OFFSET
	v.y = character_vertical_position
	return v

# takes a 3D vector and returns the x and z coords as a 2D vector
func V3_to_V2(v3:Vector3):
	var v2 = Vector2()
	v2.x = v3.x
	v2.y = v3.z
	return v2
