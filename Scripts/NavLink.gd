tool
extends Position3D
class_name NavPlusNavLink

enum LINKTYPE {
	JUMP,
	TELEPORT,
	CLIMB,
	NONE
}

export(LINKTYPE) var type

func get_one() -> Vector3:
	if Engine.editor_hint:
		var One = self.global_transform.origin
		var space_state : PhysicsDirectSpaceState = get_world().direct_space_state
		var result = space_state.intersect_ray(One,One + Vector3(0,-5,0),[],2)
		return result["position"] + Vector3(0,2,0)
	else:
		return Vector3.ZERO

func get_two() -> Vector3:
	if Engine.editor_hint:
		var Two = $To.global_transform.origin
		var space_state : PhysicsDirectSpaceState = get_world().direct_space_state
		var result = space_state.intersect_ray(Two,Two + Vector3(0,-5,0),[],2)
		return result["position"] + Vector3(0,2,0)
	else:
		return Vector3.ZERO
		
func get_type() -> int:
	return type

func _enter_tree() -> void:
	if Engine.editor_hint:
		var nodes = self.get_children()
		for n in nodes:
			if n.name == "To":
				return
		var node = Position3D.new()
		node.name = "To"
		node.transform.origin = Vector3.ZERO
		add_child(node)
		node.set_owner(get_tree().get_edited_scene_root())
	return
	
