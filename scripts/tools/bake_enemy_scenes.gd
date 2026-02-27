@tool
## BakeEnemyScenes — Run from the Godot editor to generate .tscn scene files
## for all enemy mesh templates.
##
## Usage: Open this script in the editor, then Script > Run (Ctrl+Shift+X)
##
## Generates one .tscn per registered template in res://scenes/enemies/meshes/.
## Each scene is built at scale=1.0 with neutral gray color (0x808080).
## The baked scenes use Godot's built-in PrimitiveMesh resources (SphereMesh,
## BoxMesh, CylinderMesh, etc.) and can be viewed/edited in the scene editor.
extends EditorScript

const BAKE_COLOR: int = 0x808080
const BAKE_SCALE: float = 1.0
const OUTPUT_DIR: String = "res://scenes/enemies/meshes/"

# All registered template names
const TEMPLATES: Array[String] = [
	"insectoid", "swarm_bug", "arachnid", "jellyfish", "mantis",
	"scorpion", "stalker", "worm", "slug", "void_wraith",
	"dark_entity", "crystal_golem", "eldritch_eye", "reality_warper",
	"abyssal_serpent", "abyssal_horror", "cosmic_sentinel", "cosmic_titan",
]

func _run() -> void:
	# Ensure output directory exists
	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	var success_count: int = 0
	var fail_count: int = 0

	for template_name in TEMPLATES:
		var builder: EnemyMeshBuilder = EnemyMeshBuilder.get_builder(template_name)
		if builder == null:
			push_warning("BakeEnemyScenes: No builder for '%s', skipping" % template_name)
			fail_count += 1
			continue

		# Build mesh with neutral params
		var params: Dictionary = {
			"scale": BAKE_SCALE,
			"color": BAKE_COLOR,
		}
		var root: Node3D = builder.build_mesh(params)
		if root == null:
			push_warning("BakeEnemyScenes: build_mesh() returned null for '%s'" % template_name)
			fail_count += 1
			continue

		# Name the root node after the template
		root.name = template_name

		# Store bake metadata for runtime color shifting
		root.set_meta("bake_base_color", EnemyMeshBuilder.int_to_color(BAKE_COLOR))
		root.set_meta("bake_scale", BAKE_SCALE)

		# Auto-name child nodes for easier identification in the editor
		var idx: int = 0
		for child in root.get_children():
			if child is MeshInstance3D and child.name.begins_with("@"):
				child.name = "%s_part_%d" % [template_name, idx]
			idx += 1

		# Pack and save as scene
		var scene: PackedScene = PackedScene.new()
		# Set owner on all children so they get included in the scene
		_set_owner_recursive(root, root)
		var pack_err: Error = scene.pack(root)
		if pack_err != OK:
			push_warning("BakeEnemyScenes: Failed to pack '%s' (error %d)" % [template_name, pack_err])
			fail_count += 1
			root.queue_free()
			continue

		var save_path: String = OUTPUT_DIR + template_name + ".tscn"
		var save_err: Error = ResourceSaver.save(scene, save_path)
		if save_err != OK:
			push_warning("BakeEnemyScenes: Failed to save '%s' (error %d)" % [save_path, save_err])
			fail_count += 1
		else:
			success_count += 1
			print("BakeEnemyScenes: Saved %s" % save_path)

		# Clean up
		root.queue_free()

	print("BakeEnemyScenes: Done! %d saved, %d failed." % [success_count, fail_count])

## Recursively set owner on all descendants so PackedScene.pack() includes them
func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)
