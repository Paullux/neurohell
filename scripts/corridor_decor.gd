extends Node
class_name CorridorDecor

# ============================================================
#  NeuroHell — Corridor Decor
#  Spawn automatique de l'arche gothique le long de tous les
#  meshes dont le nom contient "CORRIDOR".
#  Appelé depuis les scripts de niveau dans _ready()
# ============================================================

const ARCH_GLB   := "res://assets/decor/decor_arch_gothic/decor_arch_gothic.glb"
const SPACING     := 4.0    # distance (m) entre deux arches
const MIN_LEN     := 7.0    # longueur minimale du couloir pour spawner
const Y_OFFSET    := 0.0    # ajustement vertical si l'origine du GLB n'est pas au sol
const WALL_OFFSET := 0.01   # pousse l'arche légèrement hors du mur (anti z-fighting)

var _count := 0

# ── API publique ─────────────────────────────────────────────
static func attach_to_scene(scene_root: Node) -> Node:
	var inst := CorridorDecor.new()
	scene_root.add_child(inst)
	inst._place_arches(scene_root)
	return inst

# ── Scan + placement ─────────────────────────────────────────
func _place_arches(root: Node) -> void:
	var arch_res := load(ARCH_GLB)
	if arch_res == null:
		push_warning("CorridorDecor : GLB introuvable → " + ARCH_GLB)
		return
	_scan_recursive(root, arch_res)
	print("CorridorDecor : ", _count, " arche(s) placée(s)")

func _scan_recursive(node: Node, arch_res: Resource) -> void:
	if node is MeshInstance3D:
		if node.name.to_upper().contains("CORRIDOR"):
			_place_on_corridor(node as MeshInstance3D, arch_res)
	for child in node.get_children():
		_scan_recursive(child, arch_res)

func _place_on_corridor(mesh: MeshInstance3D, arch_res: Resource) -> void:
	var gaabb   := _global_aabb(mesh)
	var sx      := gaabb.size.x
	var sz      := gaabb.size.z
	var along_x := sx >= sz    # true = couloir s'étend sur X, murs sur Z± ; false = couloir sur Z, murs sur X±
	var length  := sx if along_x else sz

	if length < MIN_LEN:
		return

	var n_arches := maxi(1, int(length / SPACING))
	var floor_y  := gaabb.position.y + Y_OFFSET

	for i in n_arches:
		var t := (float(i) + 0.5) / float(n_arches)

		# Paires [position, rotation_degrees]
		# L'arche est collée CONTRE le mur latéral, son ouverture regarde vers l'intérieur
		var pairs : Array = []

		if along_x:
			# Couloir le long de X → murs latéraux à Z- et Z+
			# L'axe de marche est X ; les murs sont à gaabb.position.z et gaabb.end.z
			var walk_x := gaabb.position.x + length * t
			var wall_z_min := gaabb.position.z          # mur Z-
			var wall_z_max := gaabb.end.z               # mur Z+
			# Arche sur mur Z- : face vers Z+ (intérieur) → rotation Y = 180
			pairs.append([Vector3(walk_x, floor_y, wall_z_min + WALL_OFFSET), Vector3(0, 180, 0)])
			# Arche sur mur Z+ : face vers Z- (intérieur) → rotation Y = 0
			pairs.append([Vector3(walk_x, floor_y, wall_z_max - WALL_OFFSET), Vector3(0, 0, 0)])
		else:
			# Couloir le long de Z → murs latéraux à X- et X+
			# L'axe de marche est Z ; les murs sont à gaabb.position.x et gaabb.end.x
			var walk_z := gaabb.position.z + length * t
			var wall_x_min := gaabb.position.x          # mur X-
			var wall_x_max := gaabb.end.x               # mur X+
			# Arche sur mur X- : face vers X+ (intérieur) → rotation Y = -90
			pairs.append([Vector3(wall_x_min + WALL_OFFSET, floor_y, walk_z), Vector3(0, -90, 0)])
			# Arche sur mur X+ : face vers X- (intérieur) → rotation Y = 90
			pairs.append([Vector3(wall_x_max - WALL_OFFSET, floor_y, walk_z), Vector3(0, 90, 0)])

		for pair in pairs:
			var arch := (arch_res as PackedScene).instantiate() as Node3D
			get_tree().current_scene.add_child(arch)
			arch.global_position = pair[0] as Vector3
			arch.rotation_degrees = pair[1] as Vector3
			_count += 1

# ── Utilitaire : AABB en espace monde ────────────────────────
func _global_aabb(mesh: MeshInstance3D) -> AABB:
	var la := mesh.get_aabb()
	var gt := mesh.global_transform
	var corners := [
		la.position,
		la.position + Vector3(la.size.x, 0,        0       ),
		la.position + Vector3(0,         la.size.y, 0       ),
		la.position + Vector3(0,         0,         la.size.z),
		la.position + Vector3(la.size.x, la.size.y, 0       ),
		la.position + Vector3(la.size.x, 0,         la.size.z),
		la.position + Vector3(0,         la.size.y, la.size.z),
		la.end,
	]
	var mn : Vector3 = gt * (corners[0] as Vector3)
	var mx : Vector3 = mn
	for c in corners:
		var wp : Vector3 = gt * (c as Vector3)
		mn = Vector3(minf(mn.x, wp.x), minf(mn.y, wp.y), minf(mn.z, wp.z))
		mx = Vector3(maxf(mx.x, wp.x), maxf(mx.y, wp.y), maxf(mx.z, wp.z))
	return AABB(mn, mx - mn)
