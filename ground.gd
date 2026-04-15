extends MeshInstance3D

func _ready():
	var map_request = HTTPRequest.new()
	add_child(map_request)
	map_request.request_completed.connect(_on_map_loaded)
	# Запит на сервер (без зайвих цифр)
	map_request.request("http://127.0.0.1:5000/get_map")

func _on_map_loaded(_result, response_code, _headers, body):
	if response_code == 200:
		self.mesh.size = Vector2(1000, 1000) # Робимо великою для тесту
		self.position = Vector3(0, 0, 0)
		
		var image = Image.new()
		if image.load_png_from_buffer(body) == OK:
			var tex = ImageTexture.create_from_image(image)
			var mat = StandardMaterial3D.new()
			mat.albedo_texture = tex
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			self.set_surface_override_material(0, mat)
			print("КАРТА ЗАВАНТАЖЕНА В ЦЕНТР (0,0,0)")
			
			# ПРИМУСОВО СТАВИМО КАМЕРУ НАД КАРТОЮ
			var cam = get_viewport().get_camera_3d()
			if cam:
				cam.position = Vector3(0, 500, 0)
				cam.look_at(Vector3(0, 0, 0))
