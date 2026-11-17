@tool
extends EditorPlugin

const Arch3DGizmo = preload("res://addons/arch3d/arch3d_gizmo.gd")

var gizmo_plugin: EditorNode3DGizmoPlugin


func _enter_tree():
	gizmo_plugin = Arch3DGizmo.new()
	add_node_3d_gizmo_plugin(gizmo_plugin)


func _exit_tree():
	if gizmo_plugin:
		remove_node_3d_gizmo_plugin(gizmo_plugin)
