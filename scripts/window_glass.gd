extends Node

# ============================================================
#  NeuroHell — WindowGlass
#  Applique un matériau vitré transparent à tous les meshes
#  dont le nom correspond au pattern LVL_Room_*_Window_*
# ============================================================

func _ready() -> void:
	# Attendre un frame que le GLB soit bien instancié
	await get_tree().process_frame

	var mat := StandardMaterial3D.new()

	# --- Transparence ---
	mat.transparency        = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color        = Color(0.55, 0.78, 1.0, 0.18)   # bleu-gris, très léger

	# --- Surface ---
	mat.metallic            = 0.2
	mat.roughness           = 0.04                             # quasi miroir

	# --- Émission cyberpunk (très subtile) ---
	mat.emission_enabled          = true
	mat.emission                  = Color(0.35, 0.60, 1.0)
	mat.emission_energy_multiplier = 0.20

	# --- Visible des deux côtés ---
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# --- Depth + tri correct pour les alpha ---
	mat.depth_draw_mode   = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.no_depth_test     = false

	_apply(get_tree().root, mat)

func _apply(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D and "Window" in node.name and node.mesh != null:
		for i in node.mesh.get_surface_count():
			node.set_surface_override_material(i, mat)

	for child in node.get_children():
		_apply(child, mat)
