extends Area3D

# ============================================================
#  NeuroHell — Plasma Bolt
#  Charge les FX particules selon l'arme active
# ============================================================

const FX_SCENES := {
	"irongazlet":     "res://scenes/fx/plasma_irongazlet.tscn",
	"plasma_standard":"res://scenes/fx/plasma_standard.tscn",
	"plasma_elite":   "res://scenes/fx/plasma_elite.tscn",
	"teal_sniper":    "res://scenes/fx/plasma_tealsniper.tscn",
	"void_rifle":     "res://scenes/fx/plasma_voidrifle.tscn",
}

@export var speed: float       = 60.0
@export var damage: float      = 18.0
@export var lifetime: float    = 3.0
@export var weapon_id: String  = "plasma_standard"

var direction: Vector3  = Vector3.FORWARD
var plasma_color: Color = Color(1.0, 0.4, 0.0)

@onready var mesh_inst: MeshInstance3D = $MeshInstance3D

var _alive_time: float = 0.0
var _hit := false
var _fx_node: Node3D = null

func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_mask = 1 | 8
	collision_layer = 0

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	_spawn_fx()
	_apply_color()
	_apply_color_to_fx(self)

func _on_area_entered(area: Area3D) -> void:
	_handle_hit(area)

func _spawn_fx() -> void:
	var path: String = FX_SCENES.get(weapon_id, FX_SCENES["plasma_standard"])
	var scene := load(path) as PackedScene
	if scene == null: return
	_fx_node = scene.instantiate()
	add_child(_fx_node)

func _apply_color() -> void:
	if mesh_inst == null: return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = plasma_color
	mat.emission_enabled = true
	mat.emission = plasma_color
	mat.emission_energy_multiplier = 6.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.set_surface_override_material(0, mat)

	# Si le Teal Sniper ressemble à une saucisse verticale,
	# on couche seulement le visuel du mesh.
	if weapon_id == "teal_sniper":
		mesh_inst.rotation_degrees.x = 90.0

	# Lumière du bolt
	for child in get_children():
		if child is OmniLight3D:
			child.light_color = plasma_color
			child.light_energy = 2.5
			child.omni_range = 3.0

func _apply_color_to_fx(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = plasma_color
			mat.emission_enabled = true
			mat.emission = plasma_color
			mat.emission_energy_multiplier = 5.0
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			child.set_surface_override_material(0, mat)

		if child is GPUParticles3D:
			var draw_mat := StandardMaterial3D.new()
			draw_mat.albedo_color = plasma_color
			draw_mat.emission_enabled = true
			draw_mat.emission = plasma_color
			draw_mat.emission_energy_multiplier = 5.0
			draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

			if child.draw_pass_1:
				child.draw_pass_1.material = draw_mat

		_apply_color_to_fx(child)

func _physics_process(delta: float) -> void:
	if _hit: return
	_alive_time += delta
	if _alive_time >= lifetime:
		queue_free()
		return
	global_position += direction * speed * delta

func _on_body_entered(body: Node3D) -> void:
	_handle_hit(body)
	if _hit: return
	_hit = true

	if body.is_in_group("demon"):
		body.take_damage(damage)

	# Burst impact
	if _fx_node and _fx_node.has_method("restart"):
		_fx_node.one_shot = true
		_fx_node.restart()

	if mesh_inst: mesh_inst.visible = false

	# Lumière flash
	for child in get_children():
		if child is OmniLight3D:
			var tw := create_tween()
			tw.tween_property(child, "light_energy", 0.0, 0.12)

	await get_tree().create_timer(0.5).timeout
	queue_free()

func _handle_hit(target: Node) -> void:
	if _hit:
		return

	_hit = true

	var damaged := false

	if target.is_in_group("demon_hitbox"):
		var demon := target.get_parent()
		if demon and demon.has_method("take_damage"):
			demon.take_damage(damage)
			damaged = true

	elif target.is_in_group("demon") and target.has_method("take_damage"):
		target.take_damage(damage)
		damaged = true

	elif target.has_method("take_damage"):
		target.take_damage(damage)
		damaged = true

	# Burst impact
	if _fx_node and _fx_node.has_method("restart"):
		_fx_node.one_shot = true
		_fx_node.restart()

	if mesh_inst:
		mesh_inst.visible = false

	for child in get_children():
		if child is OmniLight3D:
			var tw: Tween = create_tween()
			tw.tween_property(child, "light_energy", 0.0, 0.12)

	await get_tree().create_timer(0.5).timeout
	queue_free()
