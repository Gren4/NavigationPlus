extends KinematicBody


export(NodePath) var to_path = null
onready var to = get_node(to_path)
# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var direction : Vector3 = Vector3.ZERO
var velocity : Vector3 = Vector3.ZERO
var velocityXY : Vector3 = Vector3.ZERO
var snap : Vector3 = Vector3.DOWN

# Called when the node enters the scene tree for the first time.
func _ready():
	$NavigationAgent.set_target_location(to.global_transform.origin)


func _physics_process(delta):
	$NavigationAgent.set_target_location(to.global_transform.origin)
	var to2 : Vector3 = $NavigationAgent.get_next_location()
	var dir_to_path : Vector3 = to2 - self.global_transform.origin
	direction = dir_to_path
	direction = direction.normalized()
	velocityXY = velocityXY.linear_interpolate(direction , delta)
	velocity.x = velocityXY.x
	velocity.z = velocityXY.z
	move_and_slide_with_snap(velocity, snap, Vector3.UP)
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
