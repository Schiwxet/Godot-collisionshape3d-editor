@tool
extends EditorNode3DGizmoPlugin

var undo_redo: EditorUndoRedoManager
var add_mode := false
var selected_handle := -1

enum PlaneMode { FREE, XY, XZ, YZ }
var plane_mode := PlaneMode.FREE


var current_drag_id: int = -1

# --- GIZMO SETUP ---

func _has_gizmo(node: Node3D) -> bool:
	return node is CollisionShape3D and node.shape is ConvexPolygonShape3D


func _create_gizmo(node: Node3D) -> EditorNode3DGizmo:
	return EditorNode3DGizmo.new()

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var cs := gizmo.get_node_3d() as CollisionShape3D
	if not cs or not cs.shape is ConvexPolygonShape3D:
		return

	# Only draw gizmo if node is selected
	var selection = EditorInterface.get_selection()
	if selection == null or not cs in selection.get_selected_nodes():
		gizmo.clear()  # Make sure gizmo is cleared
		return

	var pts = cs.shape.points
	if pts.size() == 0:
		return

	var ids = PackedInt32Array()
	for i in range(pts.size()):
		ids.append(i)

	# Make handles selectable so input works
	gizmo.add_handles(pts, null, ids, false, true)

	# Draw little cross lines for visualization
	var lines = PackedVector3Array()
	var s = 0.05
	for p in pts:
		lines.append_array([p + Vector3(s,0,0), p - Vector3(s,0,0)])
		lines.append_array([p + Vector3(0,s,0), p - Vector3(0,s,0)])
		lines.append_array([p + Vector3(0,0,s), p - Vector3(0,0,s)])
	gizmo.add_lines(lines, null)

#get point id
func _get_handle_name(gizmo: EditorNode3DGizmo, id: int, is_selected: bool) -> String:
	return "Point %d" % id

#cs.shape.points[id] get the point vector3
func _get_handle_value(gizmo: EditorNode3DGizmo, id: int, is_selected: bool) -> Variant:
	var cs := gizmo.get_node_3d() as CollisionShape3D
	return cs.shape.points[id] if id >= 0 and id < cs.shape.points.size() else Vector3.ZERO

#i think is point moving
func _set_handle(gizmo: EditorNode3DGizmo, id: int, is_selected: bool, camera: Camera3D, mouse_pos: Vector2) -> void:
	var cs := gizmo.get_node_3d() as CollisionShape3D
	if not cs or not cs.shape is ConvexPolygonShape3D:
		return
	var shape := cs.shape as ConvexPolygonShape3D
	var pts := shape.points
	if id < 0 or id >= pts.size():
		return

	# remember which point is being dragged
	current_drag_id = id

	var new_pos = _get_point_from_mouse(camera, mouse_pos, plane_mode, pts, id)
	pts[id] = new_pos
	shape.points = pts


#edited handle (save edited handle for undoredo)
func _commit_handle(gizmo: EditorNode3DGizmo, id: int, is_selected: bool, restore: Variant, cancel: bool) -> void:
	current_drag_id = -1
	var cs := gizmo.get_node_3d() as CollisionShape3D
	var shape := cs.shape as ConvexPolygonShape3D
	var pts := shape.points
	if id < 0 or id >= pts.size():
		return

	if cancel:
		pts[id] = restore
		shape.points = pts
		cs.update_gizmos()
		return

	var before := pts.duplicate()
	before[id] = restore
	var after := pts.duplicate()

	if undo_redo:
		undo_redo.create_action("Move Convex Point")
		undo_redo.add_do_property(shape, "points", after)
		undo_redo.add_undo_property(shape, "points", before)
		undo_redo.commit_action()


# --- HELPERS ---

func _get_point_from_mouse(camera: Camera3D, mouse_pos: Vector2, plane: int, pts: PackedVector3Array, id: int=-1) -> Vector3:
	var from = camera.project_ray_origin(mouse_pos)
	var dir = camera.project_ray_normal(mouse_pos)
	var point = from

	var ref = Vector3.ZERO
	if id >= 0 and id < pts.size():
		ref = pts[id]
	elif pts.size() > 0:
		ref = pts[pts.size() - 1]

	match plane:
		PlaneMode.XY:
			var t = (ref.z - from.z)/dir.z if abs(dir.z) > 0.001 else 0
			point = from + dir * t
			point.z = ref.z
		PlaneMode.XZ:
			var t = (ref.y - from.y)/dir.y if abs(dir.y) > 0.001 else 0
			point = from + dir * t
			point.y = ref.y
		PlaneMode.YZ:
			var t = (ref.x - from.x)/dir.x if abs(dir.x) > 0.001 else 0
			point = from + dir * t
			point.x = ref.x
		PlaneMode.FREE:
			var t = (ref - from).dot(dir)/dir.length_squared()
			point = from + dir * t

	# Shift snapping
	if Input.is_key_pressed(KEY_SHIFT):
		var snap = 0.01
		point = Vector3(round(point.x/snap)*snap, round(point.y/snap)*snap, round(point.z/snap)*snap)

	# Axis locking
	if Input.is_key_pressed(KEY_X):
		point.y = ref.y
		point.z = ref.z
	elif Input.is_key_pressed(KEY_Y):
		point.x = ref.x
		point.z = ref.z
	elif Input.is_key_pressed(KEY_Z):
		point.x = ref.x
		point.y = ref.y

	return point


func _get_handle_under_mouse(node: Node3D, camera: Camera3D, mouse_pos: Vector2) -> int:
	var cs := node as CollisionShape3D
	if not cs or not cs.shape is ConvexPolygonShape3D:
		return -1
	var shape := cs.shape as ConvexPolygonShape3D
	var min_dist = 10.0
	var closest_id = -1
	for i in range(shape.points.size()):
		var screen_pos = camera.unproject_position(shape.points[i])
		var dist = screen_pos.distance_to(mouse_pos)
		if dist < min_dist:
			min_dist = dist
			closest_id = i
	return closest_id
