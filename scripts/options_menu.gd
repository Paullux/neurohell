extends CanvasLayer

# ============================================================
#  OptionsMenu  —  UI complète construite en code
#  Ouverture  : OptionsMenu.open()   (depuis main menu ou pause)
#  Fermeture  : Echap ou bouton Fermer
# ============================================================

signal closed

const TAB_DISPLAY  := 0
const TAB_SOUND    := 1
const TAB_CONTROLS := 2

# ── Refs UI ──────────────────────────────────────────────────
var _root:         Control        = null
var _tab_btns:     Array[Button]  = []
var _pages:        Array[Control] = []
var _active_tab:   int            = 0

# Page Affichage
var _res_option:   OptionButton   = null
var _ratio_option: OptionButton   = null
var _fs_check:     CheckBox       = null

# Page Son
var _music_check:   CheckBox = null
var _music_slider:  HSlider  = null
var _sfx_check:     CheckBox = null
var _sfx_slider:    HSlider  = null
var _voice_check:   CheckBox = null
var _voice_slider:  HSlider  = null
var _demons_check:  CheckBox = null
var _demons_slider: HSlider  = null

# Page Contrôles
var _sens_slider:    HSlider         = null
var _bind_buttons:   Dictionary      = {}   # action -> Button
var _rebinding:      String          = ""   # action en cours de rebind
var _gamepad_label:  Label           = null


# ────────────────────────────────────────────────────────────
func _ready() -> void:
	layer = 200   # au-dessus de tout
	# PROCESS_MODE_ALWAYS : le menu reste interactif même quand le jeu est pausé
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func open(pause_game: bool = false) -> void:
	_refresh_all()
	visible = true
	if pause_game:
		get_tree().paused = true


func _close() -> void:
	get_tree().paused = false
	visible = false
	closed.emit()


# ════════════════════════════════════════════════════════════
#  Construction de l'interface
# ════════════════════════════════════════════════════════════
func _build_ui() -> void:
	# Fond semi-transparent
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.04, 0.88)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Panneau centré
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = Vector2(780, 560)
	_root.offset_left   = -390
	_root.offset_top    = -280
	_root.offset_right  =  390
	_root.offset_bottom =  280
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color      = Color(0.06, 0.06, 0.10, 0.97)
	panel_style.border_color  = Color(0.6, 0.0, 0.0, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	_root.add_theme_stylebox_override("panel", panel_style)
	add_child(_root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	_root.add_child(vbox)

	# ── En-tête ─────────────────────────────────────────────
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	var title := Label.new()
	title.text = "  OPTIONS"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.44, 0.44))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := _make_button("✕", 28)
	close_btn.pressed.connect(_close)
	close_btn.custom_minimum_size = Vector2(40, 40)
	header.add_child(close_btn)
	var header_bg := StyleBoxFlat.new()
	header_bg.bg_color = Color(0.1, 0.0, 0.0, 0.8)
	header_bg.set_corner_radius_all(6)
	vbox.add_child(header)

	# ── Onglets ──────────────────────────────────────────────
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_top",     6)
	margin.add_theme_constant_override("margin_bottom",  0)
	margin.add_child(tab_bar)
	vbox.add_child(margin)

	for i: int in range(3):
		var lbl: String = ["AFFICHAGE", "SON", "CONTRÔLES"][i]
		var btn := _make_button(lbl, 14)
		btn.custom_minimum_size = Vector2(120, 32)
		btn.pressed.connect(_switch_tab.bind(i))
		tab_bar.add_child(btn)
		_tab_btns.append(btn)

	# Séparateur
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.4, 0.0, 0.0, 0.6))
	vbox.add_child(sep)

	# ── Zone de contenu scrollable ───────────────────────────
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var pages_container := Control.new()
	pages_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages_container.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.add_child(pages_container)

	_pages.append(_build_display_page())
	_pages.append(_build_sound_page())
	_pages.append(_build_controls_page())
	for p: Control in _pages:
		pages_container.add_child(p)
		p.set_anchors_preset(Control.PRESET_FULL_RECT)

	_switch_tab(0)


# ── Page Affichage ───────────────────────────────────────────
func _build_display_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	var m := _page_margin(page)

	_section(page, "RÉSOLUTION")
	_res_option = OptionButton.new()
	_res_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_resolutions()
	page.add_child(_res_option)
	_res_option.item_selected.connect(func(idx: int) -> void:
		var res: Vector2i = _res_option.get_item_metadata(idx)
		GameOptions.resolution = res
	)

	_section(page, "RAPPORT D'AFFICHAGE")
	_ratio_option = OptionButton.new()
	_ratio_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for pair: Array in [["Auto (natif)", "auto"], ["16:9", "16:9"], ["21:9", "21:9"], ["32:9", "32:9"]]:
		_ratio_option.add_item(pair[0])
		_ratio_option.set_item_metadata(_ratio_option.get_item_count() - 1, pair[1])
	page.add_child(_ratio_option)
	_ratio_option.item_selected.connect(func(idx: int) -> void:
		GameOptions.aspect_ratio = _ratio_option.get_item_metadata(idx)
	)
	page.add_child(_note("[color=#888888]En 21:9 / 32:9, les cinématiques affichent des bandes noires (format 16:9 préservé).[/color]"))

	_section(page, "PLEIN ÉCRAN")
	_fs_check = _make_checkbox("Activer le plein écran")
	_fs_check.toggled.connect(func(on: bool) -> void: GameOptions.fullscreen = on)
	page.add_child(_fs_check)

	_section(page, "")
	page.add_child(_apply_btn())

	return m


# ── Page Son ────────────────────────────────────────────────
func _build_sound_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	var m := _page_margin(page)

	_section(page, "MUSIQUE")
	_music_check = _make_checkbox("Activer la musique")
	_music_check.toggled.connect(func(on: bool) -> void: GameOptions.music_on = on; GameOptions._apply_audio())
	page.add_child(_music_check)
	page.add_child(_make_slider("Volume musique", func(v: float) -> void:
		GameOptions.music_vol = v / 100.0; GameOptions._apply_audio()
	))

	_section(page, "BRUITAGE")
	_sfx_check = _make_checkbox("Activer les bruitages")
	_sfx_check.toggled.connect(func(on: bool) -> void: GameOptions.sfx_on = on; GameOptions._apply_audio())
	page.add_child(_sfx_check)
	page.add_child(_make_slider("Volume bruitage", func(v: float) -> void:
		GameOptions.sfx_vol = v / 100.0; GameOptions._apply_audio()
	))

	_section(page, "VOIX")
	_voice_check = _make_checkbox("Activer les voix (Sonya…)")
	_voice_check.toggled.connect(func(on: bool) -> void: GameOptions.voice_on = on; GameOptions._apply_audio())
	page.add_child(_voice_check)
	page.add_child(_make_slider("Volume voix", func(v: float) -> void:
		GameOptions.voice_vol = v / 100.0; GameOptions._apply_audio()
	))

	_section(page, "BRUITS DÉMONS")
	_demons_check = _make_checkbox("Activer les bruits de démons")
	_demons_check.toggled.connect(func(on: bool) -> void: GameOptions.demons_on = on; GameOptions._apply_audio())
	page.add_child(_demons_check)
	page.add_child(_make_slider("Volume bruits démons", func(v: float) -> void:
		GameOptions.demons_vol = v / 100.0; GameOptions._apply_audio()
	))

	_section(page, "")
	page.add_child(_apply_btn())

	return m


# ── Page Contrôles ───────────────────────────────────────────
func _build_controls_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	var m := _page_margin(page)

	_section(page, "SENSIBILITÉ SOURIS")
	var sens_row := HBoxContainer.new()
	var sens_lbl := Label.new()
	sens_lbl.text = "Sensibilité"
	sens_lbl.custom_minimum_size = Vector2(180, 0)
	sens_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	sens_row.add_child(sens_lbl)
	_sens_slider = HSlider.new()
	_sens_slider.min_value  = 0.05
	_sens_slider.max_value  = 1.0
	_sens_slider.step       = 0.01
	_sens_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sens_slider.value_changed.connect(func(v: float) -> void: GameOptions.mouse_sensitivity = v * 0.004)
	sens_row.add_child(_sens_slider)
	page.add_child(sens_row)

	_section(page, "TOUCHES")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	page.add_child(grid)

	for action: String in GameOptions.REBINDABLE.keys():
		var label_txt: String = GameOptions.REBINDABLE[action]
		var row_lbl := Label.new()
		row_lbl.text = label_txt
		row_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		row_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(row_lbl)

		var bind_btn := _make_button(GameOptions.current_binding_label(action), 13)
		bind_btn.custom_minimum_size = Vector2(160, 28)
		bind_btn.pressed.connect(_start_rebind.bind(action))
		grid.add_child(bind_btn)
		_bind_buttons[action] = bind_btn

	page.add_child(_note("[color=#888888]Cliquez sur une touche pour la modifier, puis appuyez sur la nouvelle touche.[/color]"))

	_section(page, "MANETTES")
	_gamepad_label = Label.new()
	_gamepad_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_gamepad_label.add_theme_font_size_override("font_size", 13)
	page.add_child(_gamepad_label)

	_section(page, "")
	page.add_child(_apply_btn())

	return m


# ════════════════════════════════════════════════════════════
#  Rafraîchissement des valeurs
# ════════════════════════════════════════════════════════════
func _refresh_all() -> void:
	_refresh_display()
	_refresh_sound()
	_refresh_controls()


func _refresh_display() -> void:
	if _res_option == null:
		return
	_populate_resolutions()
	# Sélectionner la résolution courante
	for i: int in range(_res_option.get_item_count()):
		var r: Vector2i = _res_option.get_item_metadata(i)
		if r == GameOptions.resolution:
			_res_option.select(i)
			break
	# Ratio
	for i: int in range(_ratio_option.get_item_count()):
		if _ratio_option.get_item_metadata(i) == GameOptions.aspect_ratio:
			_ratio_option.select(i)
			break
	_fs_check.button_pressed = GameOptions.fullscreen


func _refresh_sound() -> void:
	if _music_check == null:
		return
	_music_check.button_pressed    = GameOptions.music_on
	_music_slider.value             = GameOptions.music_vol * 100.0
	_sfx_check.button_pressed      = GameOptions.sfx_on
	_sfx_slider.value               = GameOptions.sfx_vol * 100.0
	_voice_check.button_pressed    = GameOptions.voice_on
	_voice_slider.value             = GameOptions.voice_vol * 100.0
	_demons_check.button_pressed   = GameOptions.demons_on
	_demons_slider.value            = GameOptions.demons_vol * 100.0


func _refresh_controls() -> void:
	if _sens_slider == null:
		return
	_sens_slider.value = GameOptions.mouse_sensitivity / 0.004
	for action: String in _bind_buttons.keys():
		(_bind_buttons[action] as Button).text = GameOptions.current_binding_label(action)
	# Manettes
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		_gamepad_label.text = "Aucune manette détectée"
	else:
		var names := PackedStringArray()
		for id: int in pads:
			names.append(Input.get_joy_name(id))
		_gamepad_label.text = "Connectée(s) : " + ", ".join(names)


func _populate_resolutions() -> void:
	_res_option.clear()
	var resolutions := GameOptions.get_available_resolutions()
	for r: Vector2i in resolutions:
		var ratio := _ratio_name(r)
		_res_option.add_item("%d × %d  (%s)" % [r.x, r.y, ratio])
		_res_option.set_item_metadata(_res_option.get_item_count() - 1, r)


func _ratio_name(r: Vector2i) -> String:
	var f := float(r.x) / float(r.y)
	if   f < 1.5:  return "4:3"
	elif f < 1.7:  return "16:10"
	elif f < 1.85: return "16:9"
	elif f < 2.1:  return "18:9"
	elif f < 2.5:  return "21:9"
	else:          return "32:9"


# ════════════════════════════════════════════════════════════
#  Onglets
# ════════════════════════════════════════════════════════════
func _switch_tab(idx: int) -> void:
	_active_tab = idx
	for i: int in range(_pages.size()):
		_pages[i].visible = (i == idx)
	# Style des boutons d'onglet
	var s_active := StyleBoxFlat.new()
	s_active.bg_color    = Color(0.47, 0.0, 0.0, 0.9)
	s_active.border_color = Color(1.0, 0.44, 0.44, 0.8)
	s_active.set_border_width_all(1)
	s_active.set_corner_radius_all(6)
	var s_normal := StyleBoxFlat.new()
	s_normal.bg_color    = Color(1, 1, 1, 0.04)
	s_normal.border_color = Color(1, 1, 1, 0.08)
	s_normal.set_border_width_all(1)
	s_normal.set_corner_radius_all(6)
	for i: int in range(_tab_btns.size()):
		var s := s_active if i == idx else s_normal
		_tab_btns[i].add_theme_stylebox_override("normal",  s)
		_tab_btns[i].add_theme_stylebox_override("hover",   s)
		_tab_btns[i].add_theme_stylebox_override("pressed", s)
	if idx == TAB_CONTROLS:
		_refresh_controls()


# ════════════════════════════════════════════════════════════
#  Rebind de touches
# ════════════════════════════════════════════════════════════
func _start_rebind(action: String) -> void:
	if _rebinding != "":
		return
	_rebinding = action
	(_bind_buttons[action] as Button).text = "Appuyez sur une touche…"


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Annuler rebind avec Echap
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		if _rebinding != "":
			(_bind_buttons[_rebinding] as Button).text = GameOptions.current_binding_label(_rebinding)
			_rebinding = ""
			get_viewport().set_input_as_handled()
			return
		_close()
		get_viewport().set_input_as_handled()
		return

	if _rebinding == "":
		return

	# Accepter key, mouse button ou gamepad button — pas la molette de scroll (navigation)
	var valid := false
	if event is InputEventKey and event.pressed and not event.echo:
		valid = true
	elif event is InputEventMouseButton and event.pressed:
		var btn := (event as InputEventMouseButton).button_index
		valid = btn not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
							MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]
	elif event is InputEventJoypadButton and event.pressed:
		valid = true

	if valid:
		InputMap.action_erase_events(_rebinding)
		InputMap.action_add_event(_rebinding, event)
		(_bind_buttons[_rebinding] as Button).text = GameOptions.event_label(event)
		_rebinding = ""
		get_viewport().set_input_as_handled()


# ════════════════════════════════════════════════════════════
#  Bouton Appliquer & Sauvegarder
# ════════════════════════════════════════════════════════════
func _apply_btn() -> Button:
	var btn := _make_button("✔  Appliquer et sauvegarder", 14)
	btn.custom_minimum_size = Vector2(240, 36)
	btn.pressed.connect(func() -> void:
		GameOptions.apply_all()
		GameOptions.save_options()
	)
	return btn


# ════════════════════════════════════════════════════════════
#  Helpers de construction UI
# ════════════════════════════════════════════════════════════
func _page_margin(child: Control) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left",   20)
	m.add_theme_constant_override("margin_right",  20)
	m.add_theme_constant_override("margin_top",    16)
	m.add_theme_constant_override("margin_bottom", 16)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	m.add_child(child)
	return m


func _section(parent: Control, title: String) -> void:
	if title == "":
		return
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.44, 0.44, 0.9))
	parent.add_child(lbl)
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.4, 0.0, 0.0, 0.4))
	parent.add_child(sep)


func _make_button(lbl: String, font_size: int = 14) -> Button:
	var btn := Button.new()
	btn.text = lbl
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	var s := StyleBoxFlat.new()
	s.bg_color    = Color(1, 1, 1, 0.04)
	s.border_color = Color(1, 1, 1, 0.1)
	s.set_border_width_all(1)
	s.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("hover",   _hover_style())
	btn.add_theme_stylebox_override("pressed", _hover_style())
	return btn


func _hover_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color    = Color(0.4, 0.0, 0.0, 0.7)
	s.border_color = Color(1.0, 0.44, 0.44, 0.6)
	s.set_border_width_all(1)
	s.set_corner_radius_all(5)
	return s


func _make_checkbox(lbl: String) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = lbl
	cb.add_theme_color_override("font_color",          Color(0.9, 0.9, 0.9))
	cb.add_theme_color_override("font_pressed_color",  Color(1.0, 0.44, 0.44))
	cb.add_theme_font_size_override("font_size", 14)
	return cb


func _make_slider(label_text: String, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(180, 0)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value  = 0.0
	slider.max_value  = 100.0
	slider.step       = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	# Stocker dans la variable membre selon le label
	match label_text:
		"Volume musique":        _music_slider  = slider
		"Volume bruitage":       _sfx_slider    = slider
		"Volume voix":           _voice_slider  = slider
		"Volume bruits démons":  _demons_slider = slider
	return row


func _note(bbcode: String) -> RichTextLabel:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.text = bbcode
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.add_theme_font_size_override("normal_font_size", 12)
	return lbl
