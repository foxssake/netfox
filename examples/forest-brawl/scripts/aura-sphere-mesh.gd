@tool
extends ArrayMesh
class_name AuraSphereMesh

@export var segments: int = 64:
	set(v):
		segments = v
		regenerate()

@export var rings: int = 32:
	set(v):
		rings = v
		regenerate()

@export var radius: float = 1.0:
	set(v):
		radius = v
		regenerate()

@export var material: Material:
	set(v):
		material = v
		surface_set_material(0, material)

func _init():
	regenerate()

func regenerate():
	clear_surfaces()
	var sphere = SphereMesh.new()
	sphere.radial_segments = segments
	sphere.rings = rings
	sphere.radius = radius
	sphere.height = 2 * radius
	sphere.is_hemisphere = false
	
	var arrays = sphere.get_mesh_arrays()
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	
	for i in range(uvs.size()):
		var uv = positions[i]
		uv = Vector2(uv.x, uv.y) / radius
		uv = (Vector2.ONE + uv) / 2.0
		
		uvs.set(i, uv)
	
	add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	surface_set_material(0, material)
