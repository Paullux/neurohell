extends Node3D

# ============================================================
#  NeuroHell — Level 1 Controller
# ============================================================

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer        = $HUD
@onready var game_manager: Node      = $GameManager
@onready var demons_root: Node3D     = $Demons
@onready var world: Node3D           = $NavigationRegion3D/World  # GLB sous NavRegion

var _demons: Array = []

# ── Narration ─────────────────────────────────────────────────
const _NARRATION_LINES := [
	{ "dist": 8.0,  "text": "Signal perdu. Aucun retour en arrière." },
	{ "dist": 22.0, "text": "Ces créatures ont été forgées dans la douleur." },
	{ "dist": 38.0, "text": "Tu n'es pas le premier à descendre ici." },
	{ "dist": 58.0, "text": "L'âme qui alimente ce portail... c'était la mienne." },
]
var _narr_done: Array[bool] = [false, false, false, false]
var _spawn_pos := Vector3.ZERO

func _process(_delta: float) -> void:
	if not player: return
	var dist := player.global_position.distance_to(_spawn_pos)
	for i in _NARRATION_LINES.size():
		if not _narr_done[i] and dist >= _NARRATION_LINES[i]["dist"]:
			_narr_done[i] = true
			hud.show_narration(_NARRATION_LINES[i]["text"])

func _ready() -> void:
	# Joueur → HUD
	player.health_changed.connect(hud.set_health)
	player.armor_changed.connect(hud.set_armor)
	player.torch_changed.connect(hud.set_torch)
	player.player_died.connect(_on_player_died)
	hud.set_minimap_target(player)

	# Armes → HUD
	var wm: Node = player.get_node_or_null("Head/Camera3D/WeaponHolder/WeaponManager")
	if wm:
		wm.weapon_switched.connect(hud.set_active_weapon)
		wm.ammo_changed.connect(hud.set_ammo)
		wm.scope_toggled.connect(hud.set_scope)

	# Collecter les démons
	for demon: Node in demons_root.get_children():
		if demon.has_method("set_player"):
			demon.set_player(player)
			demon.demon_hit_player.connect(_on_demon_hit_player)
			_demons.append(demon)

	# Game manager
	game_manager.register_player(player)
	game_manager.register_demons(_demons)

	# Générer les colliders trimesh sur tous les meshes du GLB
	# (inutile si le GLB est déjà configuré "Static Collider" dans l'onglet Import)
	if world != null:
		_generate_colliders(world)
		print("DecorColliders générés : ", _collider_count)

	# Spawn point : cherche dans le GLB, sinon position par défaut
	var spawn: Node3D = null
	if world != null:
		spawn = world.find_child("Spawn", true, false) as Node3D
	var spawn_pos := Vector3(0, 2, 0)
	if spawn:
		spawn_pos = spawn.global_position + Vector3(0, 0.5, 0)
	player.global_position = spawn_pos
	player._spawn_position = spawn_pos
	_spawn_pos = spawn_pos

	# Restaurer vie & armure du niveau précédent
	if GameData.has_saved:
		player.health = GameData.health
		player.armor  = GameData.armor
		player.health_changed.emit(player.health)
		player.armor_changed.emit(player.armor)

	hud.show_start_overlay("CLIQUEZ POUR COMMENCER\n[WASD] Déplacer  [ESPACE] Sauter  [1-5] Armes  [CLIC] Tirer  [F] Torche")

# ── Génération colliders GLB ──────────────────────────────
var _collider_count := 0

func _generate_colliders(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		if not (mesh_inst.get_parent() is StaticBody3D):
			mesh_inst.create_trimesh_collision()
			_collider_count += 1
			# Décors embarqués dans le GLB → tagger "decor" pour exclure l'anti-stuck
			if mesh_inst.name.begins_with("DECOR_SRC_"):
				for c in mesh_inst.get_children():
					if c is StaticBody3D:
						c.add_to_group("decor")
						break
	for child: Node in node.get_children():
		_generate_colliders(child)

func _on_demon_hit_player(damage: float) -> void:
	player.take_damage(damage)
	hud.show_hit_flash(Color(1.0, 0.0, 0.0, 0.35))

func _on_player_died() -> void:
	hud.show_death_screen()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hud.hide_start_overlay()
