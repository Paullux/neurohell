extends Node

# ============================================================
#  NeuroHell — Plasma System
#  Pool de projectiles, équivalent PlasmaSystem.js
# ============================================================

const BOLT_SCENE := preload("res://scenes/plasma_bolt.tscn")

signal bolt_hit(damage: float, position: Vector3)

func fire(muzzle_pos: Vector3, direction: Vector3, damage: float, color: Color, wpn_id: String = "plasma_standard") -> void:
	var bolt: Area3D = BOLT_SCENE.instantiate()
	bolt.direction    = direction.normalized()
	bolt.damage       = damage
	bolt.plasma_color = color
	bolt.weapon_id    = wpn_id
	bolt.global_position = muzzle_pos
	bolt.collision_layer = 0
	bolt.collision_mask = 1 | 8

	bolt.look_at(muzzle_pos + direction.normalized(), Vector3.UP)

	if wpn_id == "teal_sniper":
		bolt.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))

	get_tree().current_scene.add_child(bolt)

func update(_delta: float) -> void:
	pass  # Les bolts se gèrent eux-mêmes via _physics_process
