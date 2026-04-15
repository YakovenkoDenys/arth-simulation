


extends Node3D

@onready var http_request = $HTTPRequest
var camera_done = false

# ТІ САМІ ЦИФРИ ДЛЯ ВСІХ
var center_x = 3398245.0
var center_z = -6525350.0

func _ready():
	http_request.request_completed.connect(_on_request_completed)
	http_request.request("http://127.0.0.1:5000/get_objects")

func lon_lat_to_mercator(lon, lat):
	var x = lon * 20037508.34 / 180.0
	var y = log(tan((90.0 + lat) * PI / 360.0)) / (PI / 180.0)
	y = y * 20037508.34 / 180.0
	return Vector2(x, -y)

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
	
	# Створюємо матеріал
	var material = StandardMaterial3D.new()
	
	# ПЕРЕВІРКА: якщо це столиця
	if data["type"] == "capital":
		mesh_instance.mesh.size = Vector3(50, 100, 50) # Дуже великий куб
		material.albedo_color = Color(1, 0, 0) # Яскраво-червоний
	else:
		# Звичайні будинки (як було раніше)
		mesh_instance.mesh.size = Vector3(2, 5, 2)
		material.albedo_color = Color(0.8, 0.4, 0.2) # Колір цегли
	
	mesh_instance.set_surface_override_material(0, material)
	
	# Розрахунок позиції (залишаємо твій робочий метод)
	var raw_pos = data["pos"].replace("POINT(", "").replace(")", "").split(" ")
	var m_pos = lon_lat_to_mercator(float(raw_pos[0]), float(raw_pos[1]))
	
	# Висота (Y): для столиці ставимо вище (50), для будинків низько (2.5)
	var h = 50.0 if data["type"] == "capital" else 2.5
	# СТАВИМО ВІДНОСНО ЦЕНТРУ
	mesh_instance.position = Vector3(m_pos.x - center_x, 5, m_pos.y - center_z)
	
	if not camera_done:
		var cam = get_viewport().get_camera_3d()
		if cam:
			cam.position = Vector3(0, 500, 500)
			cam.look_at(Vector3(0, 0, 0))
			camera_done = true
