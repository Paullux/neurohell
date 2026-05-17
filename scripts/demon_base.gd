extends CharacterBody3D

# ============================================================
#  NeuroHell — Demon Base AI
# ============================================================

@export var demon_name: String  = "Demon"
@export var hp_max: float       = 80.0
@export var chase_speed: float  = 3.5
@export var spawn_dist: float   = 18.0
@export var melee_range: float  = 1.5
@export var melee_damage: float = 15.0

@export var float_amplitude: float = 0.0   # > 0 → vole directement (Voidborn)
@export var float_freq: float      = 1.0
@export var float_hover: float     = 0.0   # hauteur de survol au-dessus des pieds du joueur (ex: 1.6 = caméra)
@export var soul_value: int        = 10    # points d'âme accordés à la mort

# ── Débris à la mort ──────────────────────────────────────────
@export_group("Débris")
@export var debris_count:      int         = 6
@export var debris_color:      Color       = Color(0.28, 0.04, 0.04)
@export var debris_fire_color: Color       = Color(1.0, 0.95, 0.3)   # jaune par défaut — violet pour Spectre, cyan pour Voidborn
@export var debris_meshes:     Array[Mesh] = []   # laisser vide = placeholder, remplir avec assets Rodin

# ── Noms d'animations (visibles dans l'Inspector) ────────────
@export var anim_idle:        String = "Idle"
@export var anim_walk:        String = "Walk"
@export var anim_attack:      String = ""
@export var anim_speed_scale: float  = 1.0   # multiplicateur de vitesse d'animation

# ── Sons (assigner dans l'Inspector de chaque démon) ─────────
@export_group("Sons")
@export var snd_spawn:    AudioStream = null  # cri à l'activation
@export var snd_move:     AudioStream = null  # bruit de déplacement (boucle à intervalle)
@export var snd_attack:   AudioStream = null  # son d'attaque corps-à-corps
@export var snd_hit:      AudioStream = null  # réaction aux dégâts
@export var snd_die:      AudioStream = null  # mort
## Secondes entre deux sons de déplacement (pas, claquements…)
@export var snd_move_interval: float = 0.55

# ── État ─────────────────────────────────────────────────────
var hp: float
var dead               := false
var active             := false
var respawn_timer: float = 0.0
var float_phase: float   = 0.0
var _melee_cooldown: float = 0.0
var _current_anim: String  = ""
var _attacking: bool       = false

# ── Anti-coincement ───────────────────────────────────────────
var _stuck_timer: float = 0.0
var _prev_xz: Vector2   = Vector2.ZERO

# ── Voidborn : évitement d'obstacle vertical ──────────────────
var _hover_adjust: float = 0.0   # décalage Y dynamique (négatif = descend pour passer)
var _corpse: Node3D = null        # cadavre spawné à la mort, supprimé au respawn

# ── Nodes ─────────────────────────────────────────────────────
@onready var nav_agent:    NavigationAgent3D = $NavigationAgent3D
@onready var model_holder: Node3D            = $ModelHolder
@onready var _col_shape:   CollisionShape3D  = $CollisionShape3D
var anim_player: AnimationPlayer = null

var _player: CharacterBody3D = null
var _spawn_position: Vector3
var _base_y: float = 0.0
@export var gravity_scale: float = 1.0   # multiplicateur de gravité (>1 = plus lourd → colle mieux aux pentes)
const GRAVITY := 30.0

# ── Audio 3D ──────────────────────────────────────────────────
var _audio:       AudioStreamPlayer3D = null
var _move_timer:  float               = 0.0

signal demon_died(demon)
signal demon_hit_player(damage: float)

# ── Init ──────────────────────────────────────────────────────
func _ready() -> void:
	hp          = hp_max
	float_phase = randf() * TAU
	# Capturer la position de spawn au frame suivant (après que tous les _ready parents soient finis)
	call_deferred("_capture_spawn_position")
	visible         = false
	collision_layer = 2
	_setup_audio()
	_auto_load_sounds()
	collision_mask = 1
	add_to_group("demon")
	
	_add_hitbox()

	# Démons volants (float_amplitude > 0) : pas de snap au sol
	# Démons terrestres : snap agressif pour coller aux rampes
	floor_snap_length = 0.0 if float_amplitude > 0.0 else 1.0
	floor_max_angle   = deg_to_rad(70.0)
	floor_stop_on_slope = false   # permet de monter/descendre les pentes sans être stoppé

	nav_agent.path_desired_distance   = 0.5
	nav_agent.target_desired_distance = 1.0
	nav_agent.avoidance_enabled       = true
	nav_agent.radius                  = 0.4
	nav_agent.neighbor_distance       = 5.0
	nav_agent.max_neighbors           = 8
	nav_agent.max_speed               = chase_speed

	anim_player = _find_anim_player(model_holder)
	if anim_player:
		print("[%s] Animations : %s" % [demon_name, anim_player.get_animation_list()])
		if not anim_player.animation_finished.is_connected(_on_anim_finished):
			anim_player.animation_finished.connect(_on_anim_finished)
	else:
		push_warning("[%s] AnimationPlayer introuvable" % demon_name)

	_autoload_debris_meshes()

func _autoload_debris_meshes() -> void:
	# Charge automatiquement les 3 GLB de débris selon demon_name (ex: "Mawgrub" → waste_mawgrub_1.glb)
	# Si debris_meshes est déjà rempli manuellement dans l'Inspector, on ne touche à rien.
	if debris_meshes.size() > 0:
		return
	var base := demon_name.to_lower()
	for i in range(1, 4):
		var path := "res://assets/demons/waste/%s/waste_%s_%d.glb" % [demon_name, base, i]
		if not ResourceLoader.exists(path):
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			continue
		var inst := packed.instantiate()
		var mi   := _find_mesh_instance(inst)
		if mi and mi.mesh:
			debris_meshes.append(mi.mesh)
		inst.free()
	if debris_meshes.size() > 0:
		print("[%s] %d mesh débris chargés automatiquement" % [demon_name, debris_meshes.size()])

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var result := _find_mesh_instance(child)
		if result:
			return result
	return null

func _capture_spawn_position() -> void:
	_spawn_position = global_position
	_base_y         = global_position.y
	print("[%s] spawn_position capturée : %s" % [demon_name, _spawn_position])

func _add_hitbox() -> void:
	if has_node("Hitbox"):
		return

	var hitbox := Area3D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 8
	hitbox.collision_mask = 0
	hitbox.add_to_group("demon_hitbox")

	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()

	capsule.radius = 0.85
	capsule.height = 2.4

	col.shape = capsule
	col.position = Vector3(0.0, 1.2, 0.0)

	hitbox.add_child(col)
	add_child(hitbox)

func _find_anim_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child as AnimationPlayer
		var found := _find_anim_player(child)
		if found:
			return found
	return null

# ── Auto-chargement des sons depuis assets/audio/demons/<nom>/ ────────────
# Si les exports Sons restent null dans l'Inspector, charge automatiquement
# les fichiers .ogg par convention de nommage : demon_name.to_lower()
func _auto_load_sounds() -> void:
	var key := demon_name.to_lower()
	var base := "res://assets/audio/demons/%s/" % key
	if snd_spawn  == null: snd_spawn  = _try_load(base + "%s_spawn.ogg"  % key)
	if snd_move   == null: snd_move   = _try_load(base + "%s_move.ogg"   % key)
	if snd_attack == null: snd_attack = _try_load(base + "%s_attack.ogg" % key)
	if snd_hit    == null: snd_hit    = _try_load(base + "%s_hit.ogg"    % key)
	if snd_die    == null: snd_die    = _try_load(base + "%s_die.ogg"    % key)

func _try_load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null

func _setup_audio() -> void:
	_audio = AudioStreamPlayer3D.new()
	_audio.bus              = "Demons"
	_audio.max_distance     = 35.0
	_audio.unit_size        = 8.0    # plus fort à proximité
	_audio.volume_db        = 3.0    # +3 dB par défaut
	_audio.panning_strength = 1.0
	add_child(_audio)

func _play_snd(stream: AudioStream, force: bool = false) -> void:
	if stream == null or _audio == null:
		return
	if _audio.playing and not force:
		return
	_audio.stream = stream
	_audio.play()

func set_player(p: CharacterBody3D) -> void:
	_player = p

# ── Physique + IA ─────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if dead:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()
		return

	if _player == null: return

	var dist := global_position.distance_to(_player.global_position)

	# Activation à portée
	if not active and dist < spawn_dist:
		active  = true
		visible = true
		scale   = Vector3.ONE * 0.01
		_play_snd(snd_spawn, true)   # cri à l'activation

	if not active: return

	# Pop-in scale
	if scale.y < 0.99:
		scale = scale.lerp(Vector3.ONE, delta * 5.0)
	else:
		scale = Vector3.ONE

	# ── Gravité / flottement ─────────────────────────────────
	if float_amplitude > 0.0:
		# Vol : cible = pieds joueur + float_hover (hauteur caméra) + oscillation + ajustement obstacle
		_base_y     = lerp(_base_y, _player.global_position.y + float_hover, delta * 2.0)
		float_phase += delta * float_freq
		var target_y := _base_y + sin(float_phase) * float_amplitude + _hover_adjust
		velocity.y   = (target_y - global_position.y) * 8.0
	else:
		if not is_on_floor():
			velocity.y -= GRAVITY * gravity_scale * delta

	# ── Déplacement ──────────────────────────────────────────
	var is_moving := false
	if dist > melee_range and dist < spawn_dist + 8.0:
		if float_amplitude > 0.0:
			# Vol direct : ignore le NavMesh
			var dir := (_player.global_position - global_position)
			dir.y = 0.0
			if dir.length_squared() > 0.001:
				dir = dir.normalized()
				velocity.x = dir.x * chase_speed
				velocity.z = dir.z * chase_speed
				look_at(Vector3(_player.global_position.x, global_position.y,
								_player.global_position.z), Vector3.UP)
				is_moving = true
		else:
			# NavMesh — avec fallback direct si le chemin est inutilisable
			nav_agent.target_position = _player.global_position
			var moved_via_nav := false
			if not nav_agent.is_navigation_finished():
				var next_pos := nav_agent.get_next_path_position()
				var dir := (next_pos - global_position)
				# Seuil 0.05 : si le prochain waypoint est trop proche, le NavMesh
				# ne donne pas de direction utile (mesh absent ou en cours de cuisson)
				if dir.length_squared() > 0.05:
					dir = dir.normalized()
					velocity.x = dir.x * chase_speed
					velocity.z = dir.z * chase_speed
					look_at(Vector3(next_pos.x, global_position.y, next_pos.z), Vector3.UP)
					is_moving = true
					moved_via_nav = true

			if not moved_via_nav:
				# Fallback : mouvement direct (NavMesh absent, en cours de cuisson ou bloqué)
				var dir := (_player.global_position - global_position)
				dir.y = 0.0
				if dir.length_squared() > 0.001:
					dir = dir.normalized()
					velocity.x = dir.x * chase_speed
					velocity.z = dir.z * chase_speed
					look_at(Vector3(_player.global_position.x, global_position.y,
									_player.global_position.z), Vector3.UP)
					is_moving = true
	else:
		velocity.x = move_toward(velocity.x, 0.0, chase_speed)
		velocity.z = move_toward(velocity.z, 0.0, chase_speed)

	move_and_slide()

	# ── Voidborn : évitement vertical d'obstacles (encadrement de porte, etc.) ──
	if float_amplitude > 0.0:
		var wall_hit := false
		for i in get_slide_collision_count():
			var n := get_slide_collision(i).get_normal()
			if absf(n.y) < 0.4:   # normale horizontale = mur / encadrement
				wall_hit = true
				break
		if wall_hit:
			# Descend pour passer sous l'obstacle
			_hover_adjust = move_toward(_hover_adjust, -2.5, delta * 5.0)
		else:
			# Remonte progressivement à la hauteur normale
			_hover_adjust = move_toward(_hover_adjust, 0.0, delta * 1.5)

	_check_stuck(delta)
	_update_animation(is_moving)

	# ── Son de déplacement (pas, claquements…) ───────────────
	if is_moving:
		_move_timer -= delta
		if _move_timer <= 0.0:
			_play_snd(snd_move)
			_move_timer = snd_move_interval
	else:
		_move_timer = 0.0   # réinitialise pour que le premier pas soit immédiat

	# ── Corps-à-corps ────────────────────────────────────────
	_melee_cooldown -= delta
	if dist <= melee_range and _melee_cooldown <= 0.0:
		demon_hit_player.emit(melee_damage)
		_melee_cooldown = 1.0
		_play_snd(snd_attack, true)
		if anim_attack != "":
			_play_anim(anim_attack)
			_attacking = true

# ── Anti-coincement ───────────────────────────────────────────
func _check_stuck(delta: float) -> void:
	var cur_xz := Vector2(global_position.x, global_position.z)
	var moved   := cur_xz.distance_to(_prev_xz)
	_prev_xz    = cur_xz

	var xz_vel := Vector2(velocity.x, velocity.z).length()
	if xz_vel > 0.5 and moved < 0.003:
		_stuck_timer += delta
		if _stuck_timer > 0.4:
			# Distinguer décor / mur parmi les collisions actives
			var decor_normals: Array[Vector3] = []
			var wall_normals:  Array[Vector3] = []

			for i in get_slide_collision_count():
				var col := get_slide_collision(i)
				var n   := col.get_normal()
				if abs(n.y) >= 0.7:
					continue   # sol/plafond : ignorer
				if _is_decor(col.get_collider()):
					decor_normals.append(n)
				else:
					wall_normals.append(n)

			if wall_normals.size() > 0:
				# Mur : petit push pour se dégager
				global_position += wall_normals[0] * 0.12
				velocity = velocity.slide(wall_normals[0])
			elif decor_normals.size() > 0:
				# Décor uniquement : vider la vélocité horizontale,
				# le NavMesh recalculera un chemin de contournement
				velocity.x = 0.0
				velocity.z = 0.0
			else:
				velocity.x = 0.0
				velocity.z = 0.0

			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0

# Remonte jusqu'à 4 niveaux pour détecter le groupe "decor"
func _is_decor(node: Node) -> bool:
	var n := node
	for _i in 4:
		if n == null: return false
		if n.is_in_group("decor"): return true
		n = n.get_parent()
	return false

# ── Animations ────────────────────────────────────────────────
func _update_animation(moving: bool) -> void:
	if _attacking: return
	_play_anim(anim_walk if moving else anim_idle)

func _play_anim(anim: String) -> void:
	if anim_player == null or anim == "": return
	if not anim_player.has_animation(anim): return
	if _current_anim == anim: return
	_current_anim = anim
	anim_player.play(anim, 0.2)
	anim_player.speed_scale = anim_speed_scale

func _on_anim_finished(anim_name: String) -> void:
	if anim_name == anim_attack:
		_attacking    = false
		_current_anim = ""

# ── Dégâts ────────────────────────────────────────────────────
func take_damage(amount: float) -> void:
	if dead: return
	_play_snd(snd_hit, true)
	hp -= amount
	hp  = maxf(hp, 0.0)
	if hp <= 0.0:
		_die()

func _die() -> void:
	dead     = true
	active   = false
	visible  = false
	velocity = Vector3.ZERO
	# Coupure immédiate et totale — aucun son ne persiste après la mort
	if _audio:
		_audio.stop()
	# Désactiver le collider pour ne pas bloquer les tirs/déplacements
	if _col_shape:
		_col_shape.disabled = true
	respawn_timer = 10.0
	demon_died.emit(self)

	# ── Cadavre statique ─────────────────────────────────────
	var _dm := get_node_or_null("/root/DebrisManager")
	if _dm:
		# Calculer la position sol ici (CharacterBody3D a accès direct au monde physique)
		var corpse_pos := global_position
		if float_amplitude > 0.0:
			# Démon volant : raycast vers le bas pour trouver le vrai sol
			var space  := get_world_3d().direct_space_state
			var params := PhysicsRayQueryParameters3D.create(
				global_position,
				global_position + Vector3(0.0, -30.0, 0.0)
			)
			params.exclude = [get_rid()]
			var hit := space.intersect_ray(params)
			if hit:
				corpse_pos.y = hit["position"].y
		_corpse = _dm.spawn_corpse(
			get_tree().current_scene,
			corpse_pos,
			debris_color,
			debris_fire_color,
			debris_meshes
		)

func _respawn() -> void:
	# Supprimer le cadavre de la mort précédente
	if is_instance_valid(_corpse):
		_corpse.queue_free()
	_corpse = null

	hp              = hp_max
	dead            = false
	active          = false
	visible         = false
	_current_anim   = ""
	_attacking      = false
	velocity        = Vector3.ZERO
	global_position = _spawn_position
	float_phase     = randf() * TAU
	# Réactiver le collider au respawn
	if _col_shape:
		_col_shape.disabled = false

func get_hp_ratio() -> float:
	return hp / hp_max
