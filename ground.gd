extends Node3D

func _ready():
	# 1. Очищуємо вузол від старих об'єктів
	for n in get_children():
		n.queue_free()
	
	var zoom = 2
	var tile_size = 256.0
	
	# 2. ОДИН цикл для створення сітки 4x4
	for x in range(4):
		for y in range(4):
			var tile = MeshInstance3D.new()
			tile.mesh = PlaneMesh.new()
			tile.mesh.size = Vector2(tile_size, tile_size)
			
			# МАТЕМАТИКА ЦЕНТРУВАННЯ:
			# Початок координат (0,0) буде точно в центрі всієї карти світу.
			# Ми віднімаємо 384, щоб змістити сітку (256 * 1.5)
			var pos_x = (x * tile_size) - 384.0
			var pos_z = (y * tile_size) - 384.0
			
			# Висота -0.1, щоб бути під кубами, і мікро-зсув 0.001 для усунення мерехтіння
			tile.position = Vector3(pos_x, -0.1 + (x * 0.001), pos_z)
			add_child(tile)
			
			# 3. Запит на сервер (використовуємо твій робочий формат)
			var http = HTTPRequest.new()
			add_child(http)
			http.request_completed.connect(self._on_tile_loaded.bind(tile))
			
			var url = "http://127.0.0.1:5000/get_map/%d/%d/%d.png" % [zoom, x, y]
			http.request(url)

func _on_tile_loaded(_result, response_code, _headers, body, tile):
	if response_code == 200:
		var image = Image.new()
		if image.load_png_from_buffer(body) == OK:
			var tex = ImageTexture.create_from_image(image)
			var mat = StandardMaterial3D.new()
			mat.albedo_texture = tex
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			# Важливо: вимикаємо фільтрацію, щоб не було сірих ліній на стиках
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			tile.set_surface_override_material(0, mat)
