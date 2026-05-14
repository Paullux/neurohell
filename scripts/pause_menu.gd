extends CanvasLayer

# ============================================================
#  NeuroHell — Pause Menu (instancié dynamiquement par les niveaux)
#  Appuyer sur Échap en jeu → ouvre ce menu, pause le jeu.
#  RESUME    → reprend
#  SAUVEGARDER → appelle SaveManager, affiche confirmation
#  OPTIONS   → ouvre options_menu.gd (layer 200) par-dessus
#  QUITTER   → retour au menu principal
# ============================================================

signal closed

# ── Références fournies par le niveau ─────────────────────────
var player:      CharacterBody3D = null  # injecté par le script de niveau
var level_scene: String          = ""   # "res://scenes/level_X.tscn"

# ── État interne ──────────────────────────────────────────────
var _is_open:       bool  = false
var _options_open:  bool  = false   # true tant que options_menu est ouvert par-dessus
var _save_status:   Label = null

# ── Style bouton ──────────────────────────────────────────────
var _btn_style_normal:  StyleBoxFlat = null
var _btn_style_hover:   StyleBoxFlat = null
var _btn_style_pressed: StyleBoxFlat = null


# ════════════════════════════════════════════════════════════
#  Init
# ════════════════════════════════════════════════════════════
func _ready() -> void:
	layer        = 199           # sous options_menu (layer 200), au-dessus du HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_styles()
	_build_ui()
	visible = false


# ════════════════════════════════════════════════════════════
#  Entrée clavier — Échap
# ════════════════════════════════════════════════════════════
func _unhandled_input(event: InputEvent) -> void:
	# Bloquer pendant que options_menu est ouvert par-dessus :
	# c'est options_menu._input qui gère Échap dans ce cas-là.
	if _options_open:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if _is_open:
		_close()
	else:
		_open()
	get_viewport().set_input_as_handled()


# ════════════════════════════════════════════════════════════
#  Ouverture / fermeture
# ════════════════════════════════════════════════════════════
func _open() -> void:
	if _is_open:
		return
	_is_open = true
	visible  = true
	if _save_status:
		_save_status.visible = false
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible  = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	closed.emit()


# ════════════════════════════════════════════════════════════
#  Construction de l'interface
# ════════════════════════════════════════════════════════════
func _build_styles() -> void:
	_btn_style_normal = StyleBoxFlat.new()
	_btn_style_normal.bg_color     = Color(0.12, 0.04, 0.12, 0.85)
	_btn_style_normal.border_color = Color(0.6, 0.0, 0.0, 0.5)
	_btn_style_normal.set_border_width_all(1)
	_btn_style_normal.set_corner_radius_all(6)

	_btn_style_hover = StyleBoxFlat.new()
	_btn_style_hover.bg_color     = Color(0.40, 0.04, 0.04, 0.95)
	_btn_style_hover.border_color = Color(1.0, 0.3, 0.3, 0.8)
	_btn_style_hover.set_border_width_all(1)
	_btn_style_hover.set_corner_radius_all(6)

	_btn_style_pressed = StyleBoxFlat.new()
	_btn_style_pressed.bg_color     = Color(0.6, 0.05, 0.05, 0.95)
	_btn_style_pressed.border_color = Color(1.0, 0.5, 0.5, 1.0)
	_btn_style_pressed.set_border_width_all(2)
	_btn_style_pressed.set_corner_radius_all(6)


func _build_ui() -> void:
	# ── Fond semi-transparent ────────────────────────────────
	var bg := ColorRect.new()
	bg.color        = Color(0.0, 0.0, 0.0, 0.60)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ── Panneau centré ───────────────────────────────────────
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color     = Color(0.04, 0.01, 0.04, 0.96)
	panel_style.border_color = Color(0.75, 0.0, 0.0, 0.75)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# ── Titre ────────────────────────────────────────────────
	var title := Label.new()
	title.text                  = "PAUSE"
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0))
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	vbox.add_child(sep)

	# ── Boutons ──────────────────────────────────────────────
	_make_btn(vbox, "▶  REPRENDRE",      _on_resume)
	_make_btn(vbox, "💾  SAUVEGARDER",   _on_save)
	_make_btn(vbox, "⚙  OPTIONS",        _on_options)
	_make_btn(vbox, "✖  QUITTER",        _on_quit)

	# ── Statut sauvegarde ────────────────────────────────────
	_save_status = Label.new()
	_save_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_status.add_theme_font_size_override("font_size", 12)
	_save_status.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1.0))
	_save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_status.visible       = false
	vbox.add_child(_save_status)


func _make_btn(parent: VBoxContainer, label: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text                = label
	btn.custom_minimum_size = Vector2(0, 46)
	btn.alignment           = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color",         Color(0.92, 0.88, 0.88, 1.0))
	btn.add_theme_color_override("font_hover_color",   Color(1.0, 0.95, 0.95, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_stylebox_override("normal",  _btn_style_normal)
	btn.add_theme_stylebox_override("hover",   _btn_style_hover)
	btn.add_theme_stylebox_override("pressed", _btn_style_pressed)
	btn.add_theme_stylebox_override("focus",   _btn_style_normal)
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


# ════════════════════════════════════════════════════════════
#  Callbacks boutons
# ════════════════════════════════════════════════════════════
func _on_resume() -> void:
	_close()


func _on_save() -> void:
	if player == null:
		_show_status("Erreur : joueur introuvable.", false)
		return
	if level_scene == "":
		_show_status("Erreur : scène inconnue.", false)
		return

	var filename := SaveManager.save_game(player, level_scene)
	if filename == "":
		_show_status("Échec de la sauvegarde.", false)
	else:
		# Afficher un nom court (sans extension ni chemin) pour la confirmation
		var short := filename.get_basename().replace("save_", "")
		_show_status("✔  Sauvegardé : " + short, true)


func _on_options() -> void:
	# Cacher le menu pause pendant que les options sont ouvertes
	# (évite qu'il reste visible derrière et que Échap le ferme en même temps)
	_options_open = true
	visible = false

	var om: Node = load("res://scripts/options_menu.gd").new()
	get_tree().root.add_child(om)
	om.closed.connect(func() -> void:
		om.queue_free()
		_options_open = false
		visible = true                              # ré-afficher le menu pause
		get_tree().paused = true                    # s'assurer qu'on est encore pausé
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)  # restaurer le curseur
	)
	om.open(false)   # ne pas re-pauser — déjà pausé par ce menu


func _on_quit() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


# ════════════════════════════════════════════════════════════
#  Affichage du statut sauvegarde
# ════════════════════════════════════════════════════════════
func _show_status(msg: String, success: bool) -> void:
	if _save_status == null:
		return
	_save_status.text = msg
	var col := Color(0.4, 1.0, 0.4, 1.0) if success else Color(1.0, 0.4, 0.4, 1.0)
	_save_status.add_theme_color_override("font_color", col)
	_save_status.visible = true

	# Masquer automatiquement après 3 secondes (timer ignore la pause)
	var timer := get_tree().create_timer(3.5, false, false, true)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(_save_status):
			_save_status.visible = false
	)
