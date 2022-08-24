extends KinematicBody

export(NodePath) var nav_plus_path = null
export(NodePath) var nav_agent_path = null
export(NodePath) var to_path = null

onready var nav_plus : NavPlusLinkPath = get_node(nav_plus_path)
onready var nav_agent : NavigationAgent = get_node(nav_agent_path)
onready var to = get_node(to_path)

var link_from : Vector3 = Vector3.ZERO
var link_to : Vector3 = Vector3.ZERO
var link_id_one : int = -1
var link_id_two : int = -1
var give_back_id : bool = false
var use_link : bool = false
var jump_acc : Vector3 = Vector3.ZERO
var gravity : float = 40.0

var final_destination : Vector3 = Vector3.ZERO
var inter_destination : Vector3 = Vector3.ZERO
var direction : Vector3 = Vector3.ZERO
var velocity : Vector3 = Vector3.ZERO
var velocityXY : Vector3 = Vector3.ZERO
var snap : Vector3 = Vector3.DOWN

var timer : float = 0.0

enum {
	WALK,
	JUMP
}

var state : int = WALK

func _ready():
	set_physics_process(true)
	nav_agent.set_target_location(self.global_transform.origin)

func make_request():
	nav_plus.make_request({
							"obj"  : self,
							"type" : 0,
							"from" : NavigationServer.map_get_closest_point(nav_agent.get_navigation_map(),self.global_transform.origin),
							"to"   : final_destination
							})
	return

func _on_Camera_surface_hit(position):
	if link_id_one != -1 and link_id_two != -1:
		nav_plus.enable_path(link_id_one)
		nav_plus.enable_path(link_id_two)
	final_destination = NavigationServer.map_get_closest_point(nav_agent.get_navigation_map(),position)
	make_request()
	return
	
func parse_nav_info(info : Dictionary):
	if info["type"] == 1:
		use_link = true
		link_from = info["target"]
		link_to = info["to"]
		link_id_one = info["id_one"]
		link_id_two = info["id_two"]
	else:
		use_link = false
		link_id_one = -1
		link_id_two = -1
	inter_destination = info["target"]
	nav_agent.set_target_location(info["target"])
	return
	
func _physics_process(delta):
	if is_on_floor():
		velocity.y = -0.1
		snap = Vector3.DOWN
	else:
		velocity.y -= gravity * delta
		
	match state:
		WALK:
			if self.global_transform.origin.distance_squared_to(final_destination) > 2.0:
				var to2 : Vector3 = nav_agent.get_next_location()
				var dir_to_path : Vector3 = to2 - self.global_transform.origin
				direction = dir_to_path
				if use_link:
					var dtp_l = link_from - self.global_transform.origin
					if dtp_l.length_squared() <= 2.25:
						if nav_plus.check_path(link_id_one):
							nav_plus.disable_path(link_id_one)
							nav_plus.disable_path(link_id_two)
							direction = Vector3.ZERO
							var r : Vector3 = link_to - self.global_transform.origin
							jump_acc = r.normalized()
							velocity = Vector3(r.x, r.y + gravity/2.0, r.z)
							snap = Vector3.ZERO
							use_link = false
							state = JUMP
				if self.global_transform.origin.distance_squared_to(inter_destination) <= 2.0:
					make_request()
			else:
				direction = Vector3.ZERO
		JUMP:
			if timer >= 0.7 and not give_back_id:
				give_back_id = true
				nav_plus.enable_path(link_id_one)
			timer += delta
			if is_on_floor():
				if not give_back_id:
					nav_plus.enable_path(link_id_one)
				nav_plus.enable_path(link_id_two)
				make_request()
				state = WALK
		
	if state != JUMP:
		direction = direction.normalized()
		velocityXY = velocityXY.linear_interpolate(5*direction , 5*delta)
		velocity.x = velocityXY.x
		velocity.z = velocityXY.z
		nav_agent.set_velocity(velocity)
	else:
		velocity.x -= jump_acc.x*0.71*delta
		velocity.z -= jump_acc.z*0.71*delta
		move_and_slide_with_snap(velocity,snap,Vector3.UP)

func _on_NavigationAgent_velocity_computed(safe_velocity):
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	move_and_slide_with_snap(velocity, snap, Vector3.UP)
