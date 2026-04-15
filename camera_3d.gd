extends Camera3D

@export var speed: float = 50.0
@export var sensitivity: float = 0.1

func _process(delta):
	# Рух клавішами
	var dir = Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir -= global_transform.basis.z
	if Input.is_key_pressed(KEY_S): dir += global_transform.basis.z
	if Input.is_key_pressed(KEY_A): dir -= global_transform.basis.x
	if Input.is_key_pressed(KEY_D): dir += global_transform.basis.x
	if Input.is_key_pressed(KEY_Q): dir += Vector3.UP
	if Input.is_key_pressed(KEY_E): dir += Vector3.DOWN
	
	global_translate(dir.normalized() * speed * delta)

func _input(event):
	# Огляд мишкою при затиснутій правій кнопці
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		rotate_y(deg_to_rad(-event.relative.x * sensitivity))
		rotate_x(deg_to_rad(-event.relative.y * sensitivity))
		rotation.x = clamp(rotation.x, deg_to_rad(-90), deg_to_rad(90))
