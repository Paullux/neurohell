extends Node3D

# ============================================================
#  NeuroHell — Level 1 Controller
# ============================================================

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer        = $HUD
@onready var game_manager: Node      = $GameManager
@onready var demons_root: Node3D     = $Demons
@onready var world: Node3D           = $NavigationRegion3D/World  # GLB sous NavRegion

var _demons: Array    = []
var _pause_menu: Node = null

const SCENE_PATH := "res://scenes/level_1.tscn"

# ── Narration ─────────────────────────────────────────────────
const _NARRATION_LINES := [
	{ "dist": 4.0,  "text": "Signal perdu. Aucun retour en arrière." },
	{ "dist": 12.0, "text": "Ces créatures ont été forgées dans la douleur." },
	{ "dist": 25.0, "text": "Tu n'es pas le premier à descendre ici." },
	{ "dist": 40.0, "text": "L'âme qui alimente ce portail... c'était la mienne." },
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

	# Stats de session — reset au début du niveau
	# (deaths N'est PAS réinitialisé ici : il doit survivre aux reload_current_scene)
	GameData.soul_points  = 0
	GameData.kills        = 0
	GameData.damage_dealt = 0.0
	GameData.level_start_time = Time.get_ticks_msec() / 1000.0

	# Collecter les démons
	for demon: Node in demons_root.get_children():
		if demon.has_method("set_player"):
			demon.set_player(player)
			demon.demon_hit_player.connect(_on_demon_hit_player)
			demon.demon_died.connect(_on_demon_died)
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
	_spawn_collectibles()

	# ── Menu Pause ───────────────────────────────────────────
	_pause_menu = load("res://scripts/pause_menu.gd").new()
	_pause_menu.player      = player
	_pause_menu.level_scene = SCENE_PATH
	get_tree().root.add_child(_pause_menu)

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

func _spawn_collectibles() -> void:
	const CollectibleScript := preload("res://scripts/collectible.gd")
	# { position, type(0=HEALTH 1=ARMOR 2=AMMO), value }
	var items := [
		{ "pos": Vector3(-8,  0.5, -15), "type": 0, "val": 30.0 },  # vie
		{ "pos": Vector3( 8,  0.5, -25), "type": 2, "val": 20.0 },  # ammo
		{ "pos": Vector3(-5,  0.5, -38), "type": 1, "val": 25.0 },  # armure
		{ "pos": Vector3( 5,  0.5, -48), "type": 2, "val": 15.0 },  # ammo
		{ "pos": Vector3( 0,  0.5, -55), "type": 0, "val": 20.0 },  # vie
	]
	for item in items:
		var c := Area3D.new()
		c.set_script(CollectibleScript)
		c.type  = item["type"]
		c.value = item["val"]
		c.global_position = item["pos"]
		add_child(c)

func _on_demon_hit_player(damage: float) -> void:
	player.take_damage(damage)
	hud.show_hit_flash(Color(1.0, 0.0, 0.0, 0.35))

func _on_demon_died(demon: Node) -> void:
	GameData.kills       += 1
	GameData.soul_points += demon.soul_value
	hud.update_souls(GameData.soul_points)

func _on_player_died() -> void:
	GameData.deaths += 1
	hud.show_death_screen()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hud.hide_start_overlay()
		return
	# Échap intercepté par pause_menu via _unhandled_input — ne pas traiter ici
