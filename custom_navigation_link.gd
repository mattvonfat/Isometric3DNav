extends NavigationLink2D

class_name CustomNavigationLink

# these contain the tilemap layers that the start/end position are on
@export var start_position_layer:int
@export var end_position_layer:int

func create_3D_link(nav_map:RID, layer_height:int, owner_id:int) -> void:
	var link_3D:RID = NavigationServer3D.link_create()
	NavigationServer3D.link_set_owner_id(link_3D, owner_id)
	NavigationServer3D.link_set_map(link_3D, nav_map)
	NavigationServer3D.link_set_start_position(link_3D, Vector3(start_position.x, start_position_layer*layer_height, start_position.y))
	NavigationServer3D.link_set_end_position(link_3D, Vector3(end_position.x, end_position_layer*layer_height, end_position.y))
	NavigationServer3D.link_set_bidirectional(link_3D, bidirectional)
	NavigationServer3D.link_set_enabled(link_3D, enabled)
	NavigationServer3D.link_set_enter_cost(link_3D, enter_cost)
	NavigationServer3D.link_set_navigation_layers(link_3D, navigation_layers)
	NavigationServer3D.link_set_travel_cost(link_3D, travel_cost)
