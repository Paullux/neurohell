extends Node

# ============================================================
#  NeuroHell — Debris Manager (autoload)
# ============================================================
#  Inscription : Project > Paramètres du projet > Autoload
#  Chemin : res://scripts/debris_manager.gd   Nom : DebrisManager
# ============================================================

## Nombre maximum de cadavres simultanés dans toute la scène.
const MAX_CORPSES := 50

## Durée en secondes avant que le feu s'éteigne.
const FIRE_DURATION := 6.0

var _pool: Array = []

# ── API publique ──────────────────────────────────────────────────────────────

## Spawne UN cadavre statique à `world_pos`.
## Retourne le nœud créé (pour pouvoir le supprimer au respawn du démon).
func spawn_corpse(parent:     Node3D,
				  world_pos:  Vector3,
				  color:      Color = Color(0.28, 0.04, 0.04),
				  fire_color: Color = Color(1.0, 0.95, 0.3),
				  meshes:     Array = []) -> Node3D:

	# La position sol est calculée côté démon avant l'appel — on place directement
	var corpse := _make_corpse(color, fire_color, meshes)
	parent.add_child(corpse)
	corpse.global_position = world_pos + Vector3(0.0, 0.05, 0.0)

	_pool.append(corpse)
	_enforce_cap()
	return corpse

# ── Interne ───────────────────────────────────────────────────────────────────

func _enforce_cap() -> void:
	_pool = _pool.filter(func(n): return is_instance_valid(n))
	while _pool.size() > MAX_CORPSES:
		var oldest = _pool.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

func _make_corpse(color: Color, fire_color: Color, meshes: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask  = 0

	# ── Mesh : un seul, choisi aléatoirement ────────────────────────────────
	var mi := MeshInstance3D.new()
	if meshes.size() > 0:
		mi.mesh = meshes[randi() % meshes.size()]
	else:
		# Placeholder : capsule couchée
		var m       := CapsuleMesh.new()
		m.radius     = 0.25
		m.height     = 0.80
		var mat     := StandardMaterial3D.new()
		mat.albedo_color = color.darkened(randf_range(0.0, 0.3))
		mat.roughness    = 0.95
		m.surface_set_material(0, mat)
		mi.mesh = m

	body.add_child(mi)

	# Rotation : uniquement Y pour varier la direction — X/Z à 0 pour tester
	# si les modèles Rodin sont déjà exportés à plat
	body.rotation_degrees = Vector3(
		0.0,
		randf_range(0.0, 360.0),
		0.0
	)

	# ── Collider plat ────────────────────────────────────────────────────────
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.2, 0.4)
	col.shape = box
	body.add_child(col)

	# ── Feu (GPUParticles3D) ─────────────────────────────────────────────────
	var fire          := GPUParticles3D.new()
	fire.name          = "Fire"
	fire.amount        = 20
	fire.lifetime      = 1.0
	fire.explosiveness = 0.0
	fire.randomness    = 0.5
	fire.one_shot      = false
	fire.emitting      = true
	fire.position      = Vector3(0.0, 0.25, 0.0)   # au-dessus du corps allongé

	var pm                     := ParticleProcessMaterial.new()
	pm.emission_shape           = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents     = Vector3(0.4, 0.05, 0.25)  # étalé sur la longueur du corps
	pm.direction                = Vector3(0.0, 1.0, 0.0)
	pm.spread                   = 30.0
	pm.initial_velocity_min     = 0.3
	pm.initial_velocity_max     = 0.8
	pm.gravity                  = Vector3(0.0, 0.15, 0.0)
	pm.damping_min              = 0.5
	pm.damping_max              = 1.5
	pm.scale_min                = 0.08
	pm.scale_max                = 0.20

	var c0 := fire_color.lightened(0.25)
	var c1 := fire_color
	var c2 := Color(fire_color.r * 0.6, fire_color.g * 0.2,
					fire_color.b * 0.6, 0.6)
	var c3 := Color(fire_color.r * 0.1, fire_color.g * 0.0,
					fire_color.b * 0.1, 0.0)
	var grad := Gradient.new()
	grad.set_color(0, c0)
	grad.add_point(0.25, c1)
	grad.add_point(0.6,  c2)
	grad.add_point(1.0,  c3)
	var grad_tex      := GradientTexture1D.new()
	grad_tex.gradient  = grad
	pm.color_ramp      = grad_tex

	fire.process_material = pm

	var flame_tex := load("res://assets/images/particules/flam.png") as Texture2D
	var flame_mat              := StandardMaterial3D.new()
	flame_mat.shading_mode      = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.billboard_mode    = BaseMaterial3D.BILLBOARD_ENABLED
	flame_mat.blend_mode        = BaseMaterial3D.BLEND_MODE_ADD   # fond blanc → invisible sur surfaces sombres
	flame_mat.vertex_color_use_as_albedo = true
	flame_mat.cull_mode         = BaseMaterial3D.CULL_DISABLED
	if flame_tex:
		flame_mat.albedo_texture = flame_tex

	var quad          := QuadMesh.new()
	quad.size          = Vector2(0.18, 0.28)   # proportion flammèche (plus haute que large)
	quad.surface_set_material(0, flame_mat)
	fire.draw_pass_1   = quad

	body.add_child(fire)

	# ── Son de feu (AudioStreamPlayer3D) ────────────────────────────────────
	var fire_snd := AudioStreamPlayer3D.new()
	var stream   := load("res://assets/audio/sound_fx/fire_sound.ogg") as AudioStream
	if stream:
		fire_snd.stream            = stream
		fire_snd.autoplay          = true
		fire_snd.max_distance      = 8.0
		fire_snd.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		fire_snd.volume_db         = -6.0
		body.add_child(fire_snd)

	# Éteindre le feu ET le son après FIRE_DURATION secondes
	get_tree().create_timer(FIRE_DURATION).timeout.connect(func():
		if is_instance_valid(fire):     fire.emitting = false
		if is_instance_valid(fire_snd): fire_snd.stop()
	)

	return body
