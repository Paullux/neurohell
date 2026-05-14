extends Node

# ============================================================
#  SonyaCinematic
#  Apparition de Sonya sur fond blanc entre deux niveaux.
#  Flow : fade_in (0.5s) → parle + lip sync → fade_out (0.5s)
#  Émet cinematic_finished quand terminé.
#
#  Usage (depuis portal_disc.gd) :
#    var cin = SonyaCinematic.new()
#    add_child(cin)
#    cin.cinematic_finished.connect(_after_cinematic)
#    cin.play(1)   # 1 = transition level1→2, 2 = level2→3, 3 = level3→win
# ============================================================

signal cinematic_finished

const SONYA_SCENE := "res://assets/characters/sonya/sonya_cinematic.glb"
const AUDIO_BASE  := "res://assets/audio/sonya/"
const JSON_BASE   := "res://assets/audio/sonya/"

# Durée des transitions
const FADE_IN_DURATION   := 0.3   # fondu initial rapide (juste avant l'approche)
const FADE_OUT_DURATION  := 0.01
const APPROACH_DURATION  := 3.5   # Sonya marche depuis le fond vers la caméra
const LIPSYNC_LOOKAHEAD  := 0.12  # avance de 120 ms pour compenser le délai visuel

# Mapping Rhubarb letter → nom du morph target Godot
const RHUBARB_MAP := {
	"X": "viseme_sil",
	"A": "viseme_PP",
	"B": "viseme_DD",
	"C": "viseme_kk",
	"D": "viseme_SS",
	"E": "viseme_CH",
	"F": "viseme_FF",
	"G": "viseme_I",
	"H": "viseme_AA",
}

# Données de niveau
const LEVEL_DATA := {
	1: {
		"audio": "level1_to_2.ogg",
		"json":  "level1_to_2.json",
		"subtitle": "Continue...\nL'enfer te regarde avancer.\nChaque pas te rapproche d'elle.\nDu purgatoire.\nContinue.",
	},
	2: {
		"audio": "level2_to_3.ogg",
		"json":  "level2_to_3.json",
		"subtitle": "Tu résistes mieux que je ne le pensais.\nCe qui t'attend...\nc'est plus qu'un purgatoire.\nC'est une réponse.",
	},
	3: {
		"audio": "level3_to_win.ogg",
		"json":  "level3_to_win.json",
		"subtitle": "Tu l'as traversé.\nTout ça... pour elle.\nAvance.\nElle est là.",
	},
}

# ── Nœuds ──────────────────────────────────────────────────────
var _canvas_layer:  CanvasLayer        = null
var _viewport_cont: SubViewportContainer = null
var _viewport:      SubViewport        = null
var _sonya_inst:    Node3D             = null
var _mesh_inst:     MeshInstance3D     = null
var _audio:         AudioStreamPlayer  = null
var _subtitle_lbl:  Label              = null
var _fade_rect:     ColorRect          = null   # overlay noir pour fade
var _anim_player:   AnimationPlayer    = null   # référence gardée pour le blend Walk→Idle
var _approach_pivot: Node3D           = null   # pivot déplacé par le tween (isole le root motion)

# ── Lip sync ───────────────────────────────────────────────────
var _mouth_cues:    Array              = []
var _cue_index:     int                = 0
var _morphs:        Dictionary         = {}     # nom → index dans MeshInstance3D
var _active_morph:  String             = ""
var _playing:       bool               = false
var _audio_started: bool               = false
var _is_approaching: bool              = false   # vrai pendant la phase d'approche


# ────────────────────────────────────────────────────────────────
func play(level_id: int) -> void:
	var data: Dictionary = LEVEL_DATA.get(level_id, {})
	if data.is_empty():
		push_error("SonyaCinematic: level_id invalide : " + str(level_id))
		cinematic_finished.emit()
		return

	_build_scene()
	_load_audio(AUDIO_BASE + data["audio"])
	_load_lipsync(JSON_BASE + data["json"])
	_set_subtitle(data["subtitle"])
	_play_approach()


# ────────────────────────────────────────────────────────────────
func _build_scene() -> void:
	# ── CanvasLayer par-dessus tout ───────────────────────────
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 101
	get_tree().root.add_child(_canvas_layer)

	# (pas de fond supplémentaire : le blanc vient du WorldEnvironment du SubViewport)

	# ── SubViewport monde isolé (own_world_3d = true OBLIGATOIRE)
	#    Sans ça, le SubViewport voit le monde du jeu (sky, décors, etc.)
	_viewport_cont = SubViewportContainer.new()
	_viewport_cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport_cont.stretch = true
	_viewport_cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_layer.add_child(_viewport_cont)

	_viewport = SubViewport.new()
	_viewport.own_world_3d    = true   # ← ISOLATION : monde 3D dédié
	_viewport.transparent_bg  = false  # fond opaque blanc géré par WorldEnvironment
	_viewport.size = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width",  1920),
		ProjectSettings.get_setting("display/window/size/viewport_height", 1080)
	)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_cont.add_child(_viewport)

	# ── Environnement — fond blanc pur, ambiance froide (effet G-Man) ──
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode  = Environment.BG_COLOR
	env.background_color = Color(1.0, 1.0, 1.0, 1.0)   # blanc pur
	# Ambient froid/bleuté — donne le côté surréel
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.82, 0.88, 1.0)
	env.ambient_light_energy = 0.9
	# Légère brume pour l'effet de profondeur (Sonya sort du blanc)
	env.fog_enabled       = true
	env.fog_density       = 0.15   # brume dense — Sonya invisible au fond
	env.fog_light_color   = Color(1.0, 1.0, 1.0)
	env.fog_aerial_perspective = 0.35
	world_env.environment = env
	_viewport.add_child(world_env)

	# ── Éclairage dramatique style G-Man ──────────────────────
	# Key light : légèrement dessus-devant, légèrement décalé à gauche
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 20, 0)
	key.light_color      = Color(1.0, 0.97, 0.90)
	key.light_energy     = 1.8
	key.shadow_enabled   = true
	_viewport.add_child(key)
	# Fill light doux par le bas (évite les zones totalement noires)
	var fill := OmniLight3D.new()
	fill.position        = Vector3(0.6, 0.3, 1.5)
	fill.light_color     = Color(0.75, 0.82, 1.0)
	fill.light_energy    = 0.6
	fill.omni_range      = 6.0
	_viewport.add_child(fill)

	# ── Caméra — corps entier, légèrement décentrée (style G-Man) ──
	# Sonya ~1.75m (pieds à Y=0, tête à Y≈1.75)
	# Caméra à hauteur hanche, recule à Z=4 pour voir les pieds jusqu'à la tête
	var cam := Camera3D.new()
	cam.position         = Vector3(0.15, 0.78, 4.0)  # reculée, légèrement à droite
	cam.rotation_degrees = Vector3(2.0, -2.0, 0.0)   # très légère contre-plongée
	cam.fov              = 52.0                        # FOV plus large = plein corps confortable
	_viewport.add_child(cam)

	# ── Sonya GLB ──────────────────────────────────────────────
	if ResourceLoader.exists(SONYA_SCENE):
		var packed: PackedScene = load(SONYA_SCENE)
		_sonya_inst = packed.instantiate() as Node3D
		_sonya_inst.position      = Vector3(0.0, 0.0, 0.0)   # toujours à 0 local
		_sonya_inst.rotation_degrees = Vector3(0, 0, 0)
		_sonya_inst.scale         = Vector3(1, 1, 1)

		# Le PIVOT est ce qui recule dans la brume et avance vers la caméra.
		# _sonya_inst reste à Z=0 local → le root motion Walk reste confiné au pivot.
		_approach_pivot = Node3D.new()
		_approach_pivot.position = Vector3(0.0, 0.0, -5.0)
		_viewport.add_child(_approach_pivot)
		_approach_pivot.add_child(_sonya_inst)

		# Trouver le MeshInstance3D et construire la map morph
		_mesh_inst = _find_mesh(_sonya_inst)
		if _mesh_inst:
			_build_morph_map()

		# Animation Walk pour l'approche
		# La position que l'animation essaie d'appliquer sera écrasée chaque frame dans _process()
		_anim_player = _sonya_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if _anim_player:
			if _anim_player.has_animation("Walk"):
				_anim_player.play("Walk")
			elif _anim_player.get_animation_list().size() > 0:
				_anim_player.play(_anim_player.get_animation_list()[0])
	else:
		push_error("SonyaCinematic: GLB introuvable : " + SONYA_SCENE)

	# ── Audio ──────────────────────────────────────────────────
	_audio = AudioStreamPlayer.new()
	_audio.finished.connect(_on_audio_finished)
	_canvas_layer.add_child(_audio)

	# ── Sous-titres ────────────────────────────────────────────
	_subtitle_lbl = Label.new()
	_subtitle_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle_lbl.offset_top    = -200.0
	_subtitle_lbl.offset_bottom = -30.0
	_subtitle_lbl.offset_left   = 80.0
	_subtitle_lbl.offset_right  = -80.0
	_subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
	_subtitle_lbl.autowrap_mode  = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_lbl.modulate       = Color(1, 1, 1, 0)
	_subtitle_lbl.add_theme_font_size_override("font_size", 20)
	_subtitle_lbl.add_theme_color_override("font_color",        Color(1.0, 1.0, 1.0, 1.0))
	_subtitle_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	_subtitle_lbl.add_theme_constant_override("shadow_offset_x", 2)
	_subtitle_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_subtitle_lbl.add_theme_constant_override("shadow_outline_size", 4)
	_canvas_layer.add_child(_subtitle_lbl)

	# SubViewportContainer commence transparent (CanvasItem → modulate OK)
	if _viewport_cont:
		_viewport_cont.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh(child)
		if found:
			return found
	return null


func _build_morph_map() -> void:
	if _mesh_inst == null:
		return
	var mesh: Mesh = _mesh_inst.mesh
	if mesh == null:
		return
	_morphs.clear()
	for i in range(mesh.get_blend_shape_count()):
		var bname: String = mesh.get_blend_shape_name(i)
		_morphs[bname] = i

	# Pré-calculer les index pour le mapping Rhubarb → index
	print("SonyaCinematic: ", _morphs.size(), " morph targets trouvés")


# ────────────────────────────────────────────────────────────────
func _load_audio(path: String) -> void:
	if ResourceLoader.exists(path):
		_audio.stream = load(path)
	else:
		push_error("SonyaCinematic: audio introuvable : " + path)


func _load_lipsync(path: String) -> void:
	_mouth_cues = []
	_cue_index  = 0
	if not FileAccess.file_exists(path):
		push_error("SonyaCinematic: JSON lipsync introuvable : " + path)
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary and parsed.has("mouthCues"):
		_mouth_cues = parsed["mouthCues"]


func _set_subtitle(text: String) -> void:
	if _subtitle_lbl:
		_subtitle_lbl.text = text


# ── Approche : Sonya surgit de la brume ──────────────────────
func _play_approach() -> void:
	_is_approaching = true
	var tw := get_tree().create_tween()
	# 1) Faire apparaître le viewport rapidement (fond blanc + brume déjà là)
	tw.tween_method(_set_viewport_alpha, 0.0, 1.0, FADE_IN_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# 2) Le PIVOT avance de Z=-5 à Z=0 — _sonya_inst ne bouge pas en local
	if _approach_pivot:
		tw.parallel().tween_property(_approach_pivot, "position",
			Vector3(0.0, 0.0, 0.0), APPROACH_DURATION) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_anim_player.speed_scale = 0.85
		_anim_player.play("Walk")
	# 3) Sous-titres apparaissent à mi-chemin (~1.5s dans l'approche)
	tw.parallel().tween_property(_subtitle_lbl, "modulate",
		Color(1, 1, 1, 1), APPROACH_DURATION * 0.5) \
		.set_delay(APPROACH_DURATION * 0.5)
	# (la détection d'arrivée se fait dans _process)


func _set_viewport_alpha(a: float) -> void:
	if _viewport_cont:
		_viewport_cont.modulate = Color(1, 1, 1, a)



func _start_audio() -> void:
	_playing = true
	_audio_started = true
	if _audio.stream:
		_audio.play()
	else:
		# Pas d'audio → attendre 2s puis terminer
		get_tree().create_timer(2.0).timeout.connect(_begin_fade_out)


func _on_audio_finished() -> void:
	_playing = false
	# Pause d'une seconde après la fin des dialogues
	get_tree().create_timer(0.8).timeout.connect(_begin_fade_out)


func _begin_fade_out() -> void:
	var tw := get_tree().create_tween()
	tw.tween_method(_set_viewport_alpha, 1.0, 0.0, FADE_OUT_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(_subtitle_lbl, "modulate",
		Color(1, 1, 1, 0), FADE_OUT_DURATION)
	tw.tween_callback(_cleanup)


func _cleanup() -> void:
	_reset_morphs()
	if _canvas_layer:
		_canvas_layer.queue_free()
	cinematic_finished.emit()


# ── Boucle principale ────────────────────────────────────────
func _process(_delta: float) -> void:

	# ── Phase d'approche ─────────────────────────────────────
	# Tant que le pivot n'est pas arrivé à l'origine → Walk + verrou position
	# Dès qu'il est en position → Idle + lancement audio
	if _is_approaching:
		# Pivot arrivé à destination → Idle + audio
		if _approach_pivot and _approach_pivot.position.length() < 0.01:
			_is_approaching = false
			if _anim_player and _anim_player.has_animation("Idle"):
				_anim_player.play("Idle", 0.08)
			_start_audio()
		return   # pas de lip sync pendant l'approche

	if not _playing or not _audio_started:
		return
	if _mouth_cues.is_empty() or _mesh_inst == null:
		return

	var t: float = _audio.get_playback_position() + LIPSYNC_LOOKAHEAD

	# Avancer dans les cues
	while _cue_index + 1 < _mouth_cues.size() \
		  and _mouth_cues[_cue_index + 1]["start"] <= t:
		_cue_index += 1

	if _cue_index >= _mouth_cues.size():
		return

	var cue: Dictionary = _mouth_cues[_cue_index]
	var rhubarb_letter: String = cue.get("value", "X")
	var morph_name: String = RHUBARB_MAP.get(rhubarb_letter, "viseme_sil")

	if morph_name == _active_morph:
		return

	# Transition douce : atténuer l'ancien, activer le nouveau
	_reset_morphs()
	_active_morph = morph_name
	if morph_name in _morphs:
		_mesh_inst.set_blend_shape_value(_morphs[morph_name], 1.0)


func _reset_morphs() -> void:
	if _mesh_inst == null:
		return
	for idx in _morphs.values():
		_mesh_inst.set_blend_shape_value(idx, 0.0)
	_active_morph = ""
