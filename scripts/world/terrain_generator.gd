extends RefCounted
class_name VillageTerrainGenerator

# Continuous height sampling in world coordinates keeps neighbouring chunk edges aligned.
static func height_at(noise: FastNoiseLite, world_x: float, world_z: float, village_center: Vector2, flat_radius: float, falloff: float) -> float:
	var raw_height := noise.get_noise_2d(world_x, world_z) * 6.0
	var detail_height := noise.get_noise_2d(world_x * 2.7 + 173.0, world_z * 2.7 - 91.0) * 1.15
	var distance := Vector2(world_x, world_z).distance_to(village_center)
	var blend := clamp((distance - flat_radius) / maxf(falloff, 0.01), 0.0, 1.0)
	blend = blend * blend * (3.0 - 2.0 * blend)
	return (raw_height + detail_height) * blend

static func build_chunk_mesh(noise: FastNoiseLite, chunk_origin: Vector2, chunk_size: float, resolution: int, base_color: Color, village_center: Vector2, flat_radius: float, falloff: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := chunk_size / float(resolution)
	for z in range(resolution):
		for x in range(resolution):
			var x0 := float(x) * step
			var x1 := float(x + 1) * step
			var z0 := float(z) * step
			var z1 := float(z + 1) * step
			var p00 := _vertex(noise, chunk_origin, x0, z0, village_center, flat_radius, falloff)
			var p01 := _vertex(noise, chunk_origin, x0, z1, village_center, flat_radius, falloff)
			var p10 := _vertex(noise, chunk_origin, x1, z0, village_center, flat_radius, falloff)
			var p11 := _vertex(noise, chunk_origin, x1, z1, village_center, flat_radius, falloff)
			_add_vertex(surface, p00, base_color, chunk_size)
			_add_vertex(surface, p01, base_color, chunk_size)
			_add_vertex(surface, p10, base_color, chunk_size)
			_add_vertex(surface, p10, base_color, chunk_size)
			_add_vertex(surface, p01, base_color, chunk_size)
			_add_vertex(surface, p11, base_color, chunk_size)
	surface.generate_normals()
	return surface.commit()

static func _vertex(noise: FastNoiseLite, origin: Vector2, local_x: float, local_z: float, village_center: Vector2, flat_radius: float, falloff: float) -> Vector3:
	var world_x := origin.x + local_x
	var world_z := origin.y + local_z
	var y := height_at(noise, world_x, world_z, village_center, flat_radius, falloff)
	return Vector3(local_x, y, local_z)

static func _add_vertex(surface: SurfaceTool, point: Vector3, base_color: Color, chunk_size: float) -> void:
	var rock_factor := clamp((point.y - 2.0) / 7.0, 0.0, 0.72)
	var vertex_color := base_color.lerp(Color(0.43, 0.43, 0.40), rock_factor)
	if point.y < -1.5:
		vertex_color = vertex_color.lerp(Color(0.22, 0.34, 0.23), 0.28)
	surface.set_color(vertex_color)
	surface.set_uv(Vector2(point.x / chunk_size, point.z / chunk_size))
	surface.add_vertex(point)
