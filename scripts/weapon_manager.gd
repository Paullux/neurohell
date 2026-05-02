extends Node3D

# ============================================================
#  NeuroHell — Weapon Manager
#  Gère les 5 armes, le tir plasma et la visée sniper
# ============================================================

signal weapon_switched(index: int)
signal ammo_changed(index: int, ammo: float)
signal scope_toggled(on: bool)

# --- Configs armes (équivalent WPN_LIST en JS) ---
const WEAPONS := [
	{
		"id":         "irongazlet",
		"file":       "res://assets/weapons/weapon_irongazlet.glb",
		"hands":      "both",
		"color":      Color(1.0, 0.4, 0.0),
		"sniper":     false,
		"max_ammo":   INF,
		"ammo":       INF,
		"regen":      0.0,
		"continuous": true,
		"damage":     12.0,
		"hand_rot":   Vector3(170, 180, 180)
	},
	{
		"id":         "plasma_standard",
		"file":       "res://assets/weapons/weapon_plasmapistol_standard.glb",
		"hands":      "right",
		"color":      Color(0.2, 0.47, 1.0),
		"sniper":     false,
		"max_ammo":   50.0,
		"ammo":       50.0,
		"regen":      0.7,
		"continuous": false,
		"damage":     18.0,
		"hand_rot":   Vector3(0, 180, 0),
	},
	{
		"id":         "plasma_elite",
		"file":       "res://assets/weapons/weapon_plasmapistol_elite.glb",
		"hands":      "right",
		"color":      Color(0.07, 0.27, 1.0),
		"sniper":     false,
		"max_ammo":   35.0,
		"ammo":       35.0,
		"regen":      3.0,
		"continuous": false,
		"damage":     28.0,
		"hand_rot":   Vector3(0, 180, 0),
	},
	{
		"id":         "teal_sniper",
		"file":       "res://assets/weapons/weapon_tealsniper.glb",
		"hands":      "right",
		"color":      Color(0.0, 0.87, 0.73),
		"sniper":     true,
		"max_ammo":   120.0,
		"ammo":       120.0,
		"regen":      0.4,
		"continuous": false,
		"damage":     55.0,
		"hand_rot":   Vector3(0, 0, 0),  # flip vertical + retournement canon
	},
	{
		"id":         "void_rifle",
		"file":       "res://assets/weapons/weapon_voidrifle.glb",
		"hands":      "right",
		"color":      Color(0.67, 0.0, 1.0),
		"sniper":     false,
		"max_ammo":   90.0,
		"ammo":       90.0,
		"regen":      10.0,
		"continuous": false,
		"damage":     35.0,
		"hand_rot":   Vector3(0, 180, 0),
	},
]

var current_index: int = 0
var scope_on: bool = false

# Références aux modèles chargés (Node3D)
var _model_left: Node3D  = null
var _model_right: Node3D = null

# Référence au PlasmaSystem
@onready var plasma_system: Node = $PlasmaSystem

@onready var camera: Camera3D = get_parent().get_parent() as Camera3D  # WeaponHolder → Camera3D

var _fire_held: bool = false
var _ammo_copy: Array[float] = []   # copie mutable des munitions
var _anim_players: Array[AnimationPlayer] = []  # AnimationPlayers du Gazlet (gauche + droite)

func _ready() -> void:
	# Copier les ammo pour mutation en jeu
	for w: Dictionary in WEAPONS:
		_ammo_copy.append(float(w["ammo"]))
	switch_weapon(0)

func _input(event: InputEvent) -> void:
	# Touches 1-5
	for i in range(5):
		if event.is_action_pressed("weapon_%d" % (i + 1)):
			switch_weapon(i)
			return

	# Molette
	if event.is_action_pressed("weapon_next"):
		switch_weapon((current_index + 1) % WEAPONS.size())
	elif event.is_action_pressed("weapon_prev"):
		switch_weapon((current_index - 1 + WEAPONS.size()) % WEAPONS.size())

	# Tir
	if event.is_action_pressed("fire"):
		_on_fire_pressed()
	if event.is_action_released("fire"):
		_fire_held = false
		# Rouvre les mains du Gazlet
		var _cfg: Dictionary = WEAPONS[current_index]
		if _cfg["id"] == "irongazlet":
			_play_gazlet_anim(false)

	# Visée sniper
	if event.is_action_pressed("aim"):
		var cfg: Dictionary = WEAPONS[current_index]
		if cfg["sniper"]:
			_toggle_scope()

func _process(delta: float) -> void:
	# Tir continu
	var cfg: Dictionary = WEAPONS[current_index]
	if _fire_held and cfg["continuous"]:
		_try_fire()

	# Régénération munitions
	for i in range(WEAPONS.size()):
		var w: Dictionary = WEAPONS[i]
		if float(w["max_ammo"]) != INF and _ammo_copy[i] < float(w["max_ammo"]):
			_ammo_copy[i] = minf(_ammo_copy[i] + w["regen"] * delta, w["max_ammo"])
			ammo_changed.emit(i, _ammo_copy[i])

	if plasma_system:
		plasma_system.update(delta)

func _on_fire_pressed() -> void:
	var cfg: Dictionary = WEAPONS[current_index]
	if cfg["id"] == "irongazlet":
		_fire_held = true
		_try_fire()
		# Joue l'animation de fermeture des mains
		_play_gazlet_anim(true)
	else:
		if not cfg["continuous"]:
			_try_fire()
		else:
			_fire_held = true

func _try_fire() -> void:
	var cfg: Dictionary = WEAPONS[current_index]
	var has_ammo: bool = _ammo_copy[current_index] >= 1.0 or float(cfg["max_ammo"]) == INF
	if not has_ammo: return

	if float(cfg["max_ammo"]) != INF:
		_ammo_copy[current_index] -= 1.0
		ammo_changed.emit(current_index, _ammo_copy[current_index])

	if plasma_system:
		var aim: Vector3 = _get_aim_point()

		if cfg["id"] == "irongazlet":
			# Tire des deux mains en même temps
			for model: Node3D in [_model_right, _model_left]:
				if model == null: continue
				var muzzle_node: Node3D = _find_muzzle(model)
				var muzzle: Vector3 = muzzle_node.global_position if muzzle_node else model.global_position
				var dir: Vector3 = (aim - muzzle).normalized()
				plasma_system.fire(muzzle, dir, float(cfg["damage"]), cfg["color"] as Color, cfg["id"] as String)
		else:
			var muzzle: Vector3 = _get_muzzle_position()
			var dir: Vector3    = (aim - muzzle).normalized()
			plasma_system.fire(muzzle, dir, float(cfg["damage"]), cfg["color"] as Color, cfg["id"] as String)

func _get_muzzle_position() -> Vector3:
	# Cherche le nœud "Muzzle" dans le(s) modèle(s) actif(s)
	# Priority : main droite d'abord, puis gauche (pour "both")
	for model: Node3D in [_model_right, _model_left]:
		if model == null: continue
		var muzzle: Node3D = _find_muzzle(model)
		if muzzle:
			return muzzle.global_position
	# Fallback : pointe caméra si aucun Muzzle trouvé
	push_warning("WeaponManager: nœud 'Muzzle' introuvable dans le GLB — fallback caméra")
	return camera.global_position + (-camera.global_transform.basis.z * 0.5)

func _find_muzzle(node: Node) -> Node3D:
	# Recherche récursive case-insensitive du nœud nommé "muzzle"
	if node.name.to_lower() == "muzzle" or node.name.to_lower() == "muzzlepoint":
		return node as Node3D
	# Aussi accepter "contains" pour des noms comme "GunMuzzle"
	if node.name.to_lower().contains("muzzle"):
		return node as Node3D
	for child: Node in node.get_children():
		var found: Node3D = _find_muzzle(child)
		if found: return found
	return null

func _get_aim_point() -> Vector3:
	var space := camera.get_world_3d().direct_space_state
	var cam_pos := camera.global_position
	var cam_dir := -camera.global_transform.basis.z

	var query := PhysicsRayQueryParameters3D.create(
		cam_pos,
		cam_pos + cam_dir * 200.0
	)

	query.exclude = [get_tree().get_first_node_in_group("player")]

	# 1 = monde
	# 8 = hitbox démons
	query.collision_mask = 1 | 8

	var result := space.intersect_ray(query)
	if result:
		return result["position"]

	return cam_pos + cam_dir * 60.0

func switch_weapon(idx: int) -> void:
	current_index = idx

	# Retirer les anciens modèles
	if _model_left:
		_model_left.queue_free()
		_model_left = null
	if _model_right:
		_model_right.queue_free()
		_model_right = null

	# Réinitialiser les AnimationPlayers
	_anim_players.clear()

	# Désactiver le scope
	if scope_on:
		_toggle_scope()

	# Charger le nouveau modèle
	var cfg: Dictionary = WEAPONS[idx]
	var loader := ResourceLoader.load(cfg["file"])
	if loader == null:
		push_warning("WeaponManager: impossible de charger " + cfg["file"])
		weapon_switched.emit(idx)
		return

	var scene: PackedScene = loader
	var rot_deg: Vector3 = cfg.get("hand_rot", Vector3.ZERO) as Vector3

	# Position FPS : toutes les armes en bas de l'écran
	# y plus négatif = plus bas ; z négatif = devant la caméra
	var pos_right := Vector3(0.20, -0.48, -0.50)
	var pos_left  := Vector3(-0.20, -0.48, -0.50)
	var wpn_scale := Vector3(0.8, 0.8, 0.8)

	if cfg["id"] == "irongazlet":
		# Gants : écartés et légèrement réduits
		pos_right = Vector3(0.68, -1.28, -1.50)
		pos_left  = Vector3(-0.68, -1.28, -1.50)
		wpn_scale = Vector3(0.80, 0.80, 0.80)
	elif cfg["id"] == "void_rifle":
		wpn_scale = Vector3(0.40, 0.50, 0.40)
	elif cfg["id"] == "plasma_elite":
		pos_right = Vector3(0.20, -0.40, -0.90)
	elif cfg["id"] == "plasma_standard":
		pos_right = Vector3(0.20, -0.48, -0.90)
	elif cfg.get("sniper", false):
		# Sniper : plus loin pour ne pas être dans le canon
		pos_right = Vector3(0.20, -0.48, -0.90)
		

	# Main gauche (ou les deux mains)
	if cfg["hands"] in ["left", "both"]:
		_model_left = scene.instantiate()
		add_child(_model_left)
		_model_left.position = pos_left
		_model_left.rotation_degrees = rot_deg
		_model_left.scale = wpn_scale
		if cfg["hands"] == "both":
			_model_left.scale.x = -wpn_scale.x   # miroir horizontal uniquement

	# Main droite
	if cfg["hands"] in ["right", "both"]:
		_model_right = scene.instantiate()
		add_child(_model_right)
		_model_right.position = pos_right
		_model_right.rotation_degrees = rot_deg
		_model_right.scale = wpn_scale

	# ── Animation Gazlet ─────────────────────────────────────
	# Cherche l'AnimationPlayer dans chaque modèle (gauche ET droite)
	if cfg["id"] == "irongazlet":
		for model: Node3D in [_model_right, _model_left]:
			if model == null: continue
			var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if ap:
				_anim_players.append(ap)
				# Pose initiale : première frame (main ouverte)
				var anims: PackedStringArray = ap.get_animation_list()
				if anims.size() > 0:
					ap.play(anims[0])
					ap.seek(0.0, true)
					ap.pause()

	weapon_switched.emit(idx)

func _play_gazlet_anim(close: bool) -> void:
	if _anim_players.is_empty(): return
	# Cherche une animation nommée "fire", "close", "grip" ou "attack" en priorité
	var anim_name: String = ""
	var ref_anims: PackedStringArray = _anim_players[0].get_animation_list()
	if ref_anims.is_empty(): return
	anim_name = ref_anims[0]
	for candidate: String in ["fire", "close", "grip", "attack", "squeeze"]:
		for a: String in ref_anims:
			if a.to_lower().contains(candidate):
				anim_name = a
				break
	# Joue sur les deux mains simultanément
	for ap: AnimationPlayer in _anim_players:
		if close:
			ap.play(anim_name)
		else:
			ap.play_backwards(anim_name)

func _toggle_scope() -> void:
	scope_on = !scope_on
	scope_toggled.emit(scope_on)
	camera.fov = 7.0 if scope_on else 65.0

func get_current_config() -> Dictionary:
	return WEAPONS[current_index]

func get_ammo(index: int) -> float:
	return _ammo_copy[index]
