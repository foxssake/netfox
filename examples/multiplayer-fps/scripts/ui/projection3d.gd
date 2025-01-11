@tool
class_name Projection3D extends Node3D

## Whatever 2D nodes are added to Projection3D are projected onto a plane

## Width of the projection
@export var projection_size: Vector2 = Vector2(1.0, 0.66)
## Resolution of the projection
@export var resolution_size: Vector2 = Vector2(640, 480)
## Billboard mode (always face the player)
@export var billboard: bool = true
## Render in front of everything else
@export var always_on_top: bool = false
## No lighting or shading
@export var disable_shading: bool = true

## Emitted when the Node is fully constructed
signal on_constructed

var plane_mesh = PlaneMesh.new()
var viewport = SubViewport.new()
var original_children: Array[Node] = []

## Set the size of the projection and resolution
func set_size(new_projection_size: Vector2, new_resolution_size: Vector2):
	plane_mesh.size = new_projection_size
	viewport.size = new_resolution_size

func _ready():
	if Engine.is_editor_hint():
		return

	var children = get_children()
	original_children = children

	var mesh = MeshInstance3D.new()
	plane_mesh.size = projection_size
	plane_mesh.orientation = PlaneMesh.FACE_Z
	mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mesh.cast_shadow = false
	mesh.mesh = plane_mesh
	add_child(mesh)

	var viewport_container = SubViewportContainer.new()
	viewport_container.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.size = resolution_size
	# TODO: Figure out why the progressbar is slightly transparent.
	# It may not be a material issue but a rendering one (cleared one frame but drawn the next)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.handle_input_locally = false
	viewport_container.add_child(viewport)
	add_child(viewport_container)

	for child in children:
		child.reparent(viewport)

	var material = StandardMaterial3D.new()
	material.albedo_texture = viewport.get_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_MAX
	if billboard:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		material.billboard_keep_scale = true
	if disable_shading:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.disable_ambient_light = true
	material.no_depth_test = always_on_top
	plane_mesh.material = material

	on_constructed.emit()
