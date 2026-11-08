extends RefCounted
class_name VillageAssetGenerator

# Lightweight stylized environment assets. All placements are deterministic per chunk.
static func add_chunk_detail(root: Node3D, biome: String, rng: RandomNumberGenerator, cx: int, cz: int, chunk_size: float, height_sampler: Callable) -> void:
	if biome == "dryland":
		return

	var grass_transforms: Array[Transform3D] = []
	var grass_colors: Array[Color] = []
	var grass_palette := [
		Color(0.28, 0.48, 0.20),
		Color(0.38, 0.56, 0.24),
		Color(0.48, 0.59, 0.27)
	]
	var grass_count := 42 if biome == "highland" else 64
	for i in range(grass_count):
		var x := rng.randf_range(3.0, chunk_size - 3.0)
		var z := rng.randf_range(3.0, chunk_size - 3.0)
		var wx := float(cx) * chunk_size + x
		var wz := float(cz) * chunk_size + z
		if cx == 0 and cz == 0 and Vector2(wx - 32.0, wz - 32.0).length() < 39.0:
			continue
		var y: float = height_sampler.call(wx, wz)
		var clump_scale := rng.randf_range(0.72, 1.25)
		for blade in range(3):
			var angle := rng.randf_range(0.0, TAU)
			var offset := Vector3(cos(angle) * 0.12, 0.20 * clump_scale, sin(angle) * 0.12)
			var basis := Basis().rotated(Vector3.UP, angle).scaled(Vector3(0.72, clump_scale, 0.72))
			grass_transforms.append(Transform3D(basis, Vector3(x, y, z) + offset))
			grass_colors.append(grass_palette[rng.randi_range(0, grass_palette.size() - 1)])

	if not grass_transforms.is_empty():
		var blade_mesh := CapsuleMesh.new()
		blade_mesh.radius = 0.045
		blade_mesh.height = 0.52
		var grass_multi := MultiMesh.new()
		grass_multi.transform_format = MultiMesh.TRANSFORM_3D
		grass_multi.use_colors = true
		grass_multi.mesh = blade_mesh
		grass_multi.instance_count = grass_transforms.size()
		for i in range(grass_transforms.size()):
			grass_multi.set_instance_transform(i, grass_transforms[i])
			grass_multi.set_instance_color(i, grass_colors[i])
		var grass_material := StandardMaterial3D.new()
		grass_material.vertex_color_use_as_albedo = true
		grass_material.roughness = 1.0
		var grass_batch := MultiMeshInstance3D.new()
		grass_batch.name = "GrassDetailBatch"
		grass_batch.multimesh = grass_multi
		grass_batch.material_override = grass_material
		root.add_child(grass_batch)

	var shrub_transforms: Array[Transform3D] = []
	var shrub_colors: Array[Color] = []
	var shrub_count := 7 if biome == "highland" else 11
	for i in range(shrub_count):
		var x := rng.randf_range(5.0, chunk_size - 5.0)
		var z := rng.randf_range(5.0, chunk_size - 5.0)
		var wx := float(cx) * chunk_size + x
		var wz := float(cz) * chunk_size + z
		if cx == 0 and cz == 0 and Vector2(wx - 32.0, wz - 32.0).length() < 40.0:
			continue
		var y: float = height_sampler.call(wx, wz)
		var scale_value := rng.randf_range(0.65, 1.05)
		var basis := Basis().scaled(Vector3(scale_value * 1.15, scale_value * 0.72, scale_value))
		shrub_transforms.append(Transform3D(basis, Vector3(x, y + 0.48 * scale_value, z)))
		shrub_colors.append([Color(0.12, 0.31, 0.14), Color(0.18, 0.39, 0.17), Color(0.25, 0.44, 0.19)][rng.randi_range(0, 2)])

	if not shrub_transforms.is_empty():
		var shrub_mesh := SphereMesh.new()
		shrub_mesh.radius = 0.78
		shrub_mesh.height = 1.25
		var shrub_multi := MultiMesh.new()
		shrub_multi.transform_format = MultiMesh.TRANSFORM_3D
		shrub_multi.use_colors = true
		shrub_multi.mesh = shrub_mesh
		shrub_multi.instance_count = shrub_transforms.size()
		for i in range(shrub_transforms.size()):
			shrub_multi.set_instance_transform(i, shrub_transforms[i])
			shrub_multi.set_instance_color(i, shrub_colors[i])
		var shrub_material := StandardMaterial3D.new()
		shrub_material.vertex_color_use_as_albedo = true
		shrub_material.roughness = 1.0
		var shrub_batch := MultiMeshInstance3D.new()
		shrub_batch.name = "ShrubDetailBatch"
		shrub_batch.multimesh = shrub_multi
		shrub_batch.material_override = shrub_material
		root.add_child(shrub_batch)

static func add_village_props(root: Node3D) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.30, 0.18, 0.10)
	wood.roughness = 0.94
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.42, 0.45, 0.42)
	stone.roughness = 1.0

	# Two simple benches beside the village paths.
	for bench_pos in [Vector3(23.0, 0.0, 24.0), Vector3(42.0, 0.0, 18.0)]:
		var bench := Node3D.new()
		bench.name = "VillageBench"
		bench.position = bench_pos
		root.add_child(bench)
		_add_box(bench, Vector3(0.0, 0.58, 0.0), Vector3(1.8, 0.14, 0.62), wood)
		_add_box(bench, Vector3(0.0, 1.02, 0.27), Vector3(1.8, 0.72, 0.12), wood)
		for side in [-0.68, 0.68]:
			_add_box(bench, Vector3(side, 0.30, 0.0), Vector3(0.13, 0.58, 0.48), wood)

	# Low stone edging gives the crop plots a readable boundary.
	for side in [-1.0, 1.0]:
		for i in range(8):
			var x := 65.0 + float(i) * 2.7
			_add_box(root, Vector3(x, 0.22, 4.0 + (side + 1.0) * 20.0), Vector3(0.9, 0.42, 0.48), stone)

static func _add_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
