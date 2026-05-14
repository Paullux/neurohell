extends CharacterBody3D

# ============================================================
#  NeuroHell — Player FPS Controller
# ============================================================

signal health_changed(hp: float)
signal armor_changed(armor: float)
signal torch_changed(ratio: float, is_depleted: bool)
signal player_died

# --- Stats ---
@export var health: float = 100.0
@export var armor: float  = 100.0
const HP_MAX    := 100.0
const ARMOR_MAX := 100.0

# --- Mouvement ---
const SPEED_GROUND  := 25.0
const SPEED_AIR     := 8.0
const JUMP_VELOCITY := 10.0
const GRAVITY       := 30.0
const DAMPING_GROUND := 4.0
const DAMPING_AIR    := 0.4

# --- Caméra ---
@export var mouse_sensitivity: float = 0.002
var _pitch: float = 0.0
const PITCH_MAX := deg_to_rad(89.0)

# --- Invulnérabilité ---
var _invuln_timer: float = 0.0

# --- Regen séparée : armure rapide / vie lente ---
const ARMOR_REGEN_DELAY := 4.0    # secondes sans dégâts avant recharge armure
const ARMOR_REGEN_RATE  := 10.0   # points d'armure par seconde
const HP_REGEN_DELAY    := 15.0   # secondes sans dégâts avant regen vie
const HP_REGEN_RATE     := 0.5    # points de vie par seconde (très lent)
var _time_since_damage: float = 999.0  # démarre haut → regen immédiate au lancement

# --- Torche électrique ---
const TORCH_MAX      := 4.0   # secondes d'autonomie
const TORCH_RECHARGE := 5.0   # secondes pour recharger complètement

var _torch_on:       bool  = false
var _torch_charge:   float = TORCH_MAX
var _torch_depleted: bool  = false

var dead := false
var _spawn_position := Vector3(0, 2, 0)

# --- Camera bob ---
var _bob_t: float = 0.0

# --- Anti-coincement ---
var _stuck_timer: float = 0.0
var _prev_xz:     Vector2 = Vector2.ZERO

# --- Nodes ---
@onready var head: Node3D            = $Head
@onready var camera: Camera3D        = $Head/Camera3D
@onready var weapon_holder: Node3D   = $Head/Camera3D/WeaponHolder
@onready var weapon_manager: Node    = $Head/Camera3D/WeaponHolder/WeaponManager
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight

# ── entrée souris ──────────────────────────────────────────
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	collision_layer = 4
	collision_mask = 1
	add_to_group("player")
	# Appliquer la sensibilité depuis les options + écouter les changements
	mouse_sensitivity = GameOptions.mouse_sensitivity
	GameOptions.options_applied.connect(func() -> void:
		mouse_sensitivity = GameOptions.mouse_sensitivity
	)

func _input(event: InputEvent) -> void:
	if dead: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity, -PITCH_MAX, PITCH_MAX)
		head.rotation.x = _pitch

	# Échap (pause) est géré par pause_menu.gd via _unhandled_input


# ── physique ───────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if dead: return

	# Gravité
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Damping
	var damping := exp(-DAMPING_GROUND * delta) - 1.0
	if not is_on_floor():
		damping *= DAMPING_AIR / DAMPING_GROUND
	velocity.x += velocity.x * damping
	velocity.z += velocity.z * damping

	# Déplacement
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var speed_delta := delta * (SPEED_GROUND if is_on_floor() else SPEED_AIR)
		var fwd := _get_forward()
		var right := _get_right()
		if Input.is_action_pressed("move_forward"):  velocity += fwd   * speed_delta
		if Input.is_action_pressed("move_backward"): velocity -= fwd   * speed_delta
		if Input.is_action_pressed("move_left"):     velocity -= right  * speed_delta
		if Input.is_action_pressed("move_right"):    velocity += right  * speed_delta
		if is_on_floor() and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY

	move_and_slide()
	_check_stuck(delta)

	# Filet de sécurité : retéléporte si le joueur passe sous le sol
	if global_position.y < -5.0:
		global_position = _spawn_position
		velocity = Vector3.ZERO

	# Bob caméra
	_bob_t += delta
	var moving := velocity.length_squared() > 1.0
	camera.position.y = sin(_bob_t * (10.0 if moving else 2.0)) * 0.01

	# Regen passif
	_tick_regen(delta)
	if _invuln_timer > 0.0:
		_invuln_timer -= delta

	# Torche
	if Input.is_action_just_pressed("torch"):
		_toggle_torch()
	_process_torch(delta)

func _check_stuck(delta: float) -> void:
	var cur_xz := Vector2(global_position.x, global_position.z)
	var moved   := cur_xz.distance_to(_prev_xz)
	_prev_xz    = cur_xz

	# Coincé = on a de la vélocité horizontale mais on n'avance presque pas
	var xz_vel := Vector2(velocity.x, velocity.z).length()
	if xz_vel > 1.0 and moved < 0.003:
		_stuck_timer += delta
		if _stuck_timer > 0.35:
			# Pousser uniquement hors des MURS (pas des décors)
			var pushed := false
			for i in get_slide_collision_count():
				var col := get_slide_collision(i)
				var n   := col.get_normal()
				if abs(n.y) < 0.7:          # mur latéral uniquement
					if _is_decor(col.get_collider()):
						continue            # décor → pas de push, juste glisser
					global_position += n * 0.18
					velocity = velocity.slide(n)
					pushed = true
					break
			if not pushed:
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

func _get_forward() -> Vector3:
	var d := -camera.global_transform.basis.z
	d.y = 0
	return d.normalized()

func _get_right() -> Vector3:
	var d := camera.global_transform.basis.x
	d.y = 0
	return d.normalized()

# ── Torche électrique ─────────────────────────────────────
func _update_flashlight() -> void:
	if flashlight == null:
		return

	if not _torch_on or _torch_depleted:
		flashlight.visible = false
		return

	var ratio := clampf(_torch_charge / TORCH_MAX, 0.0, 1.0)
	var flicker := randf_range(0.97, 1.03)

	flashlight.visible = true

	# Torche large mais pas "plafonnier"
	flashlight.light_color = Color(1.0, 0.82, 0.48)
	flashlight.light_energy = lerp(5.0, 12.0, ratio) * flicker

	# Faisceau visible devant le joueur
	flashlight.spot_range = lerp(10.0, 26.0, ratio)

	# Large, mais pas trop
	flashlight.spot_angle = 42.0

	# Plus haut = bords plus sombres, centre plus marqué
	flashlight.spot_attenuation = 1.65

	flashlight.shadow_enabled = true

func _toggle_torch() -> void:
	if _torch_depleted:
		return

	_torch_on = not _torch_on
	_update_flashlight()
	torch_changed.emit(_torch_charge / TORCH_MAX, false)

func _process_torch(delta: float) -> void:
	if _torch_depleted:
		_torch_charge = minf(_torch_charge + delta * (TORCH_MAX / TORCH_RECHARGE), TORCH_MAX)
		torch_changed.emit(_torch_charge / TORCH_MAX, true)

		if _torch_charge >= TORCH_MAX:
			_torch_depleted = false

	elif _torch_on:
		_torch_charge -= delta
		torch_changed.emit(_torch_charge / TORCH_MAX, false)

		if _torch_charge <= 0.0:
			_torch_charge = 0.0
			_torch_on = false
			_torch_depleted = true
			torch_changed.emit(0.0, true)

	_update_flashlight()

# ── dégâts / regen ────────────────────────────────────────
func take_damage(amount: float) -> void:
	if dead or _invuln_timer > 0.0:
		return
	_invuln_timer = 1.0
	_time_since_damage = 0.0  # remet le délai de regen à zéro

	# L'armure absorbe 75 % des dégâts (se vide vite, recharge vite)
	if armor > 0.0:
		var blocked := minf(amount * 0.75, armor)
		armor -= blocked
		amount -= blocked
		armor_changed.emit(armor)

	health -= amount
	health = maxf(health, 0.0)
	health_changed.emit(health)

	if health <= 0.0:
		_die()

func _tick_regen(delta: float) -> void:
	if dead: return
	_time_since_damage += delta

	# Armure : recharge rapide après ARMOR_REGEN_DELAY secondes sans coup
	if _time_since_damage >= ARMOR_REGEN_DELAY and armor < ARMOR_MAX:
		armor = minf(ARMOR_MAX, armor + ARMOR_REGEN_RATE * delta)
		armor_changed.emit(armor)

	# Vie : regen très lente après HP_REGEN_DELAY secondes sans coup
	if _time_since_damage >= HP_REGEN_DELAY and health < HP_MAX:
		health = minf(HP_MAX, health + HP_REGEN_RATE * delta)
		health_changed.emit(health)

func _die() -> void:
	dead = true
	_torch_on = false
	if flashlight: flashlight.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player_died.emit()

# ── API publique pour les démons ──────────────────────────
func get_camera() -> Camera3D:
	return camera
