tool
extends Spatial
class_name NavPlusLinkPath

export(String) var SAVE_PATH := "res://Nav/"

var first_time : bool = true
export (bool) var generate_nav setget _generate
export (bool) var make_flight_zone = true

export(String) var save_name = "save"

export (int) var step_gridxz = 15
export (int) var step_gridy = 8
export (int) var bit_mask = 2

var astar : AStar
var astar_fly : AStar	
var polygon : Dictionary = {}

var links_col : int = 0
var link_one : PoolIntArray = []
var link_two : PoolIntArray = []
var link_type : PoolIntArray = []

var disabled_links : Dictionary = {}

var requests : Array = []
var main_thread : Thread
var mutex : Mutex
var close_thread : bool = false

onready var complete : bool = false
var file : File = File.new()

enum LINKTYPE {
	JUMP,
	TELEPORT,
	CLIMB,
	NONE
}

############################# CODE FOR SETUPING THE SCRIPT #############################
func _enter_tree() -> void:
	if Engine.editor_hint:
		if first_time:
			first_time = false
			return

func _ready() -> void:
	if not Engine.editor_hint:
		initiate()
		complete = true
	return

func _generate(generate_nav : bool) -> void:
	if Engine.editor_hint:
		if first_time:
			first_time = false
			return
	close_thread()
	var error = file.open(SAVE_PATH+save_name+".tres", File.WRITE)
	if error != OK:
		print("Bad save write")
		return
	complete = false
	links_col = 0
	link_one.resize(0)
	link_two.resize(0)
	link_type.resize(0)
	_generate_astar_points()
	if make_flight_zone:
		_generate_fly_astar_points()
	file.close()
	print("Generation complete!")

func _read_astar(astar_points : Dictionary) -> void:
	var col_p = astar_points["astar_points"]["id"].size()
	for i in range(col_p):
		astar.add_point(i,astar_points["astar_points"]["coords"][i])
	for i in range(col_p):
		var col_n = astar_points["astar_points"]["neighboor"][i].size()
		for j in range(col_n):
			astar.connect_points(i,astar_points["astar_points"]["neighboor"][i][j])
	return

func _read_astar_fly(astar_fly_points : Dictionary) -> void:
	var col_f_p = astar_fly_points["astar_fly_points"]["id"].size()
	for i in range(col_f_p):
		astar_fly.add_point(i,astar_fly_points["astar_fly_points"]["coords"][i])
	for i in range(col_f_p):
		var col_f_n = astar_fly_points["astar_fly_points"]["neighboor"][i].size()
		for j in range(col_f_n):
			astar_fly.connect_points(i,astar_fly_points["astar_fly_points"]["neighboor"][i][j])
	return

func initiate() -> void:
	if file.file_exists(SAVE_PATH+save_name+".tres"):
		var thread1 : Thread = Thread.new()
		var thread2 : Thread = Thread.new()
		file.open(SAVE_PATH+save_name+".tres", File.READ)
		astar = AStar.new()
		polygon = file.get_var()
		var astar_points : Dictionary = file.get_var()
		var link_info : Dictionary = file.get_var()
		links_col = link_info["links_col"]
		link_one = link_info["link_one"]
		link_two = link_info["link_two"]
		link_type = link_info["link_type"]
		disabled_links.clear()	
		
		thread1.start(self,"_read_astar",astar_points)
		if make_flight_zone:
			var astar_fly_points : Dictionary = file.get_var()
			astar_fly = AStar.new()
			thread2.start(self,"_read_astar_fly",astar_fly_points)
			thread2.wait_to_finish()
		thread1.wait_to_finish()
		file.close()
		mutex = Mutex.new()
		close_thread = false
		main_thread = Thread.new()
		main_thread.start(self,"request_handler")
	return

############################# SERVER CODE (THREAD HANDLING) #############################
func make_request(info : Dictionary) -> void:
	mutex.lock()
	for i in requests:
		if i["obj"] == info["obj"]:
			i["to"] = info["to"]
			i["from"] = info["from"]
			mutex.unlock()
			return
	requests.append(info)
	mutex.unlock()
	return

func request_handler() -> void:
	while true:
		if close_thread:
			break
		mutex.lock()
		if requests.size() > 0:
			var info : Dictionary = requests.pop_front()
			if info["type"] == 0:
				info["obj"].parse_nav_info(get_path_links(info["from"],info["to"]))
			elif info["type"] == 1:
				info["obj"].parse_nav_info(get_flyer_path(info["from"],info["to"]))
		mutex.unlock()
	return

func close_thread() -> void:
	if not Engine.editor_hint:
		close_thread = true
		main_thread.wait_to_finish()
	return

func _exit_tree() -> void:
	close_thread()
	return

############################# CLIENT CODE #############################
func get_path_links(from: Vector3, to: Vector3) -> Dictionary:
	var a_path : PoolIntArray = _find_path(from, to)
	var size_a = a_path.size()
	if size_a == 0:
		return {
			"type": 0,
			"target": from,
			"to": [],
			"id_one": -1,
			"id_two": -1
		}

	for i in range(size_a - 1):
		for j in range(links_col):
			if (a_path[i] == link_one[j] and a_path[i+1] == link_two[j]):
				return {
					"type": 1,
					"target": astar.get_point_position(link_one[j]),
					"to": astar.get_point_position(link_two[j]),
					"id_one": link_one[j],
					"id_two": link_two[j],
					"link_type" : link_type[j]
				}	
			elif (a_path[i] == link_two[j] and a_path[i+1] == link_one[j]):
				return {
					"type": 1,
					"target": astar.get_point_position(link_two[j]),
					"to": astar.get_point_position(link_one[j]),
					"id_one": link_two[j],
					"id_two": link_one[j],
					"link_type" : link_type[j]
				}	
	return {
		"type": 0,
		"target": to,
		"to": [],
		"id_one": -1,
		"id_two": -1,
		"link_type" : LINKTYPE.NONE
	}	
	
func _find_path(from: Vector3, to: Vector3) -> PoolIntArray:
	if complete:
		if is_instance_valid(astar):
			var start_id : int = 0
			var end_id : int = 0
			var start_d : float = 1e20
			var end_d : float = 1e20
			var one_stop : bool = false
			var two_stop : bool = false
			for d in range(polygon.size()):
				var vstart = Geometry.ray_intersects_triangle(from + Vector3(0,0.5,0), Vector3.DOWN,polygon[d]["verts"][0],polygon[d]["verts"][1],polygon[d]["verts"][2])
				if vstart != null and not one_stop:
					var d_temp : float = (vstart - from).length_squared()
					if (d_temp < start_d):
						start_id = polygon[d]["id"]
						start_d = d_temp
				for i in polygon[d]["verts"]:
					var d_temp : float = (i - from).length_squared()
					if (d_temp < start_d):
						start_id = polygon[d]["id"]
						start_d = d_temp
					
				var vend = Geometry.ray_intersects_triangle(to + Vector3(0,0.5,0), Vector3.DOWN,polygon[d]["verts"][0],polygon[d]["verts"][1],polygon[d]["verts"][2])
				if vend != null and not two_stop:
					var d_temp : float = (vend - to).length_squared()
					if (d_temp < end_d):
						end_id = polygon[d]["id"]
						end_d = d_temp
				for i in polygon[d]["verts"]:
					var d_temp : float = (i - to).length_squared()
					if (d_temp < end_d):
						end_id = polygon[d]["id"]
						end_d = d_temp

			return astar.get_id_path(start_id, end_id)
		else:
			var empty : PoolIntArray = []
			return empty
	else:
		var empty : PoolIntArray = []
		return empty

func get_flyer_path(from: Vector3, to: Vector3) -> Dictionary:
	if complete:
		if is_instance_valid(astar_fly):
			var start_id : int = astar_fly.get_closest_point(from)
			var end_id : int = astar_fly.get_closest_point(to)
			var path : PoolVector3Array = astar_fly.get_point_path(start_id, end_id)
			var path_id : PoolIntArray = astar_fly.get_id_path(start_id, end_id)
			for i in path_id:
				disable_fly_path(i)
			return {"path" : path, "path_id" : path_id}
		else:
			return {"path" : [], "path_id" : []}
	else:
		return {"path" : [], "path_id" : []}

##### ADDITIONAL CODE FOR PROCESSING THE AVAILABILITY OF LINKS #####
func disable_path(id : int) -> void:
	if disabled_links.has(id):
		if disabled_links[id] != 1:
			disabled_links[id] = 1
			astar.set_point_weight_scale(id,2.0)
	else:
		disabled_links[id] = 1
	return
	
func enable_path(id : int) -> void:
	if disabled_links.has(id):
		if disabled_links[id] != 0:
			disabled_links[id] = 0
			astar.set_point_weight_scale(id,1.0)
	return
	
func check_path(id : int) -> bool:
	if disabled_links.has(id):
		if disabled_links[id] == 0:
			return true
		else:
			return false
	else:
		return true

func disable_fly_path(id : int) -> void:
	astar_fly.set_point_disabled(id, true)
	return
	
func enable_fly_path(id : int) -> void:
	astar_fly.set_point_disabled(id, false)
	return

############################# CODE FOR GENERATING ASTAR #############################
func _check_doubles(d : Dictionary, i : int) -> int:
	if d.has(i):
		return d[i]
	else:
		return i
	
func _generate_astar_points() -> void:
	var astar_info : Dictionary = {}
	astar_info["astar_points"] = {"id" : [], "neighboor" : [], "coords" : []}
	astar = AStar.new()
	var offset : int = 0
	var NavMeshInstance = get_tree().get_nodes_in_group("NavMeshInstance")
	
	for n in NavMeshInstance:
		var doubles : Dictionary = {} 
		var main_vert : PoolVector3Array = []
		var points_of_verts : Dictionary = {}
		var NavMesh = n.navmesh
		main_vert = NavMesh.get_vertices()
		var vert_count : int = main_vert.size()
		var poly_count : int = NavMesh.get_polygon_count()
		
		var exclude : Array = []
		for i in range(vert_count):
			if i in exclude:
				continue
			for j in range(vert_count):
				if i == j:
					continue
				else:
					if main_vert[i] == main_vert[j]:
						exclude.append(j)
						doubles[j] = i
						
		for i in range(poly_count):
			var index_arr : Array = NavMesh.get_polygon(i)
			var a_id = astar.get_available_point_id()
			var center : Vector3 = Vector3.ZERO
			var col_v : int = index_arr.size()
			var verts : PoolVector3Array = []
			for a in range(col_v):
				var chck : int = _check_doubles(doubles, index_arr[a])
				var coords : Vector3 = main_vert[chck].rotated(Vector3.UP,n.rotation_degrees.y) + n.global_transform.origin
				verts.append(coords)
				center += coords
				if points_of_verts.has(chck):
					points_of_verts[chck].append(a_id)
				else:
					points_of_verts[chck] = [a_id]
			polygon[i + offset] = {"verts" : verts, "id" : a_id }
			
			center = center / col_v
			astar.add_point(a_id,center)
			astar_info["astar_points"]["id"].append(a_id)
			astar_info["astar_points"]["coords"].append(center)
			astar_info["astar_points"]["neighboor"].append([])
			
			for a in range(col_v):
				var chck : int = _check_doubles(doubles, index_arr[a])
				if points_of_verts[chck].size() > 0:
					for j in range(points_of_verts[chck].size()):
						if not astar.are_points_connected(a_id, points_of_verts[chck][j]) and a_id != points_of_verts[chck][j]:
							astar.connect_points(a_id, points_of_verts[chck][j])
							astar_info["astar_points"]["neighboor"][a_id].append(points_of_verts[chck][j])
		offset += poly_count
		
	if Engine.editor_hint:
		file.store_var(polygon,true)
	
	var nav_link_group = get_tree().get_nodes_in_group("NavLinks")
	for p in nav_link_group:
		var one : Vector3 = p.get_one()
		var two : Vector3 = p.get_two()
		var a_id1 = astar.get_available_point_id()
		astar.add_point(a_id1, one)
		astar_info["astar_points"]["id"].append(a_id1)
		astar_info["astar_points"]["coords"].append(one)
		astar_info["astar_points"]["neighboor"].append([])
		var a_id2 = astar.get_available_point_id()
		astar.add_point(a_id2, two)
		astar_info["astar_points"]["id"].append(a_id2)
		astar_info["astar_points"]["coords"].append(two)
		astar_info["astar_points"]["neighboor"].append([])
		link_one.append(a_id1)
		link_two.append(a_id2)
		link_type.append(p.get_type())
		if not astar.are_points_connected(a_id1, a_id2):
			astar.connect_points(a_id1, a_id2)
			astar_info["astar_points"]["neighboor"][a_id1].append(a_id2)
			
		var one_d : float = 1e20
		var one_id : int = 0
		var two_d : float = 1e20
		var two_id : int = 0
		for d in range(polygon.size()):
			var vone = Geometry.ray_intersects_triangle(one, Vector3.DOWN,polygon[d]["verts"][0],polygon[d]["verts"][1],polygon[d]["verts"][2])
			if vone != null:
				var d_temp : float = (vone - one).length_squared()
				if (d_temp < one_d):
					one_id = polygon[d]["id"]
					one_d = d_temp
			for i in polygon[d]["verts"]:
				var d_temp : float = (i - one).length_squared()
				if (d_temp < one_d):
					one_id = polygon[d]["id"]
					one_d = d_temp
			var vtwo = Geometry.ray_intersects_triangle(two, Vector3.DOWN,polygon[d]["verts"][0],polygon[d]["verts"][1],polygon[d]["verts"][2])
			if vtwo != null:
				var d_temp : float = (vtwo - two).length_squared()
				if (d_temp < two_d):
					two_id = polygon[d]["id"]
					two_d = d_temp
			for i in polygon[d]["verts"]:
				var d_temp : float = (i - two).length_squared()
				if (d_temp < two_d):
					two_id = polygon[d]["id"]
					two_d = d_temp
		if not astar.are_points_connected(a_id1,one_id):
			astar.connect_points(a_id1,one_id)
			astar_info["astar_points"]["neighboor"][a_id1].append(one_id)
		if not astar.are_points_connected(a_id2,two_id):
			astar.connect_points(a_id2,two_id)
			astar_info["astar_points"]["neighboor"][a_id2].append(two_id)
	links_col = link_one.size()
	if Engine.editor_hint:
		file.store_var(astar_info,true)	
		var links : Dictionary = {
			"links_col" : links_col,
			"link_one" : link_one,
			"link_two" : link_two,
			"link_type" : link_type
		}
		file.store_var(links,true)
	return

func _generate_fly_astar_points() -> void:
	astar_fly = AStar.new()
	var astar_info : Dictionary = {}
	astar_info["astar_fly_points"] = {"id" : [], "neighboor" : [], "coords" : []}
	var ray : PhysicsDirectSpaceState = get_world().direct_space_state
	var zones  = get_tree().get_nodes_in_group("FlyZones")
	for z in zones:
		z.setup_info()
	astar_info = check_and_place(zones, ray, zones[0].StartPoint, astar_info)
	if Engine.editor_hint:
		file.store_var(astar_info,true)
	return

func check_and_place(z : Array, ray : PhysicsDirectSpaceState, start : Vector3, astar_info : Dictionary) -> Dictionary:
	var fly_points_id : Array = []
	var stack : Array = [start]
	var fly_points_locale : Array = []
	var offset = [
					Vector3( step_gridxz,0,0),
					Vector3(-step_gridxz,0,0),
					Vector3(0, step_gridy,0),
					Vector3(0,-step_gridy,0),
					Vector3(0,0, step_gridxz),
					Vector3(0,0,-step_gridxz),
					
					Vector3( step_gridxz,step_gridy,0),
					Vector3(-step_gridxz,step_gridy,0),
					Vector3(0,step_gridy, step_gridxz),
					Vector3(0,step_gridy,-step_gridxz),
					Vector3( step_gridxz,-step_gridy,0),
					Vector3(-step_gridxz,-step_gridy,0),
					Vector3(0,-step_gridy, step_gridxz),
					Vector3(0,-step_gridy,-step_gridxz),
					
					Vector3( step_gridxz,step_gridy,step_gridxz),
					Vector3(-step_gridxz,step_gridy,step_gridxz),
					Vector3(step_gridxz,step_gridy, step_gridxz),
					Vector3(step_gridxz,step_gridy,-step_gridxz),
					Vector3( step_gridxz,-step_gridy,step_gridxz),
					Vector3(-step_gridxz,-step_gridy,step_gridxz),
					Vector3(step_gridxz,-step_gridy, step_gridxz),
					Vector3(step_gridxz,-step_gridy,-step_gridxz),
				]
	
	fly_points_locale.append(start)
	var a_id : int = astar_fly.get_available_point_id()
	astar_fly.add_point(a_id,start)
	astar_info["astar_fly_points"]["id"].append(a_id)
	astar_info["astar_fly_points"]["coords"].append(start)
	astar_info["astar_fly_points"]["neighboor"].append([])
	fly_points_id.append(a_id)
	
	var id_stack : Array = [a_id]
	var dead_end : bool
	while (stack.size() > 0):
		dead_end = true
		for f in range(22):
			var new_point : Vector3 = stack.back() + offset[f]
			var do_continue : int = 0
			for i in z:
				if new_point.x > i.x_max or new_point.x < i.x_min or new_point.y > i.y_max or new_point.y < i.y_min or new_point.z > i.z_max or new_point.z < i.z_min:
					do_continue += 1 
			if do_continue >= z.size():
				continue
			var result = ray.intersect_ray(stack.back(),new_point,[],bit_mask)
			if not result:
				var cont : bool = false
				if not new_point in fly_points_locale:
					fly_points_locale.append(new_point)
					a_id = astar_fly.get_available_point_id()
					fly_points_id.append(a_id)
					astar_fly.add_point(a_id,new_point)
					astar_info["astar_fly_points"]["id"].append(a_id)
					astar_info["astar_fly_points"]["coords"].append(new_point)
					astar_info["astar_fly_points"]["neighboor"].append([])
					cont = true
				else:
					a_id = fly_points_id[fly_points_locale.find(new_point)]
				if not astar_fly.are_points_connected(a_id, id_stack.back()):
					astar_fly.connect_points(id_stack.back(), a_id)
					astar_info["astar_fly_points"]["neighboor"][a_id].append(id_stack.back())
				if cont == true:
					stack.append(new_point)
					id_stack.append(a_id)
					dead_end = false
					break
		if dead_end == true:
			stack.pop_back()
			id_stack.pop_back()
	return astar_info
