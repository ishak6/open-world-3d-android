extends Node3D

const WORLD_SIZE := 180.0
const WALK_SPEED := 5.0
const RUN_SPEED := 8.0
const LOOK_SENSITIVITY := 0.004

var player: CharacterBody3D
var camera_pivot: Node3D
var camera: Camera3D
var move_vector := Vector2.ZERO
var look_finger := -1
var look_last := Vector2.ZERO
var is_running := false
var jump_requested := false
var status_label: Label
var joystick_origin := Vector2.ZERO
var joystick_active := false

func _ready() -> void:
	_build_environment()
	_build_world()
	_build_player()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.12, 0.34, 0.62)
	sky_material.sky_horizon_color = Color(0.62, 0.79, 0.91)
	sky_material.ground_bottom_color = Color(0.18, 0.22, 0.15)
	sky_material.ground_horizon_color = Color(0.55, 0.64, 0.52)
	environment.sky.sky_material = sky_material
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.78, 0.86)
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = environment
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

func _material(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _add_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, with_collision: bool = false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	body.add_child(mesh_instance)
	if with_collision:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	parent.add_child(body)
	return body

func _add_cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.position = pos
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)

func _build_world() -> void:
	var grass := _material(Color(0.27, 0.48, 0.24))
	var path_mat := _material(Color(0.57, 0.46, 0.31))
	var water_mat := _material(Color(0.12, 0.43, 0.62), 0.25)
	var wall_mats := [
		_material(Color(0.82, 0.69, 0.48)),
		_material(Color(0.72, 0.79, 0.72)),
		_material(Color(0.82, 0.78, 0.65))
	]
	var roof_mat := _material(Color(0.43, 0.19, 0.14))
	var trunk_mat := _material(Color(0.30, 0.19, 0.11))
	var leaf_mats := [
		_material(Color(0.12, 0.34, 0.16)),
		_material(Color(0.19, 0.43, 0.19)),
		_material(Color(0.28, 0.46, 0.20))
	]

	_add_box(self, Vector3(0, -0.55, 0), Vector3(WORLD_SIZE, 1, WORLD_SIZE), grass, true)
	_add_box(self, Vector3(0, -0.02, 0), Vector3(7, 0.12, WORLD_SIZE), path_mat)
	_add_box(self, Vector3(0, -0.01, -12), Vector3(48, 0.13, 3.4), path_mat)
	_add_box(self, Vector3(-54, -0.12, 12), Vector3(25, 0.18, WORLD_SIZE), water_mat)

	# A simple bridge over the river.
	_add_box(self, Vector3(-48, 0.2, 8), Vector3(15, 0.45, 4.5), path_mat, true)
	for side in [-1.0, 1.0]:
		_add_box(self, Vector3(-48, 0.8, 8 + side * 2.0), Vector3(15, 0.7, 0.18), trunk_mat)

	# Village houses: solid walls, roof and a dark doorway.
	var house_positions := [
		Vector3(13, 0, -17), Vector3(-15, 0, -18),
		Vector3(15, 0, 9), Vector3(-17, 0, 18),
		Vector3(29, 0, -2), Vector3(-31, 0, -23)
	]
	for i in range(house_positions.size()):
		var p: Vector3 = house_positions[i]
		var wall_mat: Material = wall_mats[i % wall_mats.size()]
		_add_box(self, p + Vector3(0, 1.7, 0), Vector3(8, 3.4, 7), wall_mat, true)
		_add_box(self, p + Vector3(0, 3.9, 0), Vector3(8.8, 0.45, 7.8), roof_mat)
		_add_box(self, p + Vector3(0, 1.05, 3.56), Vector3(1.35, 2.1, 0.12), _material(Color(0.18, 0.12, 0.09)))
		_add_box(self, p + Vector3(-2.1, 2.0, 3.57), Vector3(1.15, 1.0, 0.14), _material(Color(0.27, 0.58, 0.72)))

	# Farmland plots and crop rows.
	var soil := _material(Color(0.37, 0.25, 0.13))
	var crop := _material(Color(0.42, 0.63, 0.22))
	for plot in range(3):
		var plot_pos := Vector3(42, 0.02, -30 + plot * 13)
		_add_box(self, plot_pos, Vector3(19, 0.12, 9), soil)
		for row in range(5):
			for plant in range(8):
				_add_cylinder(self, plot_pos + Vector3(-8 + plant * 2.2, 0.55, -3.4 + row * 1.6), 0.13, 1.0, crop)

	# Forest ring and scattered trees.
	for i in range(90):
		var angle := float(i) * 2.399
		var radius := 55.0 + float(i % 5) * 5.0
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		if abs(x) < 35 and abs(z) < 35:
			continue
		_add_tree(Vector3(x, 0, z), trunk_mat, leaf_mats[i % leaf_mats.size()])

	# Rocks beside the river.
	var rock_mat := _material(Color(0.40, 0.43, 0.42))
	for i in range(18):
		var rock := MeshInstance3D.new()
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = 0.8 + float(i % 3) * 0.25
		rock_mesh.height = 1.0 + float(i % 2) * 0.4
		rock.mesh = rock_mesh
		rock.material_override = rock_mat
		rock.position = Vector3(-40 + float(i % 3) * 2.0, 0.15, -35 + i * 4.0)
		rock.scale = Vector3(1.4, 0.8, 1.0)
		add_child(rock)

func _add_tree(pos: Vector3, trunk_mat: Material, leaf_mat: Material) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.28
	trunk_mesh.bottom_radius = 0.42
	trunk_mesh.height = 3.4
	trunk.mesh = trunk_mesh
	trunk.material_override = trunk_mat
	trunk.position = pos + Vector3(0, 1.7, 0)
	add_child(trunk)

	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 2.0
	crown_mesh.height = 3.7
	crown.mesh = crown_mesh
	crown.material_override = leaf_mat
	crown.position = pos + Vector3(0, 4.0, 0)
	add_child(crown)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 2, 20)
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.48
	capsule.height = 1.9
	var body_mesh := MeshInstance3D.new()
	body_mesh.mesh = capsule
	body_mesh.position.y = 0.95
	body_mesh.material_override = _material(Color(0.12, 0.35, 0.78))
	player.add_child(body_mesh)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.48
	shape.height = 1.9
	collision.shape = shape
	collision.position.y = 0.95
	player.add_child(collision)

	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.55
	player.add_child(camera_pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.0, 5.5)
	camera.rotation_degrees.x = -10
	camera.current = true
	camera_pivot.add_child(camera)
	add_child(player)

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	var panel := ColorRect.new()
	panel.color = Color(0.025, 0.06, 0.09, 0.72)
	panel.position = Vector2(18, 16)
	panel.size = Vector2(390, 66)
	hud.add_child(panel)

	status_label = Label.new()
	status_label.position = Vector2(32, 27)
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1))
	status_label.text = "VILLAGE FRONTIER   •   OFFLINE"
	hud.add_child(status_label)

	var hint := Label.new()
	hint.text = "Left: move   •   Right: look   •   RUN / JUMP"
	hint.position = Vector2(20, 88)
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	hud.add_child(hint)

	var run_button := _make_button("RUN", Vector2(-170, -150), Vector2(125, 58))
	run_button.anchor_left = 1.0
	run_button.anchor_top = 1.0
	run_button.anchor_right = 1.0
	run_button.anchor_bottom = 1.0
	run_button.button_down.connect(func(): is_running = true)
	run_button.button_up.connect(func(): is_running = false)
	hud.add_child(run_button)

	var jump_button := _make_button("JUMP", Vector2(-170, -78), Vector2(125, 58))
	jump_button.anchor_left = 1.0
	jump_button.anchor_top = 1.0
	jump_button.anchor_right = 1.0
	jump_button.anchor_bottom = 1.0
	jump_button.pressed.connect(func(): jump_requested = true)
	hud.add_child(jump_button)

	var joystick := Control.new()
	joystick.name = "TouchJoystick"
	joystick.anchor_left = 0.0
	joystick.anchor_top = 1.0
	joystick.anchor_right = 0.0
	joystick.anchor_bottom = 1.0
	joystick.position = Vector2(28, -205)
	joystick.size = Vector2(150, 150)
	joystick.gui_input.connect(_on_joystick_input)
	hud.add_child(joystick)
	var base := ColorRect.new()
	base.position = Vector2(8, 8)
	base.size = Vector2(134, 134)
	base.color = Color(0.12, 0.18, 0.22, 0.42)
	joystick.add_child(base)
	var knob := ColorRect.new()
	knob.position = Vector2(48, 48)
	knob.size = Vector2(54, 54)
	knob.color = Color(0.75, 0.85, 0.95, 0.65)
	joystick.add_child(knob)

func _make_button(caption: String, pos: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = pos
	button.size = button_size
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.25, 0.42, 0.88)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.12, 0.48, 0.68, 0.95)))
	return button

func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	return style

func _on_joystick_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		joystick_active = event.pressed
		if not event.pressed:
			move_vector = Vector2.ZERO
	elif event is InputEventScreenDrag and joystick_active:
		var center := Vector2(75, 75)
		move_vector = (event.position - center).limit_length(58) / 58.0
	elif event is InputEventMouseButton:
		joystick_active = event.pressed
	elif event is InputEventMouseMotion and joystick_active:
		move_vector = (event.position - Vector2(75, 75)).limit_length(58) / 58.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * LOOK_SENSITIVITY)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - event.relative.y * LOOK_SENSITIVITY, -0.9, 0.45)
	elif event is InputEventScreenTouch:
		if event.pressed and event.position.x > get_viewport().get_visible_rect().size.x * 0.42:
			look_finger = event.index
			look_last = event.position
		elif not event.pressed and event.index == look_finger:
			look_finger = -1
	elif event is InputEventScreenDrag and event.index == look_finger:
		var look_delta: Vector2 = event.position - look_last
		look_last = event.position
		camera_pivot.rotate_y(-look_delta.x * LOOK_SENSITIVITY)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - look_delta.y * LOOK_SENSITIVITY, -0.9, 0.45)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var keyboard := Vector2.ZERO
	keyboard = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var input_vector := move_vector if move_vector.length() > 0.08 else keyboard
	var direction := (player.transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	if direction.length() > 0.01:
		player.velocity.x = direction.x * (RUN_SPEED if is_running else WALK_SPEED)
		player.velocity.z = direction.z * (RUN_SPEED if is_running else WALK_SPEED)
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), delta * 8.0)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, WALK_SPEED * 4.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, WALK_SPEED * 4.0 * delta)

	if not player.is_on_floor():
		player.velocity.y -= 9.8 * delta
	elif jump_requested:
		player.velocity.y = 5.0
	jump_requested = false
	player.move_and_slide()
	player.position.x = clamp(player.position.x, -WORLD_SIZE * 0.48, WORLD_SIZE * 0.48)
	player.position.z = clamp(player.position.z, -WORLD_SIZE * 0.48, WORLD_SIZE * 0.48)
