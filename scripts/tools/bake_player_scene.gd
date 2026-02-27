@tool
## BakePlayerScene — Run from the Godot editor to generate a .tscn scene file
## for the player mesh.
##
## Usage: Open this script in the editor, then Script > Run (Ctrl+Shift+X)
##
## Generates res://scenes/player/meshes/player.tscn using the default style.
## The baked scene uses Godot's built-in PrimitiveMesh resources.
extends EditorScript

const OUTPUT_PATH: String = "res://scenes/player/meshes/player.tscn"

func _run() -> void:
	var dir: String = OUTPUT_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var root: Node3D = PlayerMeshBuilder.build_player_mesh()
	if root == null:
		push_warning("BakePlayerScene: build_player_mesh() returned null")
		return

	root.name = "PlayerMesh"

	# Auto-name unnamed child nodes
	var idx: int = 0
	for child in root.get_children():
		if child is MeshInstance3D and child.name.begins_with("@"):
			child.name = "player_part_%d" % idx
		idx += 1

	# Set owner on all children
	_set_owner_recursive(root, root)

	var scene: PackedScene = PackedScene.new()
	var pack_err: Error = scene.pack(root)
	if pack_err != OK:
		push_warning("BakePlayerScene: Failed to pack (error %d)" % pack_err)
		root.queue_free()
		return

	var save_err: Error = ResourceSaver.save(scene, OUTPUT_PATH)
	if save_err != OK:
		push_warning("BakePlayerScene: Failed to save (error %d)" % save_err)
	else:
		print("BakePlayerScene: Saved %s" % OUTPUT_PATH)

	root.queue_free()

func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)
