# Godot-collisionshape3d-editor
![Sample inside Godot](icon.png)

## CollisionShape3d Editor
This is a plugin to modify point_array in a collisionshape3d node (mesh must be ConvexPolygonShape3D) Godot 4.4.1

## How it work
Reload current project after activating the plugin,
when a CollisionShape3D node is selected all the tool appear.

There will be transform gizmo on the point_array of the shape you just need drag it with your cursor.
When "Add/Remove Point" button is pressed press B for adding point in your cursor position; hover to a point and press V to remove the hovered point.

There is an option bar to select on which axis-plane the point will move or will be added.

## To Do

add this function to the "convex_point_gizmo.gd" so it don't call for null name,

func _get_gizmo_name():

	return ""
