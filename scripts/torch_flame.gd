extends Node
class_name TorchFlame

# ============================================================
#  NeuroHell — Torch Flame
#  Attache automatiquement des particules de flamme bleue
#  et une OmniLight3D vacillante sur tous les DECOR_SRC_Torch_*
#  Appelé depuis les scripts de niveau dans _ready()
# ============================================================

const LIGHT_ENERGY_BASE  := 2.5
const LIGHT_ENERGY_RANGE := 0.6   # amplitude du vacillement
const LIGHT_RANGE        := 4.0
const FLICKER_SPEED      := 8.0   # Hz approximatif

var _torches: Array = []          # [{light, phase}]
var _time: float = 0.0

static func attach_to_scene(scene_root: Node) -> Node:
	var inst := TorchFlame.new()
	scene_root.add_child(inst)
	inst._scan(scene_root)
	return inst

func _scan(root: Node) -> void:
	_scan_recursive(root)
	print("TorchFlame : ", _torches.size(), " torche(s) trouvée(s)")

func _scan_recursive(node: Node) -> void:
	if node is MeshInstance3D and node.name.begins_with("DECOR_SRC_Torch_"):
		_setup_torch(node as MeshInstance3D)
	for child in node.get_children():
		_scan_recursive(child)

func _setup_torch(mesh: MeshInstance3D) -> void:
	# ── Particules flamme bleue ───────────────────────────────
	var particles := GPUParticles3D.new()
	particles.name         = "FlameParticles"
	particles.amount       = 48
	particles.lifetime     = 1.0
	particles.emitting     = true
	particles.local_coords = false
	# Positionne les particules au sommet du mesh (bol de torche)
	var aabb   := mesh.get_aabb()
	var top_y  := aabb.position.y + aabb.size.y       # sommet du mesh
	var center_x := aabb.position.x + aabb.size.x * 0.5
	var center_z := aabb.position.z + aabb.size.z * 0.5
	particles.position = Vector3(center_x, top_y - aabb.size.y * 0.1 - 0.05, center_z)

	var mat := ParticleProcessMaterial.new()
	mat.direction              = Vector3(0, 1, 0)
	mat.spread                 = 18.0
	mat.initial_velocity_min   = 0.4
	mat.initial_velocity_max   = 0.9
	mat.gravity                = Vector3(0, 0.15, 0)
	mat.scale_min              = 0.12
	mat.scale_max              = 0.22
	mat.turbulence_enabled     = true
	mat.turbulence_noise_strength = 0.6
	mat.turbulence_noise_scale    = 1.5
	mat.turbulence_noise_speed    = Vector3(0.8, 0.8, 0.8)

	# Gradient bleu cyan → blanc → transparent
	var grad := Gradient.new()
	grad.set_color(0, Color(0.0, 0.5,  1.0,  1.0))
	grad.add_point(0.35, Color(0.0, 0.85, 1.0, 0.85))
	grad.add_point(0.65, Color(0.5, 0.95, 1.0, 0.5))
	grad.add_point(1.0,  Color(1.0, 1.0,  1.0, 0.0))
	var grad_tex      := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp    = grad_tex

	# Texture circulaire douce (dégradé radial blanc → transparent)
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var dx := (x - 15.5) / 15.5
			var dy := (y - 15.5) / 15.5
			var d  := sqrt(dx * dx + dy * dy)
			var a  : float = clamp(1.0 - d, 0.0, 1.0)
			a = a * a  # falloff doux
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	var circle_tex := ImageTexture.create_from_image(img)

	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	particles.draw_pass_1 = quad

	var sprite_mat := StandardMaterial3D.new()
	sprite_mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	sprite_mat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	sprite_mat.billboard_mode             = BaseMaterial3D.BILLBOARD_ENABLED
	sprite_mat.vertex_color_use_as_albedo = true
	sprite_mat.albedo_texture             = circle_tex
	sprite_mat.emission_enabled           = true
	sprite_mat.emission                   = Color(0.0, 0.6, 1.0)
	sprite_mat.emission_energy_multiplier = 2.5
	quad.surface_set_material(0, sprite_mat)

	particles.process_material = mat
	mesh.add_child(particles)

	# ── Lumière vacillante bleue ──────────────────────────────
	var light              := OmniLight3D.new()
	light.name             = "TorchLight"
	light.light_color      = Color(0.15, 0.55, 1.0)
	light.light_energy     = LIGHT_ENERGY_BASE
	light.omni_range       = LIGHT_RANGE
	light.shadow_enabled   = false
	light.position         = Vector3(0, 0.2, 0)
	mesh.add_child(light)

	_torches.append({
		"light": light,
		"phase": randf() * TAU    # phase aléatoire → flammes désynchronisées
	})

func _process(delta: float) -> void:
	_time += delta
	for t in _torches:
		var light: OmniLight3D = t["light"]
		if not is_instance_valid(light):
			continue
		var noise := sin(_time * FLICKER_SPEED + t["phase"]) \
				   + sin(_time * FLICKER_SPEED * 1.7 + t["phase"] * 0.5) * 0.4
		light.light_energy = LIGHT_ENERGY_BASE + noise * LIGHT_ENERGY_RANGE * 0.5
