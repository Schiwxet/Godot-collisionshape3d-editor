@tool
extends EditorPlugin

var gizmo_plugin: EditorNode3DGizmoPlugin
var add_button: Button
var plane_menu: OptionButton

# Track if LMB is held for brush painting
var _brush_mouse_down := false

func _enter_tree() -> void:
	# Load gizmo plugin
	gizmo_plugin = preload("res://addons/convex3d_point_editor/convex_point_gizmo.gd").new()
	gizmo_plugin.undo_redo = get_undo_redo()
	add_node_3d_gizmo_plugin(gizmo_plugin)

	# Add Point button
	add_button = Button.new()
	add_button.text = "Add/Remove Point"
	add_button.tooltip_text = "Click B to add a new point \nClick V to remove a hovered point"
	add_button.toggle_mode = true
	add_button.toggled.connect(func(pressed):
		gizmo_plugin.add_mode = pressed
		if pressed:
			pass
	)



	# Plane selection menu
	plane_menu = OptionButton.new()
	for i in ["Free", "XY", "XZ", "YZ"]:
		plane_menu.add_item(i)
	plane_menu.tooltip_text = "Choose the plane to drag/add point on"
	plane_menu.selected = gizmo_plugin.plane_mode
	plane_menu.item_selected.connect(func(idx):
		gizmo_plugin.plane_mode = idx
	)

	# Connect selection changes
	get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)

func _exit_tree() -> void:
	if gizmo_plugin:
		remove_node_3d_gizmo_plugin(gizmo_plugin)
		gizmo_plugin = null
	_remove_controls()

func _on_selection_changed() -> void:
	var selection = get_editor_interface().get_selection()
	var nodes = selection.get_selected_nodes()
	if nodes.size() == 1:
		var node = nodes[0]
		if node is CollisionShape3D and node.shape is ConvexPolygonShape3D:
			_add_controls()
			return
	_remove_controls()

func _add_controls() -> void:
	if add_button.get_parent():
		return
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, add_button)

	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, plane_menu)

func _remove_controls() -> void:
	for ctrl in [add_button, plane_menu]:
		if ctrl and ctrl.get_parent():
			remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, ctrl)


# -------------------------
# Input handling for Add / Brush
# -------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not gizmo_plugin:
		return

	# get editor 3D viewport and camera
	var editor_vp := get_editor_interface().get_editor_viewport_3d()
	if not editor_vp:
		return
	var camera := editor_vp.get_camera_3d()
	if not camera:
		return

	# must have exactly one selected CollisionShape3D with ConvexPolygonShape3D
	var selection := get_editor_interface().get_selection().get_selected_nodes()
	if selection.size() != 1:
		return
	var node := selection[0]
	if not (node is CollisionShape3D and node.shape is ConvexPolygonShape3D):
		return
	var shape := node.shape as ConvexPolygonShape3D
	var pts := shape.points

	# mouse position
	var mouse_pos: Vector2
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		mouse_pos = event.position
	else:
		mouse_pos = editor_vp.get_mouse_position()

	# -------- Keyboard 'B' to add point --------
	if gizmo_plugin.add_mode and event is InputEventKey and event.pressed and event.keycode == KEY_B:
		var hit = gizmo_plugin._get_point_from_mouse(camera, mouse_pos, gizmo_plugin.plane_mode, pts)
		if hit:
			_add_point_undo(shape, pts, hit, node)
		return

	# -------- Keyboard 'V' to delete point (independent of add mode) --------
	if gizmo_plugin.add_mode and event is InputEventKey and event.pressed and event.keycode == KEY_V:
		var id = gizmo_plugin.current_drag_id
		if id == -1: # not dragging → fallback to nearest
			id = gizmo_plugin._get_handle_under_mouse(node, camera, mouse_pos)
		if id >= 0:
			_delete_point_undo(shape, pts, id, node)
		return




func _add_point_undo(shape: ConvexPolygonShape3D, pts: PackedVector3Array, point: Vector3, node: Node) -> void:
	# Force new point to origin on plane modes
	match gizmo_plugin.plane_mode:
		gizmo_plugin.PlaneMode.XY:
			point.z = 0.0
		gizmo_plugin.PlaneMode.XZ:
			point.y = 0.0
		gizmo_plugin.PlaneMode.YZ:
			point.x = 0.0
		_:
			pass

	var new_pts := pts.duplicate()
	new_pts.append(point)
	if gizmo_plugin.undo_redo:
		gizmo_plugin.undo_redo.create_action("Add Convex Point")
		gizmo_plugin.undo_redo.add_do_property(shape, "points", new_pts)
		gizmo_plugin.undo_redo.add_undo_property(shape, "points", pts)
		gizmo_plugin.undo_redo.commit_action()
	# refresh gizmo visuals
	if node:
		node.update_gizmos()

func _delete_point_undo(shape: ConvexPolygonShape3D, pts: PackedVector3Array, id: int, node: Node) -> void:
	if id < 0 or id >= pts.size():
		return
	
	var new_pts := pts.duplicate()
	new_pts.remove_at(id)
	print("test")

	if gizmo_plugin.undo_redo:
		gizmo_plugin.undo_redo.create_action("Delete Convex Point")
		gizmo_plugin.undo_redo.add_do_property(shape, "points", new_pts)
		gizmo_plugin.undo_redo.add_undo_property(shape, "points", pts)
		gizmo_plugin.undo_redo.commit_action()
	
	if node:
		node.update_gizmos()
