extends Control

@onready var button_play:        Button        = $RootMargin/Center/VBox/MainContent/MenuPanel/MenuVBox/ButtonPlay
@onready var button_story:       Button        = $RootMargin/Center/VBox/MainContent/MenuPanel/MenuVBox/ButtonStory
@onready var button_screenshots: Button        = $RootMargin/Center/VBox/MainContent/MenuPanel/MenuVBox/ButtonScreenshots
@onready var button_download:    Button        = $RootMargin/Center/VBox/MainContent/MenuPanel/MenuVBox/ButtonDownload
@onready var button_quit:        Button        = $RootMargin/Center/VBox/MainContent/MenuPanel/MenuVBox/ButtonQuit
@onready var content_label:      RichTextLabel = $RootMargin/Center/VBox/MainContent/ContentPanel/ContentLabel
@onready var intro_overlay:      ColorRect     = $IntroOverlay
@onready var intro_video:        VideoStreamPlayer = $IntroOverlay/IntroVideo

const LEVEL_1_SCENE   := "res://scenes/level_1.tscn"
const GITHUB_API      := "https://api.github.com/repos/Paullux/neurohell/releases/latest"

var _active_btn:      Button = null
var _btn_base_texts:  Dictionary = {}  # texte original de chaque bouton
var _latest_version:  String = ""      # rempli par le fetch GitHub
var _http:            HTTPRequest = null

# ── Grille captures ──────────────────────────────────────────
var _screenshot_scroll: ScrollContainer = null
var _screenshots_built: bool = false

# ── Style actif (rouge + crânes permanent) ───────────────────
var _style_active: StyleBoxFlat = null
var _style_normal: StyleBoxFlat = null

func _ready() -> void:
	intro_overlay.visible = false

	# Styles
	_style_active = StyleBoxFlat.new()
	_style_active.bg_color     = Color(0.47, 0.0, 0.0, 0.9)
	_style_active.border_color = Color(1.0, 0.44, 0.44, 0.8)
	_style_active.set_border_width_all(1)
	_style_active.set_corner_radius_all(10)

	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color     = Color(1, 1, 1, 0.04)
	_style_normal.border_color = Color(1, 1, 1, 0.08)
	_style_normal.set_border_width_all(1)
	_style_normal.set_corner_radius_all(10)

	# Connexions
	button_play.pressed.connect(_on_play_pressed)
	button_story.pressed.connect(func() -> void: _select(button_story); _show_story())
	button_screenshots.pressed.connect(func() -> void: _select(button_screenshots); _show_screenshots())
	button_download.pressed.connect(func() -> void: _select(button_download); _show_download())
	button_quit.pressed.connect(_on_quit_pressed)

	intro_video.finished.connect(_go_to_level_1)

	# Mémoriser textes originaux + setup hover
	for btn: Button in [button_play, button_story, button_screenshots, button_download, button_quit]:
		_btn_base_texts[btn] = btn.text
		_setup_skull_hover(btn)

	# Fetch version GitHub en arrière-plan
	_fetch_latest_version()

	# Sélection initiale
	_select(button_play)
	_show_home()


# ── Sélection active ─────────────────────────────────────────
func _select(btn: Button) -> void:
	# Désactiver l'ancien bouton actif
	if _active_btn != null and _active_btn != btn:
		_active_btn.text = _btn_base_texts[_active_btn]
		_active_btn.add_theme_stylebox_override("normal", _style_normal)
		_active_btn.add_theme_stylebox_override("hover",  _style_normal)

	_active_btn = btn
	var base: String = _btn_base_texts[btn]
	btn.text = "💀  " + base + "  💀"
	btn.add_theme_stylebox_override("normal",  _style_active)
	btn.add_theme_stylebox_override("hover",   _style_active)
	btn.add_theme_stylebox_override("pressed", _style_active)


# ── Effet crâne au survol (boutons non actifs) ───────────────
func _setup_skull_hover(btn: Button) -> void:
	btn.mouse_entered.connect(func() -> void:
		if _active_btn == btn:
			return
		btn.text = "💀  " + _btn_base_texts[btn] + "  💀"
	)
	btn.mouse_exited.connect(func() -> void:
		if _active_btn == btn:
			return
		btn.text = _btn_base_texts[btn]
	)


# ── Fetch version GitHub ─────────────────────────────────────
func _fetch_latest_version() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_version_fetched)
	_http.request(GITHUB_API, ["User-Agent: NeuroHell-Menu", "Accept: application/vnd.github+json"])

func _on_version_fetched(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http.queue_free()
	_http = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if json and json.has("tag_name"):
		_latest_version = json.get("tag_name", "")
		# Rafraîchir la section téléchargement si elle est visible
		if _active_btn == button_download:
			_show_download()


# ── Contenus ─────────────────────────────────────────────────
func _hide_screenshot_grid() -> void:
	if _screenshot_scroll:
		_screenshot_scroll.visible = false
	content_label.visible = true

func _show_home() -> void:
	_hide_screenshot_grid()
	content_label.text = """
[center][font_size=28][b]Entrée en enfer[/b][/font_size][/center]

[center]Lance l'intro cinématique, puis enchaîne directement sur le premier niveau.[/center]

[center][color=#ff7070]NeuroHell[/color] - prototype desktop Godot 4[/center]
"""


func _show_story() -> void:
	_hide_screenshot_grid()
	content_label.text = """
[font_size=24][b]Histoire du jeu[/b][/font_size]

NeuroHell est un univers de dark sci-fi horror où le temps s'est effondré.

Le passé, le présent et le futur coexistent dans une seule dimension infernale.

Des entités démoniaques anciennes côtoient les restes d'une technologie humaine avancée.

Ce n'est pas simplement l'enfer. C'est un système.

[b]Le but[/b]

Traverser l'enfer pour atteindre le purgatoire, sauver son âme, et peut-être retrouver celle qu'il aime.

[b]Tonalité[/b]

- dark sci-fi horror
- culpabilité
- mémoire fracturée
- métal gothique
- chair biomécanique
- combat brutal
"""


func _show_screenshots() -> void:
	content_label.visible = false
	if not _screenshots_built:
		_build_screenshot_grid()
	if _screenshot_scroll:
		_screenshot_scroll.visible = true

func _build_screenshot_grid() -> void:
	_screenshots_built = true

	# Lire screenshots.json
	const JSON_PATH := "res://assets/images/screenshots/screenshots.json"
	if not FileAccess.file_exists(JSON_PATH):
		return
	var f := FileAccess.open(JSON_PATH, FileAccess.READ)
	if f == null:
		return
	var list: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not list is Array or list.is_empty():
		return

	# ScrollContainer dans le même parent que content_label
	var panel := content_label.get_parent()
	_screenshot_scroll = ScrollContainer.new()
	_screenshot_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screenshot_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_screenshot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_screenshot_scroll)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 14)
	_screenshot_scroll.add_child(outer)

	# Titre
	var title := Label.new()
	title.text = "Captures d'écran"
	title.add_theme_font_override("font", $RootMargin/Center/VBox/MainContent/MenuPanel/MenuVBox/ButtonPlay.get_theme_font("font"))
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.44, 0.44, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)

	# Grille 3 colonnes
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	outer.add_child(grid)

	for item in list:
		var fname: String = item.get("file", "")
		var caption: String = item.get("caption", "")
		if fname == "":
			continue

		var tex: Texture2D = load("res://assets/images/screenshots/" + fname)
		if tex == null:
			continue

		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var tr := TextureRect.new()
		tr.texture      = tex
		tr.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.custom_minimum_size = Vector2(0, 90)
		tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(tr)

		var lbl := Label.new()
		lbl.text = caption
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72, 1.0))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell.add_child(lbl)

		grid.add_child(cell)


func _show_download() -> void:
	_hide_screenshot_grid()
	var current   := GameVersion.VERSION
	var build_date := GameVersion.BUILD_DATE
	var os_name   := OS.get_name()

	if not content_label.meta_clicked.is_connected(_on_link_clicked):
		content_label.meta_clicked.connect(_on_link_clicked)

	# ── Version de développement ─────────────────────────────
	if current == "dev":
		var update_notice := ""
		if _latest_version != "":
			update_notice = "\n[color=#ffcc00]⬆  Version [b]%s[/b] disponible sur [url=https://neurohell.com]neurohell.com[/url][/color]" % _latest_version
		content_label.text = """
[font_size=24][b]Télécharger[/b][/font_size]

[color=#aaaaaa]Vous utilisez une version de développement.[/color]%s

[b]🪟 Windows[/b]
[url=https://github.com/Paullux/neurohell/releases/latest]Voir les releases sur GitHub[/url]

[b]🐧 Linux[/b]
[url=https://github.com/Paullux/neurohell/releases/latest]Voir les releases sur GitHub[/url]

[color=#aaaaaa]GPU requis : Vulkan 1.0 ou OpenGL 3.3+[/color]
""" % update_notice
		return

	# ── Version officielle ────────────────────────────────────
	# Bannière mise à jour disponible
	var update_banner := ""
	if _latest_version != "" and _latest_version != current:
		update_banner = "\n[color=#ffcc00]⬆  Mise à jour disponible : [b]%s[/b]  →  [url=https://neurohell.com]neurohell.com[/url][/color]\n" % _latest_version
	elif _latest_version == current:
		update_banner = "\n[color=#00e5ff]✔  Vous avez la dernière version.[/color]\n"

	# Mise en évidence plateforme actuelle
	var win_label := "[b]🪟 Windows[/b]"
	var lin_label := "[b]🐧 Linux[/b]"
	if os_name == "Windows":
		win_label = "[color=#00e5ff][b]🪟 Windows  ◄ votre plateforme[/b][/color]"
	elif os_name == "Linux":
		lin_label = "[color=#00e5ff][b]🐧 Linux  ◄ votre plateforme[/b][/color]"

	content_label.text = """
[font_size=24][b]Télécharger[/b][/font_size]

[color=#00e5ff]Version installée : [b]%s[/b][/color]   ·   [color=#aaaaaa]build du %s[/color]   ·   [color=#aaaaaa]%s[/color]
%s
%s
[url=https://github.com/Paullux/neurohell/releases/download/%s/NeuroHell-Windows.zip]NeuroHell-Windows.zip[/url]

%s
[url=https://github.com/Paullux/neurohell/releases/download/%s/NeuroHell-Linux.zip]NeuroHell-Linux.zip[/url]

[color=#aaaaaa]GPU requis : Vulkan 1.0 ou OpenGL 3.3+[/color]
""" % [current, build_date, os_name, update_banner, win_label, current, lin_label, current]


# ── Actions ──────────────────────────────────────────────────
func _on_play_pressed() -> void:
	_select(button_play)
	intro_overlay.visible = true
	intro_video.play()

func _go_to_level_1() -> void:
	intro_overlay.visible = false
	var err := get_tree().change_scene_to_file(LEVEL_1_SCENE)
	if err != OK:
		push_error("Impossible de charger le niveau 1 : " + LEVEL_1_SCENE)

func _on_link_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))

func _on_quit_pressed() -> void:
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if intro_overlay.visible and event.is_action_pressed("ui_cancel"):
		intro_video.stop()
		_go_to_level_1()
