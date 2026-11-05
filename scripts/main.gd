extends Node3D

# Village Frontier - streamed procedural world
const WORLD_SEED := 481516
const CHUNK_SIZE := 64.0
const TERRAIN_RESOLUTION := 20
const MOVE_ACCELERATION := 19.0
const MOVE_DECELERATION := 24.0
const TURN_RESPONSE := 10.0
const TerrainGenerator = preload("res://scripts/world/terrain_generator.gd")
const AssetGenerator = preload("res://scripts/world/asset_generator.gd")
const LOAD_RADIUS := 2
const UNLOAD_RADIUS := 2
const WALK_SPEED := 5.2
const RUN_SPEED := 8.8
const LOOK_SENSITIVITY := 0.0042
const GRAVITY := 18.0
const GRAPHICS_PROFILE := "MEDIUM"
const VISUAL_STYLE := "HYBRID"

var player: CharacterBody3D
var camera_rig: Node3D
var camera_pivot: Node3D
var camera: Camera3D
var move_vector := Vector2.ZERO
var horizontal_velocity := Vector2.ZERO
var look_finger := -1
var joystick_finger := -1
var mouse_joystick_active := false
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
var terrain_noise := FastNoiseLite.new()
var pause_panel: PanelContainer
var is_paused := false
var character_visual: Node3D
var character_skin: StandardMaterial3D
var character_shirt: StandardMaterial3D
var character_pants: StandardMaterial3D
var character_hair: StandardMaterial3D
var character_head: MeshInstance3D
var character_hair_top: MeshInstance3D
var character_hair_sides: Array[MeshInstance3D] = []
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var left_arm_pivot: Node3D
var right_arm_pivot: Node3D
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D
var animation_player: AnimationPlayer
var active_animation := ""
var creator_panel: PanelContainer
var map_panel: PanelContainer
var animation_clock := 0.0
var was_on_floor := true
var landing_timer := 0.0
var player_marker: ColorRect
var skin_index := 0
var outfit_index := 0
var hair_index := 0
var hair_style_index := 0
var face_shape_index := 0
var pants_index := 0
var world_save_timer := 0.0
var pants_palette := [Color(0.10, 0.14, 0.22), Color(0.22, 0.24, 0.28), Color(0.30, 0.20, 0.12), Color(0.08, 0.22, 0.20)]
var world_environment: WorldEnvironment
var sky_material: ProceduralSkyMaterial
var sun_light: DirectionalLight3D
var rain_particles: GPUParticles3D
var weather_button: Button
var weather_mode := 0 # 0 clear, 1 rain, 2 mist
var time_of_day := 0.32
var water_material: ShaderMaterial
var villager_nodes: Array[Node3D] = []
var villager_phases: Array[float] = []
var cloud_root: Node3D
var cloud_clusters: Array[Node3D] = []
var skin_palette := [Color(0.94, 0.72, 0.55), Color(0.72, 0.48, 0.34), Color(0.40, 0.24, 0.16), Color(0.25, 0.15, 0.11)]
var outfit_palette := [Color(0.10, 0.34, 0.78), Color(0.12, 0.48, 0.34), Color(0.68, 0.20, 0.16), Color(0.72, 0.52, 0.12), Color(0.18, 0.16, 0.25)]
var hair_palette := [Color(0.10, 0.065, 0.04), Color(0.30, 0.16, 0.08), Color(0.62, 0.48, 0.28), Color(0.08, 0.08, 0.09)]

func _ready() -> void:
	_setup_noise()
	_build_environment()
	_build_weather_particles()
	_build_cloud_layer()
	_build_player()
	_load_world_state()
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
	terrain_noise.seed = WORLD_SEED + 90210
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terrain_noise.frequency = 0.006
	terrain_noise.fractal_octaves = 4
	terrain_noise.fractal_lacunarity = 2.1
	terrain_noise.fractal_gain = 0.48

func _material(color: Color, roughness: float = 0.92) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_material = ProceduralSkyMaterial.new()
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
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.08
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.62, 0.73, 0.79)
	environment.fog_density = 0.0018
	world_environment.environment = environment
	add_child(world_environment)

	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-48, -32, 0)
	sun_light.light_energy = 1.25
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_max_distance = 84.0
	sun_light.shadow_bias = 0.035
	add_child(sun_light)
	_update_day_night(0.0)

func _build_cloud_layer() -> void:
	cloud_root = Node3D.new()
	cloud_root.name = "DynamicCloudLayer"
	add_child(cloud_root)
	var cloud_material := StandardMaterial3D.new()
	cloud_material.albedo_color = Color(0.82, 0.88, 0.92, 0.78)
	cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_material.roughness = 1.0
	var cloud_mesh := SphereMesh.new()
	cloud_mesh.radius = 3.4
	cloud_mesh.height = 2.0
	var positions := [Vector3(-34, 0, -28), Vector3(-10, 2, 18), Vector3(20, 1, -22), Vector3(42, 0, 25), Vector3(5, 3, 45), Vector3(-48, 1, 38)]
	for i in range(positions.size()):
		var cluster := Node3D.new()
		cluster.position = positions[i]
		cloud_root.add_child(cluster)
		for offset in [Vector3.ZERO, Vector3(3.0, 0.35, 0.4), Vector3(-2.8, 0.1, 0.6), Vector3(0.6, 0.45, 2.0)]:
			var puff := MeshInstance3D.new()
			puff.mesh = cloud_mesh
			puff.material_override = cloud_material
			puff.position = offset
			puff.scale = Vector3(1.0, 0.48, 0.72)
			cluster.add_child(puff)
		cloud_clusters.append(cluster)

func _build_weather_particles() -> void:
	rain_particles = GPUParticles3D.new()
	rain_particles.name = "LocalRain"
	rain_particles.amount = 420
	rain_particles.lifetime = 1.25
	rain_particles.emitting = false
	rain_particles.visibility_aabb = AABB(Vector3(-20, -18, -20), Vector3(40, 40, 40))
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(17, 1, 17)
	process_material.direction = Vector3(0.04, -1.0, 0.02)
	process_material.spread = 5.0
	process_material.initial_velocity_min = 17.0
	process_material.initial_velocity_max = 23.0
	process_material.gravity = Vector3(0, -18, 0)
	rain_particles.process_material = process_material
	var rain_quad := QuadMesh.new()
	rain_quad.size = Vector2(0.025, 0.62)
	var rain_material := StandardMaterial3D.new()
	rain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_material.albedo_color = Color(0.65, 0.82, 1.0, 0.72)
	rain_quad.material = rain_material
	rain_particles.draw_pass_1 = rain_quad
	add_child(rain_particles)

func _update_day_night(delta: float) -> void:
	if delta > 0.0:
		time_of_day = fposmod(time_of_day + delta / 1440.0, 1.0)
	var daylight := maxf(0.0, sin((time_of_day - 0.25) * TAU))
	var sunrise_distance := absf(time_of_day - 0.25)
	var sunset_distance := absf(time_of_day - 0.75)
	sunrise_distance = minf(sunrise_distance, 1.0 - sunrise_distance)
	sunset_distance = minf(sunset_distance, 1.0 - sunset_distance)
	var twilight := maxf(
		clampf(1.0 - sunrise_distance * 12.0, 0.0, 1.0),
		clampf(1.0 - sunset_distance * 12.0, 0.0, 1.0)
	)
	var night_top := Color(0.012, 0.025, 0.075)
	var day_top := Color(0.075, 0.20, 0.39)
	var night_horizon := Color(0.045, 0.065, 0.12)
	var day_horizon := Color(0.62, 0.78, 0.88)
	sky_material.sky_top_color = night_top.lerp(day_top, daylight)
	sky_material.sky_horizon_color = night_horizon.lerp(day_horizon, daylight).lerp(Color(0.92, 0.40, 0.22), twilight * 0.42)
	sky_material.ground_bottom_color = Color(0.035, 0.045, 0.065).lerp(Color(0.16, 0.20, 0.15), daylight)
	sun_light.rotation_degrees = Vector3(-48.0 + sin(time_of_day * TAU) * 28.0, -32.0, 0.0)
	sun_light.light_energy = 0.06 + daylight * 1.34
	sun_light.light_color = Color(1.0, 0.72, 0.48).lerp(Color(1.0, 0.96, 0.86), daylight)
	world_environment.environment.ambient_light_color = Color(0.12, 0.16, 0.28).lerp(Color(0.72, 0.80, 0.91), daylight)
	world_environment.environment.ambient_light_energy = 0.18 + daylight * 0.62
	if weather_mode == 2:
		world_environment.environment.fog_density = 0.009
		world_environment.environment.fog_light_color = Color(0.48, 0.55, 0.60)
	elif weather_mode == 1:
		world_environment.environment.fog_density = 0.0032
		world_environment.environment.fog_light_color = Color(0.42, 0.52, 0.62)
	else:
		world_environment.environment.fog_density = 0.0018
		world_environment.environment.fog_light_color = Color(0.62, 0.73, 0.79)

func _load_world_state() -> void:
	var config := ConfigFile.new()
	if config.load("user://world.cfg") == OK:
		var saved_position: Vector3 = config.get_value("world", "player_position", player.global_position)
		player.global_position = saved_position
		time_of_day = float(config.get_value("world", "time_of_day", time_of_day))
		weather_mode = int(config.get_value("world", "weather_mode", 0)) % 3
	_update_day_night(0.0)
	if rain_particles:
		rain_particles.emitting = weather_mode == 1

func _save_world_state() -> void:
	if player == null:
		return
	var config := ConfigFile.new()
	config.set_value("world", "player_position", player.global_position)
	config.set_value("world", "time_of_day", time_of_day)
	config.set_value("world", "weather_mode", weather_mode)
	config.save("user://world.cfg")

func _cycle_weather() -> void:
	weather_mode = (weather_mode + 1) % 3
	if rain_particles:
		rain_particles.emitting = weather_mode == 1
	if weather_button:
		weather_button.text = ["WEATHER: CLEAR", "WEATHER: RAIN", "WEATHER: MIST"][weather_mode]
	_update_day_night(0.0)
	_save_world_state()

func _process(delta: float) -> void:
	_update_day_night(delta)
	world_save_timer += delta
	if world_save_timer >= 15.0:
		world_save_timer = 0.0
		_save_world_state()
	if rain_particles and player:
		rain_particles.global_position = player.global_position + Vector3(0, 13, 0)
	if cloud_root and player:
		cloud_root.global_position = player.global_position + Vector3(0, 38, 0)
		for cloud in cloud_clusters:
			cloud.position.x += delta * 0.55
			if cloud.position.x > 58.0:
				cloud.position.x = -58.0
	for i in range(villager_nodes.size() - 1, -1, -1):
		if not is_instance_valid(villager_nodes[i]):
			villager_nodes.remove_at(i)
			villager_phases.remove_at(i)
		else:
			villager_phases[i] += delta
			villager_nodes[i].rotation.y = sin(villager_phases[i] * 0.35) * 0.12
			villager_nodes[i].position.y = sin(villager_phases[i] * 1.8) * 0.025

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_save_world_state()

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

func _biome_ground_color(biome: String) -> Color:
	match biome:
		"highland":
			return Color(0.39, 0.43, 0.36)
		"forest":
			return Color(0.18, 0.37, 0.20)
		"dryland":
			return Color(0.62, 0.51, 0.31)
		"meadow":
			return Color(0.39, 0.55, 0.28)
		_:
			return Color(0.27, 0.48, 0.24)

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
		chunk_label.text = "%s  •  SEED %d  •  CHUNK %d, %d  •  %d ACTIVE" % [VISUAL_STYLE, WORLD_SEED, current_chunk.x, current_chunk.y, loaded_chunks.size()]

func _create_chunk(cx: int, cz: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [cx, cz]
	root.position = Vector3(cx * CHUNK_SIZE, 0, cz * CHUNK_SIZE)
	add_child(root)

	var biome := _biome_at((float(cx) + 0.5) * CHUNK_SIZE, (float(cz) + 0.5) * CHUNK_SIZE)
	var ground := StaticBody3D.new()
	ground.name = "TerrainCollision"
	var ground_mesh := MeshInstance3D.new()
	ground_mesh.name = "TerrainSurface"
	var ground_material := StandardMaterial3D.new()
	ground_material.vertex_color_use_as_albedo = true
	ground_material.roughness = 1.0
	var terrain_shader := Shader.new()
	terrain_shader.code = "shader_type spatial;\nrender_mode diffuse_burley, specular_schlick_ggx;\nvarying vec3 world_position;\nvoid vertex(){ world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }\nvoid fragment(){ float grain = fract(sin(dot(floor(world_position.xz * 2.8), vec2(127.1, 311.7))) * 43758.5453); float broad = sin(world_position.x * 0.12) * sin(world_position.z * 0.10) * 0.035; ALBEDO = COLOR.rgb * (0.91 + grain * 0.12 + broad); ROUGHNESS = 0.96; }"
	var terrain_material := ShaderMaterial.new()
	terrain_material.shader = terrain_shader
	ground_mesh.mesh = TerrainGenerator.build_chunk_mesh(
		terrain_noise,
		Vector2(cx * CHUNK_SIZE, cz * CHUNK_SIZE),
		CHUNK_SIZE,
		TERRAIN_RESOLUTION,
		_biome_ground_color(biome),
		Vector2(32.0, 32.0),
		72.0,
		96.0
	)
	ground_mesh.material_override = terrain_material
	ground.add_child(ground_mesh)
	var collision := CollisionShape3D.new()
	collision.shape = ground_mesh.mesh.create_trimesh_shape()
	ground.add_child(collision)
	root.add_child(ground)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(WORLD_SEED + cx * 73856093 + cz * 19349663))
	_add_chunk_landmarks(root, biome, rng, cx, cz)
	if cx == 0 and cz == 0:
		_build_starter_village(root)
		AssetGenerator.add_village_props(root)
	_add_chunk_vegetation(root, biome, rng, cx, cz)
	AssetGenerator.add_chunk_detail(root, biome, rng, cx, cz, CHUNK_SIZE, Callable(self, "_world_height"))
	return root

func _add_chunk_landmarks(root: Node3D, biome: String, rng: RandomNumberGenerator, cx: int, cz: int) -> void:
	var rock_mat := _material(Color(0.40, 0.43, 0.42))
	if biome == "highland":
		for i in range(3):
			var peak := MeshInstance3D.new()
			var peak_mesh := SphereMesh.new()
			peak_mesh.radius = rng.randf_range(7.0, 12.0)
			peak_mesh.height = rng.randf_range(18.0, 30.0)
			peak.mesh = peak_mesh
			peak.material_override = rock_mat
			var peak_x := rng.randf_range(7.0, 57.0)
			var peak_z := rng.randf_range(7.0, 57.0)
			peak.position = Vector3(peak_x, _world_height(cx * CHUNK_SIZE + peak_x, cz * CHUNK_SIZE + peak_z) + peak_mesh.height * 0.35, peak_z)
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
			var dune_x := rng.randf_range(5.0, 59.0)
			var dune_z := rng.randf_range(5.0, 59.0)
			dune.position = Vector3(dune_x, _world_height(cx * CHUNK_SIZE + dune_x, cz * CHUNK_SIZE + dune_z) + 0.6, dune_z)
			dune.scale = Vector3(1.8, 0.65, 1.3)
			root.add_child(dune)

func _world_height(world_x: float, world_z: float) -> float:
	return TerrainGenerator.height_at(terrain_noise, world_x, world_z, Vector2(32.0, 32.0), 72.0, 96.0)

func _add_chunk_vegetation(root: Node3D, biome: String, rng: RandomNumberGenerator, cx: int, cz: int) -> void:
	var tree_count := 5
	match biome:
		"forest": tree_count = 9
		"highland": tree_count = 3
		"dryland": tree_count = 1
		"meadow": tree_count = 4

	var tree_transforms: Array[Transform3D] = []
	var crown_colors: Array[Color] = []
	var leaf_colors := [Color(0.10, 0.30, 0.15), Color(0.16, 0.40, 0.18), Color(0.28, 0.47, 0.20)]
	for i in range(tree_count):
		var local_x := rng.randf_range(4.0, CHUNK_SIZE - 4.0)
		var local_z := rng.randf_range(4.0, CHUNK_SIZE - 4.0)
		var global_x := cx * CHUNK_SIZE + local_x
		var global_z := cz * CHUNK_SIZE + local_z
		if cx == 0 and cz == 0 and abs(global_x - 32.0) < 39.0 and abs(global_z - 32.0) < 39.0:
			continue
		var ground_y := _world_height(global_x, global_z)
		if biome == "dryland":
			_add_cactus(root, Vector3(local_x, ground_y, local_z))
		else:
			var scale_value := rng.randf_range(0.82, 1.22)
			var transform_basis := Basis().scaled(Vector3.ONE * scale_value)
			tree_transforms.append(Transform3D(transform_basis, Vector3(local_x, ground_y + 1.55 * scale_value, local_z)))
			crown_colors.append(leaf_colors[rng.randi_range(0, leaf_colors.size() - 1)))
	if not tree_transforms.is_empty():
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.22
		trunk_mesh.bottom_radius = 0.34
		trunk_mesh.height = 3.1
		var trunk_multi := MultiMesh.new()
		trunk_multi.transform_format = MultiMesh.TRANSFORM_3D
		trunk_multi.mesh = trunk_mesh
		trunk_multi.instance_count = tree_transforms.size()
		for i in range(tree_transforms.size()):
			trunk_multi.set_instance_transform(i, tree_transforms[i])
		var trunks := MultiMeshInstance3D.new()
		trunks.multimesh = trunk_multi
		trunks.material_override = _material(Color(0.29, 0.18, 0.10))
		root.add_child(trunks)

		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = 1.75
		crown_mesh.height = 3.4
		var crown_multi := MultiMesh.new()
		crown_multi.transform_format = MultiMesh.TRANSFORM_3D
		crown_multi.use_colors = true
		crown_multi.mesh = crown_mesh
		crown_multi.instance_count = tree_transforms.size()
		for i in range(tree_transforms.size()):
			var transform := tree_transforms[i]
			var scale_value := transform.basis.get_scale().x
			transform.origin.y += 2.20 * scale_value
			crown_multi.set_instance_transform(i, transform)
			crown_multi.set_instance_color(i, crown_colors[i])
		var crown_material := _material(Color.WHITE)
		crown_material.vertex_color_use_as_albedo = true
		var crowns := MultiMeshInstance3D.new()
		crowns.multimesh = crown_multi
		crowns.material_override = crown_material
		root.add_child(crowns)

	for i in range(2 if biome != "dryland" else 4):
		var rock := MeshInstance3D.new()
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = rng.randf_range(0.45, 1.05)
		rock_mesh.height = rng.randf_range(0.7, 1.5)
		rock.mesh = rock_mesh
		rock.material_override = _material(Color(0.39, 0.42, 0.41))
		var rock_x := rng.randf_range(3.0, 61.0)
		var rock_z := rng.randf_range(3.0, 61.0)
		rock.position = Vector3(rock_x, _world_height(cx * CHUNK_SIZE + rock_x, cz * CHUNK_SIZE + rock_z) + 0.2, rock_z)
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

func _add_water_surface(parent: Node3D, pos: Vector3, dimensions: Vector2, material: Material) -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = dimensions
	plane.orientation = PlaneMesh.FACE_Y
	plane.subdivide_width = 24
	plane.subdivide_depth = 48
	water.mesh = plane
	water.material_override = material
	water.position = pos
	parent.add_child(water)

func _build_starter_village(root: Node3D) -> void:
	var path_mat := _material(Color(0.57, 0.45, 0.29))
	var water_shader := Shader.new()
	water_shader.code = "shader_type spatial;\nrender_mode blend_mix, cull_disabled, depth_draw_opaque;\nuniform vec4 water_color : source_color = vec4(0.035, 0.30, 0.52, 0.82);\nvarying vec3 world_position;\nvoid vertex(){ world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; VERTEX.y += sin(VERTEX.x * 0.42 + TIME * 1.4) * 0.045 + cos(VERTEX.z * 0.31 + TIME) * 0.025; }\nvoid fragment(){ float ripple = sin(world_position.x * 0.55 + TIME * 1.8) * cos(world_position.z * 0.34 - TIME * 1.2); ALBEDO = water_color.rgb * (0.82 + ripple * 0.12); ROUGHNESS = 0.16; METALLIC = 0.18; SPECULAR = 0.8; ALPHA = water_color.a; }"
	water_material = ShaderMaterial.new()
	water_material.shader = water_shader
	var water_mat := water_material
	var rail_mat := _material(Color(0.29, 0.18, 0.10))
	var wall_mats := [_material(Color(0.82, 0.69, 0.48)), _material(Color(0.72, 0.79, 0.72)), _material(Color(0.82, 0.78, 0.65))]
	var roof_mat := _material(Color(0.43, 0.19, 0.14))
	_add_box(root, Vector3(32, 0.015, 32), Vector3(7, 0.12, 64), path_mat)
	_add_box(root, Vector3(32, 0.02, 20), Vector3(48, 0.13, 3.4), path_mat)
	_add_water_surface(root, Vector3(-22, -0.10, 32), Vector2(25, 64), water_mat)
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
		var gable_roof := MeshInstance3D.new()
		var gable_mesh := PrismMesh.new()
		gable_mesh.size = Vector3(8.9, 1.7, 7.9)
		gable_roof.mesh = gable_mesh
		gable_roof.position = p + Vector3(0, 4.25, 0)
		gable_roof.material_override = roof_mat
		root.add_child(gable_roof)
		_add_box(root, p + Vector3(0, 1.28, 3.56), Vector3(1.35, 2.55, 0.16), _material(Color(0.31, 0.19, 0.11)))
		_add_box(root, p + Vector3(-2.1, 2.0, 3.57), Vector3(1.15, 1.0, 0.14), _material(Color(0.27, 0.58, 0.72)))
		_add_box(root, p + Vector3(2.1, 2.0, 3.57), Vector3(1.15, 1.0, 0.14), _material(Color(0.27, 0.58, 0.72)))
		_add_box(root, p + Vector3(-4.02, 2.05, -1.45), Vector3(0.12, 0.95, 1.25), _material(Color(0.27, 0.58, 0.72)))
		_add_box(root, p + Vector3(4.02, 2.05, -1.45), Vector3(0.12, 0.95, 1.25), _material(Color(0.27, 0.58, 0.72)))
		_add_box(root, p + Vector3(-1.8, 0.12, 4.25), Vector3(2.3, 0.22, 1.2), path_mat)
		var chimney := MeshInstance3D.new()
		var chimney_mesh := BoxMesh.new()
		chimney_mesh.size = Vector3(0.75, 2.0, 0.75)
		chimney.mesh = chimney_mesh
		chimney.position = p + Vector3(2.7, 4.8, -1.8)
		chimney.material_override = _material(Color(0.38, 0.31, 0.27))
		root.add_child(chimney)
	var soil := _material(Color(0.37, 0.25, 0.13))
	var crop := _material(Color(0.42, 0.63, 0.22))
	for plot in range(3):
		var plot_pos := Vector3(75, 0.02, 8 + plot * 13)
		_add_box(root, plot_pos, Vector3(19, 0.12, 9), soil)
		for row in range(5):
			for plant in range(8):
				_add_cylinder(root, plot_pos + Vector3(-8 + plant * 2.2, 0.55, -3.4 + row * 1.6), 0.13, 1.0, crop)
	_spawn_villagers(root)
	_build_village_lamps(root)

func _build_village_lamps(root: Node3D) -> void:
	var wood := _material(Color(0.20, 0.16, 0.12))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.72, 0.32)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.48, 0.12)
	glow.emission_energy_multiplier = 1.4
	for pos in [Vector3(25, 0, 17), Vector3(39, 0, 25), Vector3(25, 0, 39), Vector3(52, 0, 34)]:
		_add_cylinder(root, pos + Vector3(0, 2.1, 0), 0.09, 4.2, wood)
		var lamp := MeshInstance3D.new()
		var globe := SphereMesh.new()
		globe.radius = 0.22
		globe.height = 0.44
		lamp.mesh = globe
		lamp.position = pos + Vector3(0, 4.25, 0)
		lamp.material_override = glow
		root.add_child(lamp)

func _spawn_villagers(root: Node3D) -> void:
	var outfits := [Color(0.68, 0.24, 0.16), Color(0.16, 0.36, 0.58), Color(0.24, 0.48, 0.27)]
	var positions := [Vector3(29, 0, 25), Vector3(43, 0, 35), Vector3(12, 0, 26)]
	for i in range(positions.size()):
		var npc := Node3D.new()
		npc.name = "VillageResident_%d" % i
		npc.position = positions[i]
		root.add_child(npc)
		var skin := _material([Color(0.78, 0.56, 0.40), Color(0.52, 0.34, 0.24), Color(0.90, 0.69, 0.52)][i])
		var clothes := _material(outfits[i])
		var pants := _material(Color(0.12, 0.15, 0.20))
		var torso_mesh := CapsuleMesh.new()
		torso_mesh.radius = 0.31
		torso_mesh.height = 0.82
		_make_piece(npc, "Body", torso_mesh, Vector3(0, 1.1, 0), clothes)
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.24
		head_mesh.height = 0.48
		_make_piece(npc, "Head", head_mesh, Vector3(0, 1.82, 0), skin)
		var hair_mesh := SphereMesh.new()
		hair_mesh.radius = 0.25
		hair_mesh.height = 0.20
		_make_piece(npc, "Hair", hair_mesh, Vector3(0, 2.0, 0), _material(Color(0.10, 0.07, 0.05)))
		var leg_mesh := CapsuleMesh.new()
		leg_mesh.radius = 0.11
		leg_mesh.height = 0.72
		_make_piece(npc, "LeftLeg", leg_mesh, Vector3(-0.13, 0.42, 0), pants)
		_make_piece(npc, "RightLeg", leg_mesh, Vector3(0.13, 0.42, 0), pants)
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.085
		arm_mesh.height = 0.66
		var left := _make_piece(npc, "LeftArm", arm_mesh, Vector3(-0.36, 1.12, 0), skin)
		var right := _make_piece(npc, "RightArm", arm_mesh, Vector3(0.36, 1.12, 0), skin)
		left.rotation.z = -0.12
		right.rotation.z = 0.12
		villager_nodes.append(npc)
		villager_phases.append(float(i) * 1.7)

func _make_piece(parent: Node3D, piece_name: String, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = piece_name
	piece.mesh = mesh
	piece.position = pos
	piece.material_override = mat
	parent.add_child(piece)
	return piece

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(32, 2, 51)
	character_visual = Node3D.new()
	character_visual.name = "CharacterVisual"
	player.add_child(character_visual)

	var skin_mat := _material(Color(0.72, 0.48, 0.34))
	var shirt_mat := _material(Color(0.10, 0.34, 0.78))
	var pants_mat := _material(Color(0.10, 0.14, 0.22))
	var hair_mat := _material(Color(0.10, 0.065, 0.04))
	character_skin = skin_mat
	character_shirt = shirt_mat
	character_pants = pants_mat
	character_hair = hair_mat

	var torso := CapsuleMesh.new()
	torso.radius = 0.36
	torso.height = 0.92
	_make_piece(character_visual, "Torso", torso, Vector3(0, 1.12, 0), shirt_mat)
	var head := SphereMesh.new()
	head.radius = 0.27
	head.height = 0.56
	character_head = _make_piece(character_visual, "Head", head, Vector3(0, 1.88, 0), skin_mat)
	var hair := SphereMesh.new()
	hair.radius = 0.285
	hair.height = 0.30
	character_hair_top = _make_piece(character_visual, "Hair", hair, Vector3(0, 2.08, 0), hair_mat)
	var side_hair_mesh := CapsuleMesh.new()
	side_hair_mesh.radius = 0.075
	side_hair_mesh.height = 0.28
	var side_left := _make_piece(character_visual, "HairSideLeft", side_hair_mesh, Vector3(-0.235, 1.94, 0), hair_mat)
	var side_right := _make_piece(character_visual, "HairSideRight", side_hair_mesh, Vector3(0.235, 1.94, 0), hair_mat)
	character_hair_sides = [side_left, side_right]
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.027
	eye_mesh.height = 0.045
	var eye_mat := _material(Color(0.025, 0.025, 0.03))
	_make_piece(character_visual, "EyeLeft", eye_mesh, Vector3(-0.095, 1.91, -0.235), eye_mat)
	_make_piece(character_visual, "EyeRight", eye_mesh, Vector3(0.095, 1.91, -0.235), eye_mat)
	var ear_mesh := SphereMesh.new()
	ear_mesh.radius = 0.075
	ear_mesh.height = 0.14
	_make_piece(character_visual, "EarLeft", ear_mesh, Vector3(-0.27, 1.87, 0), skin_mat)
	_make_piece(character_visual, "EarRight", ear_mesh, Vector3(0.27, 1.87, 0), skin_mat)
	var nose_mesh := SphereMesh.new()
	nose_mesh.radius = 0.055
	nose_mesh.height = 0.09
	_make_piece(character_visual, "Nose", nose_mesh, Vector3(0, 1.84, -0.27), skin_mat)
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.12
	neck_mesh.bottom_radius = 0.14
	neck_mesh.height = 0.22
	_make_piece(character_visual, "Neck", neck_mesh, Vector3(0, 1.58, 0), skin_mat)
	var backpack_mesh := BoxMesh.new()
	backpack_mesh.size = Vector3(0.42, 0.55, 0.22)
	_make_piece(character_visual, "Backpack", backpack_mesh, Vector3(0, 1.12, 0.30), _material(Color(0.32, 0.20, 0.10)))

	var arm_mesh := CapsuleMesh.new()
	arm_mesh.radius = 0.105
	arm_mesh.height = 0.72
	left_arm_pivot = Node3D.new()
	left_arm_pivot.name = "LeftArmPivot"
	left_arm_pivot.position = Vector3(-0.43, 1.48, 0)
	character_visual.add_child(left_arm_pivot)
	left_arm = _make_piece(left_arm_pivot, "LeftArm", arm_mesh, Vector3(0, -0.35, 0), skin_mat)
	right_arm_pivot = Node3D.new()
	right_arm_pivot.name = "RightArmPivot"
	right_arm_pivot.position = Vector3(0.43, 1.48, 0)
	character_visual.add_child(right_arm_pivot)
	right_arm = _make_piece(right_arm_pivot, "RightArm", arm_mesh, Vector3(0, -0.35, 0), skin_mat)

	var leg_mesh := CapsuleMesh.new()
	leg_mesh.radius = 0.13
	leg_mesh.height = 0.78
	left_leg_pivot = Node3D.new()
	left_leg_pivot.name = "LeftLegPivot"
	left_leg_pivot.position = Vector3(-0.16, 0.82, 0)
	character_visual.add_child(left_leg_pivot)
	left_leg = _make_piece(left_leg_pivot, "LeftLeg", leg_mesh, Vector3(0, -0.39, 0), pants_mat)
	right_leg_pivot = Node3D.new()
	right_leg_pivot.name = "RightLegPivot"
	right_leg_pivot.position = Vector3(0.16, 0.82, 0)
	character_visual.add_child(right_leg_pivot)
	right_leg = _make_piece(right_leg_pivot, "RightLeg", leg_mesh, Vector3(0, -0.39, 0), pants_mat)

	# Feet follow the animated leg pivots instead of floating in place.
	var shoe_mesh := BoxMesh.new()
	shoe_mesh.size = Vector3(0.30, 0.16, 0.44)
	var shoe_mat := _material(Color(0.055, 0.06, 0.075))
	_make_piece(left_leg_pivot, "LeftShoe", shoe_mesh, Vector3(0, -0.73, -0.07), shoe_mat)
	_make_piece(right_leg_pivot, "RightShoe", shoe_mesh, Vector3(0, -0.73, -0.07), shoe_mat)

	animation_player = AnimationPlayer.new()
	animation_player.name = "CharacterAnimationPlayer"
	animation_player.root_node = NodePath("..")
	player.add_child(animation_player)
	_build_character_animations()

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.43
	shape.height = 1.8
	collision.shape = shape
	collision.position.y = 0.9
	player.add_child(collision)
	add_child(player)
	camera_rig = Node3D.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position.y = 1.45
	camera_rig.add_child(camera_pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.0, 5.8)
	camera.fov = 72.0
	camera.far = 360.0
	camera.rotation_degrees.x = -11
	camera.current = true
	camera_pivot.add_child(camera)
	camera_rig.global_position = player.global_position
	_load_character_appearance()

func _load_character_appearance() -> void:
	var config := ConfigFile.new()
	if config.load("user://character.cfg") == OK:
		_apply_character_colors(
			config.get_value("appearance", "skin", Color(0.72, 0.48, 0.34)),
			config.get_value("appearance", "shirt", Color(0.10, 0.34, 0.78)),
			config.get_value("appearance", "pants", Color(0.10, 0.14, 0.22))
		)
		character_hair.albedo_color = config.get_value("appearance", "hair", Color(0.10, 0.065, 0.04))
		skin_index = int(config.get_value("appearance", "skin_index", 0)) % skin_palette.size()
		outfit_index = int(config.get_value("appearance", "outfit_index", 0)) % outfit_palette.size()
		hair_index = int(config.get_value("appearance", "hair_index", 0)) % hair_palette.size()
		hair_style_index = int(config.get_value("appearance", "hair_style", 0)) % 4
		face_shape_index = int(config.get_value("appearance", "face_shape", 0)) % 3
		pants_index = int(config.get_value("appearance", "pants_index", 0)) % pants_palette.size()
		_apply_hair_style()
		_apply_face_shape()

func _apply_character_colors(skin: Color, shirt: Color, pants: Color) -> void:
	character_skin.albedo_color = skin
	character_shirt.albedo_color = shirt
	character_pants.albedo_color = pants

func _save_character_appearance() -> void:
	var config := ConfigFile.new()
	config.set_value("appearance", "skin", character_skin.albedo_color)
	config.set_value("appearance", "shirt", character_shirt.albedo_color)
	config.set_value("appearance", "pants", character_pants.albedo_color)
	config.set_value("appearance", "hair", character_hair.albedo_color)
	config.set_value("appearance", "skin_index", skin_index)
	config.set_value("appearance", "outfit_index", outfit_index)
	config.set_value("appearance", "hair_index", hair_index)
	config.set_value("appearance", "hair_style", hair_style_index)
	config.set_value("appearance", "face_shape", face_shape_index)
	config.set_value("appearance", "pants_index", pants_index)
	config.save("user://character.cfg")

func _apply_hair_style() -> void:
	if character_hair_top == null:
		return
	var styles := [Vector3(1.0, 1.0, 1.0), Vector3(1.15, 0.68, 1.0), Vector3(0.82, 1.25, 0.9), Vector3(1.05, 0.82, 1.18)]
	character_hair_top.scale = styles[hair_style_index % styles.size()]
	for i in range(character_hair_sides.size()):
		character_hair_sides[i].visible = hair_style_index != 1

func _cycle_hair_style() -> void:
	hair_style_index = (hair_style_index + 1) % 4
	_apply_hair_style()
	_save_character_appearance()

func _apply_face_shape() -> void:
	if character_head == null:
		return
	var shapes := [Vector3.ONE, Vector3(1.12, 0.92, 0.96), Vector3(0.92, 1.08, 1.04)]
	character_head.scale = shapes[face_shape_index % shapes.size()]

func _cycle_face_shape() -> void:
	face_shape_index = (face_shape_index + 1) % 3
	_apply_face_shape()
	_save_character_appearance()

func _cycle_pants() -> void:
	pants_index = (pants_index + 1) % pants_palette.size()
	character_pants.albedo_color = pants_palette[pants_index]
	_save_character_appearance()

func _cycle_skin() -> void:
	skin_index = (skin_index + 1) % skin_palette.size()
	_apply_character_colors(skin_palette[skin_index], character_shirt.albedo_color, character_pants.albedo_color)
	_save_character_appearance()

func _cycle_outfit() -> void:
	outfit_index = (outfit_index + 1) % outfit_palette.size()
	_apply_character_colors(character_skin.albedo_color, outfit_palette[outfit_index], character_pants.albedo_color)
	_save_character_appearance()

func _cycle_hair() -> void:
	hair_index = (hair_index + 1) % hair_palette.size()
	character_hair.albedo_color = hair_palette[hair_index]
	_save_character_appearance()

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
	status_label.text = "VILLAGE FRONTIER  •  " + GRAPHICS_PROFILE
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
	_build_creator_and_map(hud)
	weather_button = _make_button("WEATHER: CLEAR", Vector2(20, 136), Vector2(190, 48))
	weather_button.anchor_left = 0.0
	weather_button.anchor_right = 0.0
	weather_button.anchor_top = 0.0
	weather_button.anchor_bottom = 0.0
	hud.add_child(weather_button)
	weather_button.pressed.connect(_cycle_weather)
	weather_button.text = ["WEATHER: CLEAR", "WEATHER: RAIN", "WEATHER: MIST"][weather_mode]

func _build_creator_and_map(hud: CanvasLayer) -> void:
	var creator_button := _make_button("CHARACTER", Vector2(-190, 78), Vector2(174, 48))
	creator_button.anchor_left = 1.0
	creator_button.anchor_right = 1.0
	creator_button.anchor_top = 0.0
	creator_button.anchor_bottom = 0.0
	hud.add_child(creator_button)
	creator_button.pressed.connect(func():
		creator_panel.visible = not creator_panel.visible
		map_panel.visible = false
	)

	var map_button := _make_button("MAP", Vector2(-190, 134), Vector2(174, 48))
	map_button.anchor_left = 1.0
	map_button.anchor_right = 1.0
	map_button.anchor_top = 0.0
	map_button.anchor_bottom = 0.0
	hud.add_child(map_button)
	map_button.pressed.connect(func():
		map_panel.visible = not map_panel.visible
		creator_panel.visible = false
	)

	creator_panel = PanelContainer.new()
	creator_panel.visible = false
	creator_panel.set_anchors_preset(Control.PRESET_CENTER)
	creator_panel.position = Vector2(-210, -190)
	creator_panel.custom_minimum_size = Vector2(420, 470)
	creator_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.07, 0.10, 0.97)))
	hud.add_child(creator_panel)
	var creator_scroll := ScrollContainer.new()
	creator_scroll.custom_minimum_size = Vector2(390, 430)
	creator_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	creator_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	creator_panel.add_child(creator_scroll)
	var creator_box := VBoxContainer.new()
	creator_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	creator_box.add_theme_constant_override("separation", 10)
	creator_scroll.add_child(creator_box)
	var creator_title := Label.new()
	creator_title.text = "CHARACTER STUDIO"
	creator_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	creator_title.add_theme_font_size_override("font_size", 23)
	creator_box.add_child(creator_title)
	var creator_desc := Label.new()
	creator_desc.text = "Customize your explorer • changes save on this device"
	creator_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	creator_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	creator_box.add_child(creator_desc)
	var skin_button := _make_button("SKIN TONE  •  CHANGE", Vector2.ZERO, Vector2(360, 46))
	creator_box.add_child(skin_button)
	skin_button.pressed.connect(_cycle_skin)
	var hair_button := _make_button("HAIR COLOR  •  CHANGE", Vector2.ZERO, Vector2(370, 48))
	creator_box.add_child(hair_button)
	hair_button.pressed.connect(_cycle_hair)
	var hair_style_button := _make_button("HAIRSTYLE  •  CHANGE", Vector2.ZERO, Vector2(360, 42))
	creator_box.add_child(hair_style_button)
	hair_style_button.pressed.connect(_cycle_hair_style)
	var face_button := _make_button("FACE SHAPE  •  CHANGE", Vector2.ZERO, Vector2(370, 42))
	creator_box.add_child(face_button)
	face_button.pressed.connect(_cycle_face_shape)
	var outfit_button := _make_button("SHIRT COLOR  •  CHANGE", Vector2.ZERO, Vector2(370, 42))
	creator_box.add_child(outfit_button)
	outfit_button.pressed.connect(_cycle_outfit)
	var pants_button := _make_button("TROUSER COLOR  •  CHANGE", Vector2.ZERO, Vector2(370, 42))
	creator_box.add_child(pants_button)
	pants_button.pressed.connect(_cycle_pants)
	var close_creator := _make_button("DONE", Vector2.ZERO, Vector2(360, 44))
	creator_box.add_child(close_creator)
	close_creator.pressed.connect(func(): creator_panel.visible = false)

	map_panel = PanelContainer.new()
	map_panel.visible = false
	map_panel.set_anchors_preset(Control.PRESET_CENTER)
	map_panel.position = Vector2(-230, -205)
	map_panel.custom_minimum_size = Vector2(460, 410)
	map_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.07, 0.10, 0.97)))
	hud.add_child(map_panel)
	var map_box := VBoxContainer.new()
	map_box.add_theme_constant_override("separation", 8)
	map_panel.add_child(map_box)
	var map_title := Label.new()
	map_title.text = "WORLD MAP  •  EXPLORATION"
	map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_title.add_theme_font_size_override("font_size", 21)
	map_box.add_child(map_title)
	var map_info := Label.new()
	map_info.text = "Village  •  River  •  Forest  •  Highlands  •  Drylands\nBlue dot = your current position"
	map_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_box.add_child(map_info)
	var map_canvas := ColorRect.new()
	map_canvas.custom_minimum_size = Vector2(420, 255)
	map_canvas.color = Color(0.10, 0.22, 0.19)
	map_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_box.add_child(map_canvas)
	var river := ColorRect.new()
	river.position = Vector2(0, 104)
	river.size = Vector2(420, 32)
	river.color = Color(0.10, 0.42, 0.65)
	map_canvas.add_child(river)
	var road_v := ColorRect.new()
	road_v.position = Vector2(205, 0)
	road_v.size = Vector2(12, 255)
	road_v.color = Color(0.68, 0.58, 0.39)
	map_canvas.add_child(road_v)
	var road_h := ColorRect.new()
	road_h.position = Vector2(0, 66)
	road_h.size = Vector2(420, 10)
	road_h.color = Color(0.68, 0.58, 0.39)
	map_canvas.add_child(road_h)
	_add_map_marker(map_canvas, Vector2(205, 66), "VILLAGE", Color(0.96, 0.78, 0.34))
	_add_map_marker(map_canvas, Vector2(76, 38), "FOREST", Color(0.28, 0.72, 0.40))
	_add_map_marker(map_canvas, Vector2(340, 36), "HILLS", Color(0.65, 0.68, 0.64))
	_add_map_marker(map_canvas, Vector2(330, 205), "FIELDS", Color(0.82, 0.67, 0.30))
	player_marker = ColorRect.new()
	player_marker.position = Vector2(197, 155)
	player_marker.size = Vector2(18, 18)
	player_marker.color = Color(0.20, 0.72, 1.0)
	map_canvas.add_child(player_marker)
	var map_close := _make_button("CLOSE MAP", Vector2.ZERO, Vector2(420, 44))
	map_box.add_child(map_close)
	map_close.pressed.connect(func(): map_panel.visible = false)

func _add_map_marker(parent: Control, pos: Vector2, caption: String, tint: Color) -> void:
	var marker := ColorRect.new()
	marker.position = pos
	marker.size = Vector2(12, 12)
	marker.color = tint
	parent.add_child(marker)
	var label := Label.new()
	label.text = caption
	label.position = pos + Vector2(14, -7)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color.WHITE)
	parent.add_child(label)

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
		if event.pressed and joystick_finger == -1:
			joystick_finger = event.index
			joystick_active = true
			_update_joystick(event.position)
		elif not event.pressed and event.index == joystick_finger:
			joystick_finger = -1
			joystick_active = false
			move_vector = Vector2.ZERO
			joystick_knob.position = Vector2(54, 54)
	elif event is InputEventScreenDrag and joystick_active and event.index == joystick_finger:
		_update_joystick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_joystick_active = event.pressed
		joystick_active = mouse_joystick_active
		if not event.pressed:
			move_vector = Vector2.ZERO
			joystick_knob.position = Vector2(54, 54)
	elif event is InputEventMouseMotion and mouse_joystick_active:
		_update_joystick(event.position)

func _update_joystick(pointer: Vector2) -> void:
	var delta := (pointer - Vector2(80, 80)).limit_length(52)
	move_vector = Vector2(delta.x / 52.0, delta.y / 52.0)
	joystick_knob.position = Vector2(54, 54) + delta

func _reset_camera() -> void:
	camera_pivot.rotation = Vector3.ZERO
	camera.rotation_degrees.x = -11
	look_finger = -1

func _toggle_pause() -> void:
	is_paused = not is_paused
	pause_panel.visible = is_paused
	get_tree().paused = is_paused
	if is_paused:
		is_running = false
		move_vector = Vector2.ZERO
		joystick_active = false
		joystick_finger = -1
		look_finger = -1
		if joystick_knob:
			joystick_knob.position = Vector2(54, 54)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and look_finger == -1 and event.position.x > get_viewport().get_visible_rect().size.x * 0.42:
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

func _add_animation_track(animation: Animation, node_path: String, times: Array[float], values: Array[Vector3]) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(node_path + ":rotation"))
	animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	for i in range(times.size()):
		animation.track_insert_key(track, times[i], values[i])

func _build_character_animations() -> void:
	var library := AnimationLibrary.new()
	var idle := Animation.new()
	idle.resource_name = "Idle"
	idle.length = 2.0
	idle.loop_mode = Animation.LOOP_LINEAR
	_add_animation_track(idle, "CharacterVisual/LeftArmPivot", [0.0, 1.0, 2.0], [Vector3(0, 0, -0.035), Vector3(0, 0, 0.035), Vector3(0, 0, -0.035)])
	_add_animation_track(idle, "CharacterVisual/RightArmPivot", [0.0, 1.0, 2.0], [Vector3(0, 0, 0.035), Vector3(0, 0, -0.035), Vector3(0, 0, 0.035)])
	library.add_animation("Idle", idle)

	var walk := Animation.new()
	walk.resource_name = "Walk"
	walk.length = 0.82
	walk.loop_mode = Animation.LOOP_LINEAR
	_add_animation_track(walk, "CharacterVisual/LeftArmPivot", [0.0, 0.205, 0.41, 0.615, 0.82], [Vector3(-0.52, 0, 0), Vector3.ZERO, Vector3(0.52, 0, 0), Vector3.ZERO, Vector3(-0.52, 0, 0)])
	_add_animation_track(walk, "CharacterVisual/RightArmPivot", [0.0, 0.205, 0.41, 0.615, 0.82], [Vector3(0.52, 0, 0), Vector3.ZERO, Vector3(-0.52, 0, 0), Vector3.ZERO, Vector3(0.52, 0, 0)])
	_add_animation_track(walk, "CharacterVisual/LeftLegPivot", [0.0, 0.205, 0.41, 0.615, 0.82], [Vector3(0.58, 0, 0), Vector3.ZERO, Vector3(-0.58, 0, 0), Vector3.ZERO, Vector3(0.58, 0, 0)])
	_add_animation_track(walk, "CharacterVisual/RightLegPivot", [0.0, 0.205, 0.41, 0.615, 0.82], [Vector3(-0.58, 0, 0), Vector3.ZERO, Vector3(0.58, 0, 0), Vector3.ZERO, Vector3(-0.58, 0, 0)])
	library.add_animation("Walk", walk)

	var run := Animation.new()
	run.resource_name = "Run"
	run.length = 0.56
	run.loop_mode = Animation.LOOP_LINEAR
	_add_animation_track(run, "CharacterVisual/LeftArmPivot", [0.0, 0.14, 0.28, 0.42, 0.56], [Vector3(-0.88, 0, 0), Vector3.ZERO, Vector3(0.88, 0, 0), Vector3.ZERO, Vector3(-0.88, 0, 0)])
	_add_animation_track(run, "CharacterVisual/RightArmPivot", [0.0, 0.14, 0.28, 0.42, 0.56], [Vector3(0.88, 0, 0), Vector3.ZERO, Vector3(-0.88, 0, 0), Vector3.ZERO, Vector3(0.88, 0, 0)])
	_add_animation_track(run, "CharacterVisual/LeftLegPivot", [0.0, 0.14, 0.28, 0.42, 0.56], [Vector3(0.92, 0, 0), Vector3.ZERO, Vector3(-0.92, 0, 0), Vector3.ZERO, Vector3(0.92, 0, 0)])
	_add_animation_track(run, "CharacterVisual/RightLegPivot", [0.0, 0.14, 0.28, 0.42, 0.56], [Vector3(-0.92, 0, 0), Vector3.ZERO, Vector3(0.92, 0, 0), Vector3.ZERO, Vector3(-0.92, 0, 0)])
	library.add_animation("Run", run)

	var jump := Animation.new()
	jump.resource_name = "Jump"
	jump.length = 0.48
	jump.loop_mode = Animation.LOOP_NONE
	_add_animation_track(jump, "CharacterVisual/LeftArmPivot", [0.0, 0.24, 0.48], [Vector3(-0.25, 0, 0), Vector3(-1.0, 0, -0.12), Vector3(-1.0, 0, -0.12)])
	_add_animation_track(jump, "CharacterVisual/RightArmPivot", [0.0, 0.24, 0.48], [Vector3(-0.25, 0, 0), Vector3(-1.0, 0, 0.12), Vector3(-1.0, 0, 0.12)])
	_add_animation_track(jump, "CharacterVisual/LeftLegPivot", [0.0, 0.24, 0.48], [Vector3(0.1, 0, 0), Vector3(0.28, 0, 0), Vector3(0.28, 0, 0)])
	_add_animation_track(jump, "CharacterVisual/RightLegPivot", [0.0, 0.24, 0.48], [Vector3(0.1, 0, 0), Vector3(0.28, 0, 0), Vector3(0.28, 0, 0)])
	library.add_animation("Jump", jump)

	var fall := Animation.new()
	fall.resource_name = "Fall"
	fall.length = 0.72
	fall.loop_mode = Animation.LOOP_LINEAR
	_add_animation_track(fall, "CharacterVisual/LeftArmPivot", [0.0, 0.36, 0.72], [Vector3(-0.82, 0, -0.16), Vector3(-0.92, 0, -0.20), Vector3(-0.82, 0, -0.16)])
	_add_animation_track(fall, "CharacterVisual/RightArmPivot", [0.0, 0.36, 0.72], [Vector3(-0.82, 0, 0.16), Vector3(-0.92, 0, 0.20), Vector3(-0.82, 0, 0.16)])
	_add_animation_track(fall, "CharacterVisual/LeftLegPivot", [0.0, 0.36, 0.72], [Vector3(0.32, 0, 0), Vector3(0.42, 0, 0), Vector3(0.32, 0, 0)])
	_add_animation_track(fall, "CharacterVisual/RightLegPivot", [0.0, 0.36, 0.72], [Vector3(0.32, 0, 0), Vector3(0.42, 0, 0), Vector3(0.32, 0, 0)])
	library.add_animation("Fall", fall)

	var land := Animation.new()
	land.resource_name = "Land"
	land.length = 0.24
	land.loop_mode = Animation.LOOP_NONE
	_add_animation_track(land, "CharacterVisual/LeftArmPivot", [0.0, 0.12, 0.24], [Vector3(-0.95, 0, -0.10), Vector3(-0.42, 0, -0.06), Vector3(-0.12, 0, 0)])
	_add_animation_track(land, "CharacterVisual/RightArmPivot", [0.0, 0.12, 0.24], [Vector3(-0.95, 0, 0.10), Vector3(-0.42, 0, 0.06), Vector3(-0.12, 0, 0)])
	_add_animation_track(land, "CharacterVisual/LeftLegPivot", [0.0, 0.12, 0.24], [Vector3(0.48, 0, 0), Vector3(0.22, 0, 0), Vector3.ZERO])
	_add_animation_track(land, "CharacterVisual/RightLegPivot", [0.0, 0.12, 0.24], [Vector3(0.48, 0, 0), Vector3(0.22, 0, 0), Vector3.ZERO])
	library.add_animation("Land", land)

	animation_player.add_animation_library("", library)
	animation_player.play("Idle")

func _update_character_animation(_delta: float) -> void:
	if character_visual == null or animation_player == null:
		return
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	var on_floor := player.is_on_floor()
	var next_animation := "Idle"
	if not on_floor:
		next_animation = "Jump" if player.velocity.y > 0.35 else "Fall"
	else:
		if not was_on_floor:
			landing_timer = 0.24
		if landing_timer > 0.0:
			next_animation = "Land"
			landing_timer = maxf(0.0, landing_timer - _delta)
		elif horizontal_speed > 0.45:
			next_animation = "Run" if is_running and horizontal_speed > WALK_SPEED * 0.65 else "Walk"
	was_on_floor = on_floor
	if next_animation != active_animation:
		active_animation = next_animation
		animation_player.play(next_animation, 0.08 if next_animation == "Land" else 0.14)
	if next_animation == "Walk":
		animation_player.speed_scale = clampf(horizontal_speed / WALK_SPEED, 0.72, 1.35)
	elif next_animation == "Run":
		animation_player.speed_scale = clampf(horizontal_speed / RUN_SPEED, 0.82, 1.22)
	else:
		animation_player.speed_scale = 1.0
	animation_clock += _delta
	var local_motion := player.global_transform.basis.inverse() * Vector3(player.velocity.x, 0.0, player.velocity.z)
	var target_side_lean := clampf(-local_motion.x * 0.018, -0.14, 0.14)
	var target_forward_lean := clampf(-horizontal_speed * 0.012, -0.12, 0.0)
	character_visual.rotation.z = lerp_angle(character_visual.rotation.z, target_side_lean, 1.0 - exp(-9.0 * _delta))
	character_visual.rotation.x = lerp_angle(character_visual.rotation.x, target_forward_lean, 1.0 - exp(-7.0 * _delta))
	if not on_floor:
		character_visual.position.y = 0.035
	elif next_animation == "Land":
		character_visual.position.y = -0.025
	elif horizontal_speed > 0.45:
		var bob_rate := 17.0 if next_animation == "Run" else 11.5
		character_visual.position.y = absf(sin(animation_clock * bob_rate)) * 0.045
	else:
		character_visual.position.y = sin(animation_clock * 2.2) * 0.012

func _physics_process(delta: float) -> void:
	if player == null or is_paused:
		return
	var keyboard := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var input_vector := move_vector if move_vector.length() > 0.08 else keyboard
	var input_strength := clampf(input_vector.length(), 0.0, 1.0)
	var camera_forward := -camera_pivot.global_transform.basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var camera_right := camera_pivot.global_transform.basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	var direction := (camera_right * input_vector.x + camera_forward * -input_vector.y).normalized()
	var target_speed := RUN_SPEED if is_running else WALK_SPEED
	var target_velocity := direction * target_speed * input_strength
	var response := MOVE_ACCELERATION if input_strength > 0.08 else MOVE_DECELERATION
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, response * delta)
	player.velocity.x = horizontal_velocity.x
	player.velocity.z = horizontal_velocity.y
	if input_strength > 0.08 and direction.length() > 0.01:
		var target_yaw := atan2(-direction.x, -direction.z)
		player.rotation.y = lerp_angle(player.rotation.y, target_yaw, 1.0 - exp(-TURN_RESPONSE * delta))
	camera_rig.global_position = player.global_position
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
	elif jump_requested:
		player.velocity.y = 6.0
	jump_requested = false
	player.move_and_slide()
	camera_rig.global_position = player.global_position
	if player.global_position.y < -20.0:
		player.global_position = Vector3(current_chunk.x * CHUNK_SIZE + 32, 3, current_chunk.y * CHUNK_SIZE + 32)
		player.velocity = Vector3.ZERO
		horizontal_velocity = Vector2.ZERO
	_update_chunks()
	_update_character_animation(delta)
	if player_marker and is_instance_valid(player_marker):
		player_marker.position = Vector2(197.0 + fposmod(player.global_position.x, 64.0) * 0.35, 145.0 + fposmod(player.global_position.z, 64.0) * 0.35)
