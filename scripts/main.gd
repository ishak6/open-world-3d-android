extends Node3D

# Village Frontier - streamed procedural world
const WORLD_SEED := 481516
const CHUNK_SIZE := 64.0
const LOAD_RADIUS := 3
const UNLOAD_RADIUS := 4
const WALK_SPEED := 5.2
const RUN_SPEED := 8.8
const LOOK_SENSITIVITY := 0.0042
const GRAVITY := 18.0

var player: CharacterBody3D
var camera_pivot: Node3D
var camera: Camera3D
var move_vector := Vector2.ZERO
var look_finger := -1
var look_last := Vector2.ZERO
var is_running := false
var jump_requested := false
var status_label: Label
var chunk_label: Label
var joystick: Control
var joystick_knob: ColorRect
var joystick_active := false
var current_chunk := Vector2i(999999, 999999)
var loaded_chunks: Dictionary = {}
var biome_noise := FastNoiseLite.new()
var pause_panel: PanelContainer
var is_paused := false

func _ready() -> void:
	_setup_noise()
	_build_environment()
	_build_player()
	_build_hud()
	_update_chunks(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _setup_noise() -> void:
	biome_noise.seed = WORLD_SEED
	biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	biome_noise.frequency = 0.0032
	biome_noise.fractal_octaves = 3
	biome_noise.fractal_lacunarity = 2.0
	biome_noise.fractal_gain = 0.48

func _material(color: Color, roughness: float = 0.92) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.075, 0.20, 0.39)
	sky_material.sky_horizon_color = Color(0.62, 0.78, 0.88)
	sky_material.ground_bottom_color = Color(0.16, 0.20, 0.15)
	sky_material.ground_horizon_color = Color(0.53, 0.63, 0.48)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.80, 0.91)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.62, 0.73, 0.79)
	environment.fog_density = 0.0018
	world_env.environment = environment
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 95.0
	add_child(sun)

func _chunk_key(cx: int, cz: int) -> String:
	return str(cx) + ":" + str(cz)

func _biome_at(x: float, z: float) -> String:
	var value := biome_noise.get_noise_2d(x, z)
	if value > 0.42:
		return "highland"
	if value > 0.13:
		return "forest"
	if value < -0.42:
		return "dryland"
	if value < -0.16:
		return "meadow"
	return "grassland"

func _biome_material(biome: String) -> StandardMaterial3D:
	match biome:
		"highland":
			return _material(Color(0.39, 0.43, 0.36))
		"forest":
			return _material(Color(0.18, 0.37, 0.20))
		"dryland":
			return _material(Color(0.62, 0.51, 0.31))
		"meadow":
			return _material(Color(0.39, 0.55, 0.28))
		_:
			return _material(Color(0.27, 0.48, 0.24))

func _update_chunks(force: bool = false) -> void:
	var player_chunk := Vector2i(
		floori(player.global_position.x / CHUNK_SIZE),
		floori(player.global_position.z / CHUNK_SIZE)
	)
	if not force and player_chunk == current_chunk:
		return
	current_chunk = player_chunk

	for cz in range(player_chunk.y - LOAD_RADIUS, player_chunk.y + LOAD_RADIUS + 1):
		for cx in range(player_chunk.x - LOAD_RADIUS, player_chunk.x + LOAD_RADIUS + 1):
			var key := _chunk_key(cx, cz)
			if not loaded_chunks.has(key):
				loaded_chunks[key] = _create_chunk(cx, cz)

	var remove_keys: Array = []
	for key in loaded_chunks.keys():
		var parts := String(key).split(":")
		var cx := int(parts[0])
		var cz := int(parts[1])
		if abs(cx - player_chunk.x) > UNLOAD_RADIUS or abs(cz - player_chunk.y) > UNLOAD_RADIUS:
			remove_keys.append(key)
	for key in remove_keys:
		var old_chunk: Node = loaded_chunks[key]
		if is_instance_valid(old_chunk):
			old_chunk.queue_free()
		loaded_chunks.erase(key)

	if chunk_label:
		chunk_label.text = "SEED %d  •  CHUNK %d, %d  •  %d LOADED" % [WORLD_SEED, current_chunk.x, current_chunk.y, loaded_chunks.size()]

func _create_chunk(cx: int, cz: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [cx, cz]
	root.position = Vector3(cx * CHUNK_SIZE, 0, cz * CHUNK_SIZE)
	add_child(root)

	var biome := _biome_at((float(cx) + 0.5) * CHUNK_SIZE, (float(cz) + 0.5) * CHUNK_SIZE)
	var ground := StaticBody3D.new()
	ground.position = Vector3(CHUNK_SIZE * 0.5, -0.55, CHUNK_SIZE * 0.5)
	var ground_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(CHUNK_SIZE, 1.0, CHUNK_SIZE)
	ground_mesh.mesh = box
	ground_mesh.material_override = _biome_material(biome)
	ground.add_child(ground_mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(CHUNK_SIZE, 1.0, CHUNK_SIZE)
	collision.shape = shape
	ground.add_child(collision)
	root.add_child(ground)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(WORLD_SEED + cx * 73856093 + cz * 19349663))
	_add_chunk_landmarks(root, biome, rng)
	if cx == 0 and cz == 0:
		_build_starter_village(root)
	_add_chunk_vegetation(root, biome, rng, cx, cz)
	return root

func _add_chunk_landmarks(root: Node3D, biome: String, rng: RandomNumberGenerator) -> void:
	var rock_mat := _material(Color(0.40, 0.43, 0.42))
	if biome == "highland":
		for i in range(3):
			var peak := MeshInstance3D.new()
			var peak_mesh := SphereMesh.new()
			peak_mesh.radius = rng.randf_range(7.0, 12.0)
			peak_mesh.height = rng.randf_range(18.0, 30.0)
			peak.mesh = peak_mesh
			peak.material_override = rock_mat
			peak.position = Vector3(rng.randf_range(7, 57), peak_mesh.height * 0.35, rng.randf_range(7, 57))
			peak.scale = Vector3(1.4, 1.0, 1.2)
			root.add_child(peak)
	elif biome == "dryland":
		for i in range(4):
			var dune := MeshInstance3D.new()
			var dune_mesh := SphereMesh.new()
			dune_mesh.radius = rng.randf_range(4.0, 8.0)
			dune_mesh.height = rng.randf_range(2.0, 4.0)
			dune.mesh = dune_mesh
			dune.material_override = _material(Color(0.58, 0.49, 0.35))
			dune.position = Vector3(rng.randf_range(5, 59), 0.6, rng.randf_range(5, 59))
			dune.scale = Vector3(1.8, 0.65, 1.3)
			root.add_child(dune)

func _add_chunk_vegetation(root: Node3D, biome: String, rng: RandomNumberGenerator, cx: int, cz: int) -> void:
	var trunk_mat := _material(Color(0.29, 0.18, 0.10))
	var leaf_colors := [Color(0.10, 0.30, 0.15), Color(0.16, 0.40, 0.18), Color(0.28, 0.47, 0.20)]
	var tree_count := 7
	match biome:
		"forest": tree_count = 12
		"highland": tree_count = 4
		"dryland": tree_count = 1
		"meadow": tree_count = 5
	for i in range(tree_count):
		var local_x := rng.randf_range(4.0, CHUNK_SIZE - 4.0)
		var local_z := rng.randf_range(4.0, CHUNK_SIZE - 4.0)
		var global_x := cx * CHUNK_SIZE + local_x
		var global_z := cz * CHUNK_SIZE + local_z
		if cx == 0 and cz == 0 and abs(global_x - 32.0) < 39.0 and abs(global_z - 32.0) < 39.0:
			continue
		if biome == "dryland":
			_add_cactus(root, Vector3(local_x, 0, local_z))
		else:
			var leaf_mat := _material(leaf_colors[rng.randi_range(0, leaf_colors.size() - 1)])
			_add_tree_visual(root, Vector3(local_x, 0, local_z), trunk_mat, leaf_mat, rng.randf_range(0.82, 1.22))
	for i in range(2 if biome != "dryland" else 4):
		var rock := MeshInstance3D.new()
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = rng.randf_range(0.45, 1.05)
		rock_mesh.height = rng.randf_range(0.7, 1.5)
		rock.mesh = rock_mesh
		rock.material_override = _material(Color(0.39, 0.42, 0.41))
		rock.position = Vector3(rng.randf_range(3, 61), 0.2, rng.randf_range(3, 61))
		rock.scale = Vector3(1.4, 0.8, 1.0)
		root.add_child(rock)

func _add_tree_visual(parent: Node3D, pos: Vector3, trunk_mat: Material, leaf_mat: Material, scale_value: float) -> void:
	var tree := Node3D.new()
	tree.position = pos
	tree.scale = Vector3.ONE * scale_value
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.34
	trunk_mesh.height = 3.1
	trunk.mesh = trunk_mesh
	trunk.material_override = trunk_mat
	trunk.position.y = 1.55
	tree.add_child(trunk)
	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.75
	crown_mesh.height = 3.4
	crown.mesh = crown_mesh
	crown.material_override = leaf_mat
	crown.position.y = 3.75
	tree.add_child(crown)
	parent.add_child(tree)

func _add_cactus(parent: Node3D, pos: Vector3) -> void:
	var cactus := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.30
	mesh.height = 2.4
	cactus.mesh = mesh
	cactus.material_override = _material(Color(0.20, 0.40, 0.24))
	cactus.position = pos + Vector3(0, 1.2, 0)
	parent.add_child(cactus)

func _add_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, with_collision: bool = false) -> void:
	var body: Node3D = StaticBody3D.new() if with_collision else Node3D.new()
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

func _build_starter_village(root: Node3D) -> void:
	var path_mat := _material(Color(0.57, 0.45, 0.29))
	var water_mat := _material(Color(0.10, 0.39, 0.61), 0.24)
	var rail_mat := _material(Color(0.29, 0.18, 0.10))
	var wall_mats := [_material(Color(0.82, 0.69, 0.48)), _material(Color(0.72, 0.79, 0.72)), _material(Color(0.82, 0.78, 0.65))]
	var roof_mat := _material(Color(0.43, 0.19, 0.14))
	_add_box(root, Vector3(32, 0.015, 32), Vector3(7, 0.12, 64), path_mat)
	_add_box(root, Vector3(32, 0.02, 20), Vector3(48, 0.13, 3.4), path_mat)
	_add_box(root, Vector3(-22, -0.10, 32), Vector3(25, 0.18, 64), water_mat)
	_add_box(root, Vector3(-16, 0.20, 28), Vector3(15, 0.45, 4.5), path_mat, true)
	for side in [-1.0, 1.0]:
		_add_box(root, Vector3(-16, 0.78, 28 + side * 2.0), Vector3(15, 0.7, 0.18), rail_mat)

	var houses := [Vector3(45, 0, 15), Vector3(17, 0, 14), Vector3(47, 0, 41), Vector3(15, 0, 48), Vector3(61, 0, 29), Vector3(1, 0, 9)]
	for i in range(houses.size()):
		var p: Vector3 = houses[i]
		var wall: Material = wall_mats[i % wall_mats.size()]
		_add_box(root, p + Vector3(0, 1.7, -3.44), Vector3(8, 3.4, 0.12), wall, true)
		_add_box(root, p + Vector3(-3.94, 1.7, 0), Vector3(0.12, 3.4, 7), wall, true)
		_add_box(root, p + Vector3(3.94, 1.7, 0), Vector3(0.12, 3.4, 7), wall, true)
		_add_box(root, p + Vector3(-2.375, 1.7, 3.44), Vector3(3.25, 3.4, 0.12), wall, true)
		_add_box(root, p + Vector3(2.375, 1.7, 3.44), Vector3(3.25, 3.4, 0.12), wall, true)
		_add_box(root, p + Vector3(0, 2.75, 3.44), Vector3(1.5, 1.3, 0.12), wall, true)
		_add_box(root, p + Vector3(0, 3.9, 0), Vector3(8.8, 0.45, 7.8), roof_mat)
		_add_box(root, p + Vector3(-2.1, 2.0, 3.57), Vector3(1.15, 1.0, 0.14), _material(Color(0.27, 0.58, 0.72)))
	var soil := _material(Color(0.37, 0.25, 0.13))
	var crop := _material(Color(0.42, 0.63, 0.22))
	for plot in range(3):
		var plot_pos := Vector3(75, 0.02, 8 + plot * 13)
		_add_box(root, plot_pos, Vector3(19, 0.12, 9), soil)
		for row in range(5):
			for plant in range(8):
				_add_cylinder(root, plot_pos + Vector3(-8 + plant * 2.2, 0.55, -3.4 + row * 1.6), 0.13, 1.0, crop)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(32, 2, 51)
	var body_mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.43
	capsule.height = 1.8
	body_mesh.mesh = capsule
	body_mesh.position.y = 0.9
	body_mesh.material_override = _material(Color(0.10, 0.34, 0.78))
	player.add_child(body_mesh)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.43
	shape.height = 1.8
	collision.shape = shape
	collision.position.y = 0.9
	player.add_child(collision)
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.45
	player.add_child(camera_pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.0, 5.8)
	camera.rotation_degrees.x = -11
	camera.current = true
	camera_pivot.add_child(camera)
	add_child(player)

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 5
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	var top_panel := PanelContainer.new()
	top_panel.position = Vector2(18, 16)
	top_panel.custom_minimum_size = Vector2(310, 74)
	top_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.07, 0.10, 0.82)))
	hud.add_child(top_panel)
	var top_column := VBoxContainer.new()
	top_column.add_theme_constant_override("separation", 2)
	top_panel.add_child(top_column)
	status_label = Label.new()
	status_label.text = "VILLAGE FRONTIER  •  OFFLINE"
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.91, 0.96, 1))
	top_column.add_child(status_label)
	chunk_label = Label.new()
	chunk_label.text = "WORLD STREAMING"
	chunk_label.add_theme_font_size_override("font_size", 12)
	chunk_label.add_theme_color_override("font_color", Color(0.55, 0.84, 0.91))
	top_column.add_child(chunk_label)
	var help := Label.new()
	help.text = "LEFT STICK: MOVE   •   DRAG RIGHT SIDE: LOOK"
	help.position = Vector2(20, 100)
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	hud.add_child(help)

	joystick = Control.new()
	joystick.name = "MoveJoystick"
	joystick.anchor_left = 0.0
	joystick.anchor_top = 1.0
	joystick.anchor_right = 0.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 24
	joystick.offset_top = -194
	joystick.offset_right = 184
	joystick.offset_bottom = -24
	joystick.gui_input.connect(_on_joystick_input)
	hud.add_child(joystick)
	var base := ColorRect.new()
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.position = Vector2(8, 8)
	base.size = Vector2(144, 144)
	base.color = Color(0.10, 0.20, 0.27, 0.58)
	joystick.add_child(base)
	joystick_knob = ColorRect.new()
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_knob.position = Vector2(54, 54)
	joystick_knob.size = Vector2(52, 52)
	joystick_knob.color = Color(0.76, 0.89, 0.96, 0.88)
	joystick.add_child(joystick_knob)

	var run_button := _make_button("RUN", Vector2(-166, -166), Vector2(142, 62))
	_anchor_bottom_right(run_button)
	run_button.button_down.connect(func(): is_running = true)
	run_button.button_up.connect(func(): is_running = false)
	hud.add_child(run_button)
	var jump_button := _make_button("JUMP", Vector2(-166, -92), Vector2(142, 62))
	_anchor_bottom_right(jump_button)
	jump_button.pressed.connect(func(): jump_requested = true)
	hud.add_child(jump_button)
	var reset_button := _make_button("CAM", Vector2(-166, -238), Vector2(142, 54))
	_anchor_bottom_right(reset_button)
	reset_button.pressed.connect(_reset_camera)
	hud.add_child(reset_button)
	var pause_button := _make_button("Ⅱ", Vector2(-82, 18), Vector2(64, 54))
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.anchor_top = 0.0
	pause_button.anchor_bottom = 0.0
	hud.add_child(pause_button)
	pause_button.pressed.connect(_toggle_pause)

	pause_panel = PanelContainer.new()
	pause_panel.visible = false
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-150, -115)
	pause_panel.custom_minimum_size = Vector2(300, 230)
	pause_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.07, 0.10, 0.96)))
	hud.add_child(pause_panel)
	var pause_box := VBoxContainer.new()
	pause_box.add_theme_constant_override("separation", 14)
	pause_panel.add_child(pause_box)
	var pause_title := Label.new()
	pause_title.text = "PAUSED"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 24)
	pause_box.add_child(pause_title)
	var resume_button := _make_button("RESUME", Vector2.ZERO, Vector2(250, 52))
	pause_box.add_child(resume_button)
	resume_button.pressed.connect(_toggle_pause)
	var pause_hint := Label.new()
	pause_hint.text = "Explore the endless frontier"
	pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_box.add_child(pause_hint)

func _anchor_bottom_right(control: Control) -> void:
	control.anchor_left = 1.0
	control.anchor_top = 1.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0

func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(18)
	style.set_border_width_all(1)
	style.border_color = Color(0.28, 0.58, 0.68, 0.55)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _make_button(caption: String, pos: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = pos
	button.size = button_size
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.06, 0.23, 0.36, 0.91)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.09, 0.34, 0.49, 0.96)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.10, 0.49, 0.65, 0.98)))
	return button

func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(16)
	style.set_border_width_all(1)
	style.border_color = Color(0.55, 0.80, 0.90, 0.62)
	return style

func _on_joystick_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		joystick_active = event.pressed
		if not event.pressed:
			move_vector = Vector2.ZERO
			joystick_knob.position = Vector2(54, 54)
	elif event is InputEventScreenDrag and joystick_active:
		_update_joystick(event.position)
	elif event is InputEventMouseButton:
		joystick_active = event.pressed
		if not event.pressed:
			move_vector = Vector2.ZERO
			joystick_knob.position = Vector2(54, 54)
	elif event is InputEventMouseMotion and joystick_active:
		_update_joystick(event.position)

func _update_joystick(pointer: Vector2) -> void:
	var delta := (pointer - Vector2(80, 80)).limit_length(52)
	move_vector = Vector2(delta.x / 52.0, delta.y / 52.0)
	joystick_knob.position = Vector2(54, 54) + delta

func _reset_camera() -> void:
	camera_pivot.rotation = Vector3.ZERO
	camera.rotation_degrees.x = -11

func _toggle_pause() -> void:
	is_paused = not is_paused
	pause_panel.visible = is_paused
	get_tree().paused = is_paused
	if is_paused:
		is_running = false
		move_vector = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x > get_viewport().get_visible_rect().size.x * 0.42:
			look_finger = event.index
			look_last = event.position
		elif not event.pressed and event.index == look_finger:
			look_finger = -1
	elif event is InputEventScreenDrag and event.index == look_finger:
		var look_delta: Vector2 = event.position - look_last
		look_last = event.position
		_rotate_camera(look_delta)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_rotate_camera(event.relative)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_toggle_pause()
		elif event.keycode == KEY_SPACE:
			jump_requested = true
		elif event.keycode == KEY_SHIFT:
			is_running = true
	elif event is InputEventKey and not event.pressed and event.keycode == KEY_SHIFT:
		is_running = false

func _rotate_camera(delta: Vector2) -> void:
	camera_pivot.rotate_y(-delta.x * LOOK_SENSITIVITY)
	camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - delta.y * LOOK_SENSITIVITY, -0.95, 0.48)

func _physics_process(delta: float) -> void:
	if player == null or is_paused:
		return
	var keyboard := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var input_vector := move_vector if move_vector.length() > 0.08 else keyboard
	var camera_forward := -camera_pivot.global_transform.basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var camera_right := camera_pivot.global_transform.basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	var direction := (camera_right * input_vector.x + camera_forward * -input_vector.y).normalized()
	if direction.length() > 0.01:
		var speed := RUN_SPEED if is_running else WALK_SPEED
		player.velocity.x = direction.x * speed
		player.velocity.z = direction.z * speed
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-direction.x, -direction.z), delta * 8.0)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, WALK_SPEED * 4.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, WALK_SPEED * 4.0 * delta)
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
	elif jump_requested:
		player.velocity.y = 6.0
	jump_requested = false
	player.move_and_slide()
	if player.global_position.y < -20.0:
		player.global_position = Vector3(current_chunk.x * CHUNK_SIZE + 32, 3, current_chunk.y * CHUNK_SIZE + 32)
		player.velocity = Vector3.ZERO
	_update_chunks()
