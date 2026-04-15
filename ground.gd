extends Node3D

func _ready():
	#self.mesh = null # Видаляємо старий меш вузла
	var zoom = 2
	var tile_size = 256.0
	
	for x in range(4):
		for y in range(4):
			spawn_tile(zoom, x, y, tile_size)

func spawn_tile(z, x, y, size):
	var tile = MeshInstance3D.new()
	var p_mesh = PlaneMesh.new()
	p_mesh.size = Vector2(size+8, size+8)
	p_mesh.subdivide_depth = 128
	p_mesh.subdivide_width = 128
	tile.mesh = p_mesh
	
	var pos_x = (x * size) - 384.0
	var pos_z = (y * size) - 384.0
	# Мікро-зсув (x * 0.001) щоб прибрати мерехтіння
	tile.position = Vector3(pos_x, -1.0 + (x * 0.001), pos_z)
	add_child(tile)
	
	var mat = ShaderMaterial.new()
	mat.shader = load("res://terrain.gdshader")
	tile.set_surface_override_material(0, mat)
	
	# Базова адреса твого сервера
	var server = "http://127.0.0.1:5000"
	
	# 1. Запит на КОЛІР
	var http_color = HTTPRequest.new()
	add_child(http_color)
	http_color.request_completed.connect(self._on_data_loaded.bind(mat, "color_map"))
	var url_color = server + "/get_map/%d/%d/%d.png" % [z, x, y]
	http_color.request(url_color)
	
	# 2. Запит на ВИСОТУ
	var http_height = HTTPRequest.new()
	add_child(http_height)
	http_height.request_completed.connect(self._on_data_loaded.bind(mat, "height_map"))
	var url_height = server + "/get_height/%d/%d/%d.png" % [z, x, y]
	http_height.request(url_height)

func _on_data_loaded(_result, response_code, _headers, body, mat, param_name):
	if response_code == 200:
		var image = Image.new()
		if image.load_png_from_buffer(body) == OK:
			var tex = ImageTexture.create_from_image(image)
			# ВИМИКАЄМО ФІЛЬТРАЦІЮ (прибирає розриви на стиках)
			
			# Передаємо текстуру в шейдер під потрібним ім'ям (color_map або height_map)
			mat.set_shader_parameter(param_name, tex)
