extends Area3D

# ============================================================
#  NeuroHell — Collectible
#  Créé dynamiquement dans les scripts de niveau.
#  Types : HEALTH | ARMOR | AMMO
# ============================================================

enum Type { HEALTH, ARMOR, AMMO }

@export var type:  Type  = Type.HEALTH
@export var value: float = 25.0

const COLORS := {
	Type.HEALTH: Color(0.0, 1.0, 0.3,  1.0),   # vert
	Type.ARMOR:  Color(0.0, 0.9, 1.0,  1.0),   # cyan
	Type.AMMO:   Color(1.0, 0.7, 0.0,  1.0),   # orange
}
const LABELS := {
	Type.HEALTH: "+VIE",
	Type.ARMOR:  "+ARMURE",
	Type.AMMO:   "+MUNITIONS",
}

var _collected := false
var _bob_phase := 0.0
var _origin_y  := 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask  = 1
	_origin_y = global_position.y

	# Sphère visuelle
	var mesh_inst := MeshInstance3D.new()
	var sphere    := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	mesh_inst.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color    = COLORS[type]
	mat.emission_enabled = true
	mat.emission        = COLORS[type] * 1.8
	mat.transparency    = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	# Collider
	var col   := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.6
	col.shape = shape
	add_child(col)

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _collected: return
	_bob_phase += delta * 2.0
	position.y = _origin_y + sin(_bob_phase) * 0.12
	rotate_y(delta * 1.8)

func _on_body_entered(body: Node3D) -> void:
	if _collected: return
	if not body.is_in_group("player"): return
	_collected = true

	match type:
		Type.HEALTH:
			if body.has_method("heal"):
				body.heal(value)
			elif "health" in body:
				body.health = minf(body.health + value, 100.0)
				if body.has_signal("health_changed"):
					body.health_changed.emit(body.health)
		Type.ARMOR:
			if "armor" in body:
				body.armor = minf(body.armor + value, 100.0)
				if body.has_signal("armor_changed"):
					body.armor_changed.emit(body.armor)
		Type.AMMO:
			var wm := body.find_child("WeaponManager", true, false)
			if wm and wm.has_method("add_ammo"):
				wm.add_ammo(int(value))

	# Flash HUD
	var hud := get_tree().current_scene.find_child("HUD", true, false)
	if hud and hud.has_method("show_narration"):
		hud.show_narration(LABELS[type])

	# Disparaître
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.25).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
