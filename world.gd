


extends Node3D

@onready var http_request = $HTTPRequest
var camera_done = false

# ТІ САМІ ЦИФРИ ДЛЯ ВСІХ
var center_x = 3398245.0
var center_z = -6525350.0

func _ready():
	http_request.request_completed.connect(_on_request_completed)
	http_request.request("https://arth-simulation.onrender.com/get_objects")

func lon_lat_to_mercator(lon, lat):
	# X: від 0 до 1024
	var x = (lon + 180.0) * (1024.0 / 360.0)
	# Y: від 0 до 1024 (Меркатор)
	var lat_rad = deg_to_rad(lat)
	var y = (1.0 - log(tan(lat_rad) + (1.0 / cos(lat_rad))) / PI) / 2.0 * 1024.0
	return Vector2(x, y)

func _on_request_completed(_result, response_code, _headers, body):
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json is Array:
			for obj in json:
				spawn_object(obj)

func spawn_object(data):
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	add_child(mesh_instance)
	
	var material = StandardMaterial3D.new()
	
	if data["type"] == "capital":
		mesh_instance.mesh.size = Vector3(0.5, 2, 0.5) # Вежа
		material.albedo_color = Color(1, 0, 0) # Червоний
	else:
		mesh_instance.mesh.size = Vector3(0.1, 0.5, 0.1)
		material.albedo_color = Color(0.8, 0.4, 0.2)
	
	mesh_instance.set_surface_override_material(0, material)
	
	var raw_pos = data["pos"].replace("POINT(", "").replace(")", "").split(" ")
	var m_pos = lon_lat_to_mercator(float(raw_pos[0]), float(raw_pos[1]))
	
	# Висота: столиці на 50, будинки на 2.5
	var h = 2 if data["type"] == "capital" else 1
	
	# ТУТ ВИПРАВЛЕННЯ: використовуємо m_pos.y для осі Z у Godot
	# Віднімаємо 512, щоб центр карти (0,0) збігався з центром сцени
	mesh_instance.position = Vector3(m_pos.x - 512, h, m_pos.y - 512)
	
	if not camera_done:
		var cam = get_viewport().get_camera_3d()
		if cam:
			cam.position = Vector3(0, 1000, 1000) # Камера вище, щоб бачити весь світ
			cam.look_at(Vector3(0, 0, 0))
			camera_done = true
