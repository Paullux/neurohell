extends Area3D

# ============================================================
#  NeuroHell — PortalDisc
#  Détection : distance XZ uniquement (plan horizontal)
#  Le nœud doit être placé AU MÊME endroit que le cylindre blanc.
#  Flow : approche → freeze joueur → blanc → stats → clic → scène
# ============================================================

## Scène suivante à charger
@export var next_scene: String = "res://scenes/level_2.tscn"

## Forcer un ID de cinématique Sonya (0 = auto-détecté depuis next_scene)
@export var sonya_level_id: int = 0

## Rayon de déclenchement dans le plan XZ (mètres)
@export var trigger_radius: float = 1.5

## Rayon d'avertissement ("SORTIE DÉTECTÉE")
@export var warning_radius: float = 6.0

## (optionnel) Nœud visuel qui tourne — s'il est assigné, il tourne et
##  sa position XZ est utilisée comme centre du portail à la place de self
@export var spin_node: NodePath = NodePath("")
@export var spin_speed: float   = 140.0

# ── état interne ──────────────────────────────────────────────
var _activated:      bool  = false
var _warning_shown:  bool  = false
var _waiting_input:  bool  = false
var _spin_target:    Node3D = null
var _portal_center:  Node3D = null   # nœud dont on prend la position XZ

func _ready() -> void:
	if spin_node != NodePath(""):
		_spin_target = get_node_or_null(spin_node)
	# Le centre du portail = le nœud visuel s'il existe, sinon self
	_portal_center = _spin_target if _spin_target != null else self

	# Cacher les meshes marqueurs du portail (blanc dans le GLB)
	_hide_portal_markers()

	# Vidéo sur le disque — optionnel : si les nœuds sont absents on ignore
	_setup_portal_video()


func _hide_portal_markers() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	_hide_markers_recursive(root)


func _hide_markers_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var n := node.name
		if n == "NH_MarkerPortal":
			# Disque blanc semi-transparent avec légère émission
			var mat := StandardMaterial3D.new()
			mat.albedo_color              = Color(1.0, 1.0, 1.0, 0.18)
			mat.transparency              = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.emission_enabled          = true
			mat.emission                  = Color(1.0, 1.0, 1.0, 1.0)
			mat.emission_energy_multiplier = 0.4
			mat.cull_mode                 = BaseMaterial3D.CULL_DISABLED
			(node as MeshInstance3D).material_override = mat
		elif n.begins_with("NH_Marker") or n.begins_with("MARKER_"):
			# Tous les autres marqueurs → invisibles
			(node as MeshInstance3D).visible = false
	for child in node.get_children():
		_hide_markers_recursive(child)


const _VIDEO_PATH := "res://assets/videos/Sonya_Portals.ogv"

func _setup_portal_video() -> void:
	if not ResourceLoader.exists(_VIDEO_PATH):
		push_warning("PortalDisc : vidéo introuvable → " + _VIDEO_PATH)
		return

	# ── SubViewport → VideoStreamPlayer → texture fiable ─────
	var sv: SubViewport = get_node_or_null("VideoViewport")
	if sv == null:
		sv                          = SubViewport.new()
		sv.name                     = "VideoViewport"
		sv.size                      = Vector2i(512, 512)
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		sv.transparent_bg            = true
		sv.use_hdr_2d                = false
		add_child(sv)

	var vp: VideoStreamPlayer = sv.get_node_or_null("VideoPlayer")
	if vp == null:
		vp             = VideoStreamPlayer.new()
		vp.name        = "VideoPlayer"
		vp.stream      = load(_VIDEO_PATH)
		vp.expand      = true
		vp.anchor_left = 0.0; vp.anchor_top    = 0.0
		vp.anchor_right = 1.0; vp.anchor_bottom = 1.0
		sv.add_child(vp)

	vp.play()
	vp.finished.connect(func() -> void: vp.play())

	# Laisser le SubViewport rendre au moins 3 frames
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var shader := load("res://shaders/portal_chroma.gdshader")
	var tex     := sv.get_texture()

	# ── Face avant (+5 cm sur Z) ──────────────────────────────
	var front: MeshInstance3D = get_node_or_null("DiscMesh")
	if front == null:
		front            = MeshInstance3D.new()
		front.name       = "DiscMesh"
		var q            := QuadMesh.new()
		q.size           = Vector2(1.6, 1.6)
		front.mesh       = q
		front.position.z = 0.05
		add_child(front)

	var mat_front := ShaderMaterial.new()
	mat_front.shader = shader
	mat_front.set_shader_parameter("video_tex", tex)
	mat_front.set_shader_parameter("flip_u", false)
	front.material_override = mat_front

	# ── Face arrière (-5 cm sur Z, retournée 180°) ─────────────
	var back: MeshInstance3D = get_node_or_null("DiscMeshBack")
	if back == null:
		back             = MeshInstance3D.new()
		back.name        = "DiscMeshBack"
		var q2           := QuadMesh.new()
		q2.size          = Vector2(1.6, 1.6)
		back.mesh        = q2
		back.position.z  = -0.05
		back.rotation.y  = deg_to_rad(180.0)
		add_child(back)

	var mat_back := ShaderMaterial.new()
	mat_back.shader = shader
	mat_back.set_shader_parameter("video_tex", tex)
	mat_back.set_shader_parameter("flip_u", true)
	back.material_override = mat_back

func _process(delta: float) -> void:
	if _activated:
		return

	# Rotation du cylindre
	if _spin_target:
		_spin_target.rotate_y(deg_to_rad(spin_speed) * delta)

	# ── Détection joueur (XZ uniquement) ──────────────────────
	var center_xz := Vector2(_portal_center.global_position.x,
							  _portal_center.global_position.z)

	for node in get_tree().get_nodes_in_group("player"):
		if not node is Node3D:
			continue
		var player := node as Node3D
		var p_xz   := Vector2(player.global_position.x, player.global_position.z)
		var dist   := center_xz.distance_to(p_xz)

		# Avertissement à distance
		if not _warning_shown and dist <= warning_radius:
			_warning_shown = true
			var hud := get_tree().current_scene.find_child("HUD", true, false)
			if hud and hud.has_method("show_narration"):
				hud.show_narration("SORTIE DÉTECTÉE — Approchez du portail")

		# Déclenchement
		if dist <= trigger_radius:
			_activate_portal(player)
			return

# ── Séquence de transition ────────────────────────────────────
func _activate_portal(player: Node3D) -> void:
	if _activated:
		return
	_activated = true

	# Sauvegarder vie & armure
	if "health" in player and "armor" in player:
		GameData.health    = player.health
		GameData.armor     = player.armor
		GameData.has_saved = true

	# Bloquer le joueur
	player.set_physics_process(false)
	player.set_process_input(false)

	# Flash blanc — CanvasLayer layer 99
	var cl := CanvasLayer.new()
	cl.layer = 99
	if next_scene.ends_with("game_win.tscn"):
		get_tree().current_scene.add_child(cl)
	else:
		get_tree().root.add_child(cl)

	var white := ColorRect.new()
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	white.color        = Color(1.0, 1.0, 1.0, 0.0)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(white)

	# Tween rattaché au SceneTree (indépendant du cycle de vie du nœud)
	var tw := get_tree().create_tween()
	tw.tween_property(white, "color:a", 1.0, 1.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_on_white_done)

func _get_sonya_id() -> int:
	# sonya_level_id > 0 dans l'inspecteur = forçage manuel
	if sonya_level_id > 0:
		return sonya_level_id
	# Auto-détection depuis next_scene
	if next_scene.ends_with("level_2.tscn"):
		return 1
	if next_scene.ends_with("level_3.tscn"):
		return 2
	if next_scene.ends_with("level_4.tscn"):
		return 3
	if next_scene.ends_with("game_win.tscn"):
		return 4
	return 0

func _on_white_done() -> void:
	var sid := _get_sonya_id()
	if sid > 0:
		var cin: Node = load("res://scripts/sonya_cinematic.gd").new()
		get_tree().root.add_child(cin)
		cin.cinematic_finished.connect(_on_cinematic_done)
		cin.play(sid)
		return
	# Chemin normal — inchangé
	var elapsed := (Time.get_ticks_msec() / 1000.0) - GameData.level_start_time
	var hud := get_tree().current_scene.find_child("HUD", true, false)
	if hud and hud.has_method("show_end_stats"):
		var is_final := next_scene.ends_with("game_win.tscn")
		hud.show_end_stats(GameData.kills, GameData.soul_points, elapsed, GameData.deaths, is_final)
	_waiting_input = true

func _on_cinematic_done() -> void:
	var elapsed := (Time.get_ticks_msec() / 1000.0) - GameData.level_start_time
	var hud := get_tree().current_scene.find_child("HUD", true, false)
	if hud and hud.has_method("show_end_stats"):
		var is_final := next_scene.ends_with("game_win.tscn")
		hud.show_end_stats(GameData.kills, GameData.soul_points, elapsed, GameData.deaths, is_final)
	_waiting_input = true

func _input(event: InputEvent) -> void:
	if not _waiting_input:
		return
	var valid: bool = (event is InputEventKey        and event.pressed) \
				  or (event is InputEventMouseButton and event.pressed)
	if valid:
		_waiting_input = false
		_change_scene_safe()

func _change_scene_safe() -> void:
	if next_scene == "":
		push_error("PORTAL ERROR: next_scene est vide")
		return
	if not ResourceLoader.exists(next_scene):
		push_error("PORTAL ERROR: scène introuvable : " + next_scene)
		return
	var err := get_tree().change_scene_to_file(next_scene)
	if err != OK:
		push_error("PORTAL ERROR: code erreur : " + str(err))
