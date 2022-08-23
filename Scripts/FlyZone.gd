tool
extends Node
class_name NavPlusZonePath

var StartPoint : Vector3
var x_max : float = -1e20
var x_min : float = 1e20
var y_max : float = -1e20
var y_min : float = 1e20
var z_max : float = -1e20
var z_min : float = 1e20
	
func setup_info() -> void:
	var ArrayPoints : Array = [	$PointOne.global_transform.origin, $PointTwo.global_transform.origin]
	StartPoint = $GenerationStart.global_transform.origin
	
	for p in ArrayPoints:
		if p.x > x_max:
			x_max = p.x
		if p.x < x_min:
			x_min = p.x
		if p.y > y_max:
			y_max = p.y
		if p.y < y_min:
			y_min = p.y
		if p.z > z_max:
			z_max = p.z
		if p.z < z_min:
			z_min = p.z
	return

func _enter_tree() -> void:
	if Engine.editor_hint:
		var nodes = self.get_children()
		var i : int = 0
		for n in nodes:
			if n.name == "GenerationStart" or n.name == "PointOne" or n.name == "PointTwo":
				i += 1
		if i >= 3:
			return
		var node1 = Position3D.new()
		node1.name = "GenerationStart"
		node1.transform.origin = Vector3.ZERO
		add_child(node1)
		node1.set_owner(get_tree().get_edited_scene_root())
		
		var node2 = Position3D.new()
		node2.name = "PointOne"
		node2.transform.origin = Vector3.ZERO
		add_child(node2)
		node2.set_owner(get_tree().get_edited_scene_root())
		
		var node3 = Position3D.new()
		node3.name = "PointTwo"
		node3.transform.origin = Vector3.ZERO
		add_child(node3)
		node3.set_owner(get_tree().get_edited_scene_root())
	return
