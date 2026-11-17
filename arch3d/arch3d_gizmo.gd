@tool
extends EditorNode3DGizmoPlugin

const Arch3D = preload("res://addons/arch3d/arch3d.gd")

const HANDLE_WIDTH := 0
const HANDLE_HEIGHT := 1
const HANDLE_RADIUS := 2
const HANDLE_DEPTH := 3
const HANDLE_WALL_THICKNESS := 4


func _init():
	create_handle_material("handles")


func _get_gizmo_name() -> String:
	return "Arch3D"


func _has_gizmo(node: Node3D) -> bool:
	return node is Arch3D


func _redraw(gizmo: EditorNode3DGizmo):
	gizmo.clear()

	var arch := gizmo.get_node_3d() as Arch3D

	if arch == null:
		return

	var handles := PackedVector3Array()
	var ids := PackedInt32Array()

	# ==========================================
	# BREITE
	# ==========================================

	handles.append(
		Vector3(
			arch.width / 2.0,
			arch.height / 2.0,
			0.0
		)
	)

	ids.append(HANDLE_WIDTH)


	# ==========================================
	# HÖHE
	# ==========================================

	handles.append(
		Vector3(
			0.0,
			arch.height,
			0.0
		)
	)

	ids.append(HANDLE_HEIGHT)


	# ==========================================
	# RADIUS
	# ==========================================

	handles.append(
		Vector3(
			arch.radius,
			arch.height - arch.radius,
			0.0
		)
	)

	ids.append(HANDLE_RADIUS)


	# ==========================================
	# TIEFE
	# ==========================================

	handles.append(
		Vector3(
			0.0,
			arch.height / 2.0,
			arch.depth / 2.0
		)
	)

	ids.append(HANDLE_DEPTH)


	# ==========================================
	# WANDSTÄRKE
	# ==========================================

	handles.append(
		Vector3(
			arch.width / 2.0 - arch.wall_thickness,
			arch.height / 2.0,
			0.0
		)
	)

	ids.append(HANDLE_WALL_THICKNESS)


	gizmo.add_handles(
		handles,
		get_material("handles", gizmo),
		ids
	)


func _get_handle_name(
	gizmo: EditorNode3DGizmo,
	handle_id: int,
	secondary: bool
) -> String:

	match handle_id:
		HANDLE_WIDTH:
			return "Width"

		HANDLE_HEIGHT:
			return "Height"

		HANDLE_RADIUS:
			return "Arch Radius"

		HANDLE_DEPTH:
			return "Depth"

		HANDLE_WALL_THICKNESS:
			return "Wall Thickness"

	return ""


func _get_handle_value(
	gizmo: EditorNode3DGizmo,
	handle_id: int,
	secondary: bool
) -> Variant:

	var arch := gizmo.get_node_3d() as Arch3D

	if arch == null:
		return 0.0

	match handle_id:
		HANDLE_WIDTH:
			return arch.width

		HANDLE_HEIGHT:
			return arch.height

		HANDLE_RADIUS:
			return arch.radius

		HANDLE_DEPTH:
			return arch.depth

		HANDLE_WALL_THICKNESS:
			return arch.wall_thickness

	return 0.0


func _set_handle(
	gizmo: EditorNode3DGizmo,
	handle_id: int,
	secondary: bool,
	camera: Camera3D,
	screen_pos: Vector2
):
	var arch := gizmo.get_node_3d() as Arch3D

	if arch == null:
		return


	# ==========================================
	# STRAHL DER MAUS IN LOKALE ARCH-KOORDINATEN
	# ==========================================

	var global_origin := camera.project_ray_origin(screen_pos)
	var global_direction := camera.project_ray_normal(screen_pos)

	var inverse_transform := arch.global_transform.affine_inverse()

	var ray_origin := inverse_transform * global_origin
	var ray_direction := (
		inverse_transform.basis * global_direction
	).normalized()


	# ==========================================
	# BREITE / HÖHE / RADIUS / WANDSTÄRKE
	# → XY-EBENE
	# ==========================================

	if (
		handle_id == HANDLE_WIDTH
		or handle_id == HANDLE_HEIGHT
		or handle_id == HANDLE_RADIUS
		or handle_id == HANDLE_WALL_THICKNESS
	):

		var plane := Plane(
			Vector3.FORWARD,
			0.0
		)

		var hit = plane.intersects_ray(
			ray_origin,
			ray_direction
		)

		if hit == null:
			return

		var point: Vector3 = hit


		match handle_id:

			# --------------------------
			# BREITE
			# --------------------------

			HANDLE_WIDTH:
				var new_width: float = abs(point.x) * 2.0

				arch.width = max(
					new_width,
					0.1
				)


			# --------------------------
			# HÖHE
			# --------------------------

			HANDLE_HEIGHT:
				var new_height: float = point.y

				arch.height = max(
					new_height,
					0.1
				)


			# --------------------------
			# RADIUS
			# --------------------------

			HANDLE_RADIUS:
				var center_y: float = (
					arch.height - arch.radius
				)

				var new_radius: float = sqrt(
					point.x * point.x
					+ (point.y - center_y)
					* (point.y - center_y)
				)

				var max_radius: float = (
					arch.width / 2.0
					- arch.wall_thickness
				)

				new_radius = clamp(
					new_radius,
					0.1,
					max_radius
				)

				arch.radius = new_radius


			# --------------------------
			# WANDSTÄRKE
			# --------------------------

			HANDLE_WALL_THICKNESS:
				var new_thickness: float = (
					arch.width / 2.0
					- abs(point.x)
				)

				var max_thickness: float = (
					arch.width / 2.0 - 0.05
				)

				new_thickness = clamp(
					new_thickness,
					0.05,
					max_thickness
				)

				arch.wall_thickness = new_thickness


		return


	# ==========================================
	# TIEFE
	# ==========================================

	if handle_id == HANDLE_DEPTH:

		var xy_direction_length: float = (
			ray_direction.x * ray_direction.x
			+ ray_direction.y * ray_direction.y
		)

		if xy_direction_length < 0.00001:
			return

		# Punkt auf der Z-Achse,
		# der dem Mausstrahl am nächsten liegt
		var t: float = -(
			ray_origin.x * ray_direction.x
			+ ray_origin.y * ray_direction.y
		) / xy_direction_length

		var z_position: float = (
			ray_origin.z
			+ ray_direction.z * t
		)

		var new_depth: float = abs(
			z_position * 2.0
		)

		arch.depth = max(
			new_depth,
			0.05
		)


func _commit_handle(
	gizmo: EditorNode3DGizmo,
	handle_id: int,
	secondary: bool,
	restore: Variant,
	cancel: bool
):
	var arch := gizmo.get_node_3d() as Arch3D

	if arch == null:
		return


	var property_name := ""


	match handle_id:

		HANDLE_WIDTH:
			property_name = "width"

		HANDLE_HEIGHT:
			property_name = "height"

		HANDLE_RADIUS:
			property_name = "radius"

		HANDLE_DEPTH:
			property_name = "depth"

		HANDLE_WALL_THICKNESS:
			property_name = "wall_thickness"


	if property_name == "":
		return


	# ==========================================
	# ABBRECHEN
	# ==========================================

	if cancel:
		arch.set(
			property_name,
			restore
		)

		return


	# ==========================================
	# NEUEN WERT SPEICHERN
	# ==========================================

	var new_value = arch.get(
		property_name
	)


	# ==========================================
	# UNDO / REDO
	# ==========================================

	var undo_redo := (
		EditorInterface.get_editor_undo_redo()
	)

	undo_redo.create_action(
		"Change Arch3D " + property_name
	)

	undo_redo.add_do_property(
		arch,
		property_name,
		new_value
	)

	undo_redo.add_undo_property(
		arch,
		property_name,
		restore
	)

	undo_redo.commit_action()
