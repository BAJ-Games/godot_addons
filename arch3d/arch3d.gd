@tool
extends MeshInstance3D
class_name Arch3D


@export_category("Arch")

@export var width: float = 4.0:
	set(value):
		width = max(value, 0.1)
		_generate_arch()

@export var height: float = 4.0:
	set(value):
		height = max(value, 0.1)
		_generate_arch()

@export var depth: float = 0.5:
	set(value):
		depth = max(value, 0.05)
		_generate_arch()

@export var radius: float = 1.5:
	set(value):
		radius = max(value, 0.05)
		_generate_arch()

@export var wall_thickness: float = 0.5:
	set(value):
		wall_thickness = max(value, 0.05)
		_generate_arch()

@export_range(4, 128, 1)
var segments: int = 32:
	set(value):
		segments = value
		_generate_arch()


# =================================================
# TEXTURE
# =================================================

enum TextureMode {
	STRAIGHT,
	FOLLOW_ARCH
}

@export_category("Texture")

@export var texture: Texture2D:
	set(value):
		texture = value
		_generate_arch()

@export var texture_mode: TextureMode = TextureMode.FOLLOW_ARCH:
	set(value):
		texture_mode = value
		_generate_arch()


# =================================================
# COLLISION
# =================================================

@export_category("Collision")

@export var generate_collision: bool = true:
	set(value):
		generate_collision = value
		_generate_arch()

@export_range(0.05, 10.0, 0.05)
var texture_scale: float = 0.5:
	set(value):
		texture_scale = max(value, 0.05)
		_generate_arch()


func _ready():
	_generate_arch()


# =================================================
# ARCH GENERIEREN
# =================================================

func _generate_arch():

	var mesh_data: ArrayMesh

	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	var uvs = PackedVector2Array()


	# -------------------------------------------------
	# Grundwerte
	# -------------------------------------------------

	var thickness = wall_thickness

	var max_radius = width / 2.0 - thickness

	var inner_radius = min(radius, max_radius)
	inner_radius = max(inner_radius, 0.05)

	var outer_radius = inner_radius + thickness

	var center_y = height - outer_radius


	# -------------------------------------------------
	# Pfeilerbreite
	# -------------------------------------------------

	var pillar_width = (width - outer_radius * 2.0) / 2.0


	# -------------------------------------------------
	# Linker Pfeiler
	# -------------------------------------------------

	if pillar_width > 0:

		_add_box(
			vertices,
			indices,
			uvs,
			Vector3(-width / 2.0, 0, 0),
			Vector3(
				pillar_width,
				center_y,
				depth
			)
		)


	# -------------------------------------------------
	# Rechter Pfeiler
	# -------------------------------------------------

	if pillar_width > 0:

		_add_box(
			vertices,
			indices,
			uvs,
			Vector3(
				width / 2.0 - pillar_width,
				0,
				0
			),
			Vector3(
				pillar_width,
				center_y,
				depth
			)
		)


	# -------------------------------------------------
	# Rundbogen
	# -------------------------------------------------

	for i in range(segments):

		var angle1 = PI * float(i) / segments
		var angle2 = PI * float(i + 1) / segments


		# Innerer Radius

		var inner1 = Vector3(
			cos(angle1) * inner_radius,
			center_y + sin(angle1) * inner_radius,
			0
		)

		var inner2 = Vector3(
			cos(angle2) * inner_radius,
			center_y + sin(angle2) * inner_radius,
			0
		)


		# Äußerer Radius

		var outer1 = Vector3(
			cos(angle1) * outer_radius,
			center_y + sin(angle1) * outer_radius,
			0
		)

		var outer2 = Vector3(
			cos(angle2) * outer_radius,
			center_y + sin(angle2) * outer_radius,
			0
		)


		_add_arch_segment(
			vertices,
			indices,
			uvs,
			inner1,
			inner2,
			outer2,
			outer1,
			depth,
			angle1,
			angle2,
			inner_radius,
			outer_radius
		)


	# =================================================
	# ARRAYMESH
	# =================================================

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	if uvs.size() == vertices.size():
		arrays[Mesh.ARRAY_TEX_UV] = uvs


	# -------------------------------------------------
	# SurfaceTool für korrekte Normalen
	# -------------------------------------------------

	# -------------------------------------------------
	# SurfaceTool für korrekte Normalen
	# -------------------------------------------------

	var surface_tool = SurfaceTool.new()

	surface_tool.create_from_arrays(
		arrays,
		Mesh.PRIMITIVE_TRIANGLES
	)

	# Glatte Normalen für den Bogen erzeugen
	surface_tool.generate_normals()
	surface_tool.set_smooth_group(0)

	mesh_data = surface_tool.commit()


	# =================================================
	# MATERIAL
	# =================================================

	var material = StandardMaterial3D.new()

	material.albedo_color = Color.WHITE
	material.metallic = 0.0
	material.roughness = 0.85

	# Beide Seiten der Flächen anzeigen
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Textur nur verwenden, wenn eine vorhanden ist
	if texture != null:
		material.albedo_texture = texture
		material.texture_repeat = true

	mesh_data.surface_set_material(0, material)


	mesh = mesh_data


	# =================================================
	# COLLISION
	# =================================================

	if generate_collision:
		_generate_collision()


# =================================================
# BOX
# =================================================

func _add_box(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	uvs: PackedVector2Array,
	box_position: Vector3,
	size: Vector3
):
	# Jede Fläche bekommt eigene Vertices.
	# Dadurch können Vorderseite, Rückseite und Seiten
	# unabhängig voneinander texturiert werden.

	var p0 = box_position
	var p1 = box_position + Vector3(size.x, 0, 0)
	var p2 = box_position + Vector3(size.x, size.y, 0)
	var p3 = box_position + Vector3(0, size.y, 0)

	var p4 = box_position + Vector3(0, 0, size.z)
	var p5 = box_position + Vector3(size.x, 0, size.z)
	var p6 = box_position + Vector3(size.x, size.y, size.z)
	var p7 = box_position + Vector3(0, size.y, size.z)


	# =================================================
	# VORDERSEITE
	# =================================================

	var start = vertices.size()

	vertices.append(p0)
	vertices.append(p1)
	vertices.append(p2)
	vertices.append(p3)

	uvs.append(Vector2(p0.x / texture_scale, p0.y / texture_scale))
	uvs.append(Vector2(p1.x / texture_scale, p1.y / texture_scale))
	uvs.append(Vector2(p2.x / texture_scale, p2.y / texture_scale))
	uvs.append(Vector2(p3.x / texture_scale, p3.y / texture_scale))

	indices.append(start + 0)
	indices.append(start + 1)
	indices.append(start + 2)

	indices.append(start + 0)
	indices.append(start + 2)
	indices.append(start + 3)


	# =================================================
	# RÜCKSEITE
	# =================================================

	start = vertices.size()

	vertices.append(p4)
	vertices.append(p7)
	vertices.append(p6)
	vertices.append(p5)

	uvs.append(Vector2(p0.x / texture_scale, p0.y / texture_scale))
	uvs.append(Vector2(p3.x / texture_scale, p3.y / texture_scale))
	uvs.append(Vector2(p2.x / texture_scale, p2.y / texture_scale))
	uvs.append(Vector2(p1.x / texture_scale, p1.y / texture_scale))

	indices.append(start + 0)
	indices.append(start + 1)
	indices.append(start + 2)

	indices.append(start + 0)
	indices.append(start + 2)
	indices.append(start + 3)


	# =================================================
	# UNTERSEITE
	# =================================================

	start = vertices.size()

	vertices.append(p0)
	vertices.append(p4)
	vertices.append(p5)
	vertices.append(p1)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(size.z / texture_scale, 0))
	uvs.append(Vector2(size.z / texture_scale, size.x / texture_scale))
	uvs.append(Vector2(0, size.x / texture_scale))

	indices.append(start + 0)
	indices.append(start + 1)
	indices.append(start + 2)

	indices.append(start + 0)
	indices.append(start + 2)
	indices.append(start + 3)


	# =================================================
	# OBERSEITE
	# =================================================

	start = vertices.size()

	vertices.append(p3)
	vertices.append(p2)
	vertices.append(p6)
	vertices.append(p7)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(size.x / texture_scale, 0))
	uvs.append(Vector2(size.x / texture_scale, size.z / texture_scale))
	uvs.append(Vector2(0, size.z / texture_scale))

	indices.append(start + 0)
	indices.append(start + 1)
	indices.append(start + 2)

	indices.append(start + 0)
	indices.append(start + 2)
	indices.append(start + 3)


	# =================================================
	# LINKE SEITE
	# =================================================

	start = vertices.size()

	vertices.append(p0)
	vertices.append(p3)
	vertices.append(p7)
	vertices.append(p4)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(size.y / texture_scale, 0))
	uvs.append(Vector2(size.y / texture_scale, size.z / texture_scale))
	uvs.append(Vector2(0, size.z / texture_scale))

	indices.append(start + 0)
	indices.append(start + 1)
	indices.append(start + 2)

	indices.append(start + 0)
	indices.append(start + 2)
	indices.append(start + 3)


	# =================================================
	# RECHTE SEITE
	# =================================================

	start = vertices.size()

	vertices.append(p1)
	vertices.append(p5)
	vertices.append(p6)
	vertices.append(p2)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(size.z / texture_scale, 0))
	uvs.append(Vector2(size.z / texture_scale, size.y / texture_scale))
	uvs.append(Vector2(0, size.y / texture_scale))

	indices.append(start + 0)
	indices.append(start + 1)
	indices.append(start + 2)

	indices.append(start + 0)
	indices.append(start + 2)
	indices.append(start + 3)
# =================================================
# BOGENSEGMENT
# =================================================

func _add_arch_segment(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	uvs: PackedVector2Array,
	inner1: Vector3,
	inner2: Vector3,
	outer2: Vector3,
	outer1: Vector3,
	segment_depth: float,
	angle1: float,
	angle2: float,
	inner_radius: float,
	outer_radius: float
):
	var inner1_back = inner1 + Vector3(0, 0, segment_depth)
	var inner2_back = inner2 + Vector3(0, 0, segment_depth)
	var outer1_back = outer1 + Vector3(0, 0, segment_depth)
	var outer2_back = outer2 + Vector3(0, 0, segment_depth)

	var center_radius = (inner_radius + outer_radius) * 0.5

	var arc1 = angle1 * center_radius
	var arc2 = angle2 * center_radius

	var radial_size = outer_radius - inner_radius


	# =================================================
	# UVs VORDER-/RÜCKSEITE
	# =================================================

	var uv_inner1: Vector2
	var uv_inner2: Vector2
	var uv_outer1: Vector2
	var uv_outer2: Vector2

	if texture_mode == TextureMode.FOLLOW_ARCH:
		uv_inner1 = Vector2(
			arc1 / texture_scale,
			0.0
		)

		uv_inner2 = Vector2(
			arc2 / texture_scale,
			0.0
		)

		uv_outer1 = Vector2(
			arc1 / texture_scale,
			radial_size / texture_scale
		)

		uv_outer2 = Vector2(
			arc2 / texture_scale,
			radial_size / texture_scale
		)

	else:
		uv_inner1 = Vector2(
			inner1.x / texture_scale,
			inner1.y / texture_scale
		)

		uv_inner2 = Vector2(
			inner2.x / texture_scale,
			inner2.y / texture_scale
		)

		uv_outer1 = Vector2(
			outer1.x / texture_scale,
			outer1.y / texture_scale
		)

		uv_outer2 = Vector2(
			outer2.x / texture_scale,
			outer2.y / texture_scale
		)


	# =================================================
	# VORDERSEITE
	# =================================================

	var start = vertices.size()

	vertices.append(inner1)
	vertices.append(inner2)
	vertices.append(outer2)
	vertices.append(outer1)

	uvs.append(uv_inner1)
	uvs.append(uv_inner2)
	uvs.append(uv_outer2)
	uvs.append(uv_outer1)

	indices.append(start + 0)
	indices.append(start + 1)
	indices.append(start + 2)

	indices.append(start + 0)
	indices.append(start + 2)
	indices.append(start + 3)


	# =================================================
	# RÜCKSEITE
	# =================================================

	start = vertices.size()

	vertices.append(inner1_back)
	vertices.append(outer1_back)
	vertices.append(outer2_back)
	vertices.append(inner2_back)

	uvs.append(uv_inner1)
	uvs.append(uv_outer1)
	uvs.append(uv_outer2)
	uvs.append(uv_inner2)

	indices.append(start + 0)
	indices.append(start + 1)
	indices.append(start + 2)

	indices.append(start + 0)
	indices.append(start + 2)
	indices.append(start + 3)


	# =================================================
	# INNENFLÄCHE
	# =================================================
	# Diese Fläche verbindet Vorder- und Rückseite
	# entlang der kompletten Innenseite der Öffnung.

	start = vertices.size()

	vertices.append(inner1)
	vertices.append(inner1_back)
	vertices.append(inner2_back)
	vertices.append(inner2)

	uvs.append(Vector2(
		arc1 / texture_scale,
		0.0
	))

	uvs.append(Vector2(
		arc1 / texture_scale,
		segment_depth / texture_scale
	))

	uvs.append(Vector2(
		arc2 / texture_scale,
		segment_depth / texture_scale
	))

	uvs.append(Vector2(
		arc2 / texture_scale,
		0.0
	))

	indices.append(start + 0)
	indices.append(start + 2)
	indices.append(start + 1)

	indices.append(start + 0)
	indices.append(start + 3)
	indices.append(start + 2)


	# =================================================
	# AUSSENFLÄCHE
	# =================================================
	# Diese Fläche verbindet Vorder- und Rückseite
	# entlang der Außenseite des Bogens.

	start = vertices.size()

	vertices.append(outer1)
	vertices.append(outer2)
	vertices.append(outer2_back)
	vertices.append(outer1_back)

	uvs.append(Vector2(
		arc1 / texture_scale,
		0.0
	))

	uvs.append(Vector2(
		arc2 / texture_scale,
		0.0
	))

	uvs.append(Vector2(
		arc2 / texture_scale,
		segment_depth / texture_scale
	))

	uvs.append(Vector2(
		arc1 / texture_scale,
		segment_depth / texture_scale
	))

	indices.append(start + 0)
	indices.append(start + 1)
	indices.append(start + 2)

	indices.append(start + 0)
	indices.append(start + 2)
	indices.append(start + 3)



# =================================================
# COLLISION
# =================================================

func _generate_collision():

	# Alte Kollision entfernen

	var old_body = get_node_or_null("CollisionBody")

	if old_body:
		old_body.queue_free()


	# Prüfen, ob Mesh vorhanden ist

	if mesh == null:
		return


	# StaticBody3D

	var body = StaticBody3D.new()

	body.name = "CollisionBody"

	add_child(body)


	# CollisionShape3D

	var collision = CollisionShape3D.new()

	collision.name = "CollisionShape3D"

	body.add_child(collision)


	# Kollisionsform aus Mesh

	var shape = ConcavePolygonShape3D.new()

	shape.set_faces(
		mesh.get_faces()
	)

	collision.shape = shape
