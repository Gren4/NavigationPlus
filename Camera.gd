extends Camera

signal surface_hit(position)

var mouse_pressed: bool

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT && event.is_pressed():
			var space_state = get_world().direct_space_state
			var mouse_position = get_viewport().get_mouse_position()
			var rayOrigin = project_ray_origin(mouse_position)
			var rayEnd = rayOrigin + project_ray_normal(mouse_position) * 2000
			var intersection = space_state.intersect_ray(rayOrigin, rayEnd)
			emit_signal("surface_hit", intersection.position)
