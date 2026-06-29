extends Control

@onready var background:         TextureRect   = $Background
@onready var button_play:        Button        = $RootMargin/Center/VBox/MainContent/MenuPanel/MenuVBox/ButtonPlay
@onready var button_story:       Button        = $RootMargin/Center/VBox/MainContent/MenuPanel/MenuVBox/ButtonStory
@onready var button_screenshots: Button        = $RootMargin/Center/VBox/MainContent/MenuPanel/MenuVBox/ButtonScreenshots
@onready var button_download:    Button        = $RootMargin/Center/VBox/MainContent/MenuPanel/MenuVBox/ButtonDownload
@onready var button_options:     Button        = $RootMargin/Center/VBox/MainContent/MenuPanel/MenuVBox/ButtonOptions
@onready var button_restore:     Button        = $RootMargin/Center/VBox/MainContent/MenuPanel/MenuVBox/ButtonRestore
@onready var button_quit:        Button        = $RootMargin/Center/VBox/MainContent/MenuPanel/MenuVBox/ButtonQuit
@onready var content_label:      RichTextLabel = $RootMargin/Center/VBox/MainContent/ContentPanel/ContentLabel
@onready var intro_overlay:      ColorRect     = $IntroOverlay
@onready var intro_video:        VideoStreamPlayer = $IntroOverlay/IntroVideo

const LEVEL_1_SCENE   := "res://scenes/level_1.tscn"
# /releases (toutes) plutôt que /latest → une seule requête pour version + compteurs
const GITHUB_API      := "https://api.github.com/repos/Paullux/neurohell/releases"

const SPLASH_VIDEO_PATH := "res://assets/images/splashscreen/intro.ogv"

var _active_btn:      Button = null
var _btn_base_texts:  Dictionary = {}  # texte original de chaque bouton
var _latest_version:  String = ""      # rempli par le fetch GitHub
var _dl_windows:      int    = -1      # -1 = pas encore chargé
var _dl_linux:        int    = -1
var _http:            HTTPRequest = null


# ── Grille captures ──────────────────────────────────────────
var _screenshot_scroll: ScrollContainer = null
var _screenshots_built: bool = false

# ── Panneau restauration sauvegarde ──────────────────────────
var _restore_scroll: ScrollContainer = null

# ── Style actif (rouge + crânes permanent) ───────────────────
var _style_active: StyleBoxFlat = null
var _style_normal: StyleBoxFlat = null

var _splash_cover: TextureRect = null   # affiche intro.ogv en cover (sans bandes noires)

func _ready() -> void:
	intro_overlay.visible = false
	call_deferred("_fit_background")
	get_viewport().size_changed.connect(_fit_background)

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
	button_options.pressed.connect(_on_options_pressed)
	button_restore.pressed.connect(func() -> void: _select(button_restore); _show_restore())
	button_quit.pressed.connect(_on_quit_pressed)

	intro_video.finished.connect(_go_to_level_1)

	# Mémoriser textes originaux + setup hover
	for btn: Button in [button_play, button_story, button_screenshots, button_download, button_options, button_restore, button_quit]:
		_btn_base_texts[btn] = btn.text
		_setup_skull_hover(btn)

	# Fetch version GitHub en arrière-plan
	_fetch_latest_version()

	# Sélection initiale
	_select(button_play)
	_show_home()

	# Splash d'intro au lancement (intro.ogv) — joue avant que le menu soit accessible
	_play_launch_splash()


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


# ── Fetch releases GitHub (version + compteurs de téléchargement) ──
func _fetch_latest_version() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_releases_fetched)
	_http.request(GITHUB_API, ["User-Agent: NeuroHell-Menu", "Accept: application/vnd.github+json"])

func _on_releases_fetched(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http.queue_free()
	_http = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var releases: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not releases is Array or releases.is_empty():
		return

	# Première release = la plus récente
	var latest: Dictionary = releases[0]
	_latest_version = latest.get("tag_name", "")

	# Sommer les download_count par plateforme sur TOUTES les releases
	_dl_windows = 0
	_dl_linux   = 0
	for release: Variant in releases:
		if not release is Dictionary:
			continue
		var assets: Variant = release.get("assets", [])
		if not assets is Array:
			continue
		for asset: Variant in assets:
			if not asset is Dictionary:
				continue
			var name: String = asset.get("name", "").to_lower()
			var count: int   = asset.get("download_count", 0)
			if "windows" in name:
				_dl_windows += count
			elif "linux" in name:
				_dl_linux += count

	# Rafraîchir la section téléchargement si elle est visible
	if _active_btn == button_download:
		_show_download()


# ── Contenus ─────────────────────────────────────────────────
func _hide_screenshot_grid() -> void:
	if _screenshot_scroll:
		_screenshot_scroll.visible = false
	if _restore_scroll:
		_restore_scroll.visible = false
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


func _show_restore() -> void:
	_hide_screenshot_grid()
	if _restore_scroll:
		_restore_scroll.queue_free()
		_restore_scroll = null

	var saves := SaveManager.load_saves()
	var panel := content_label.get_parent()

	# Conteneur scrollable
	_restore_scroll = ScrollContainer.new()
	_restore_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_restore_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_restore_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_restore_scroll)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 10)
	_restore_scroll.add_child(outer)

	# Titre
	var title := Label.new()
	title.text = "Restaurer une sauvegarde"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.44, 0.44, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)

	if saves.is_empty():
		var empty := Label.new()
		empty.text = "Aucune sauvegarde disponible."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
		outer.add_child(empty)
		content_label.visible = false
		return

	# Un item par sauvegarde
	for save_data: Dictionary in saves:
		var filename: String = save_data.get("filename", "")
		var slot:     String = save_data.get("slot_name", "?")
		var ts:       String = save_data.get("timestamp", "")
		var scene:    String = save_data.get("level_scene", "")
		var hp:       float  = float(save_data.get("health", 0.0))
		var armor:    float  = float(save_data.get("armor", 0.0))
		var souls:    int    = int(save_data.get("soul_points", 0))

		# Nom de niveau lisible
		var level_label := "?"
		if "level_1" in scene:   level_label = "Niveau 1"
		elif "level_2" in scene: level_label = "Niveau 2"
		elif "level_3" in scene: level_label = "Niveau 3"
		elif "level_4" in scene: level_label = "Niveau 4"

		# Date lisible : "20250514_153022" → "14/05/2025 15:30"
		var date_str := ts
		if ts.length() >= 15:
			date_str = "%s/%s/%s %s:%s" % [
				ts.substr(6, 2), ts.substr(4, 2), ts.substr(0, 4),
				ts.substr(9, 2), ts.substr(11, 2)
			]

		# Panneau de l'item
		var item_panel := PanelContainer.new()
		var item_style := StyleBoxFlat.new()
		item_style.bg_color     = Color(0.08, 0.03, 0.08, 0.85)
		item_style.border_color = Color(0.5, 0.0, 0.0, 0.5)
		item_style.set_border_width_all(1)
		item_style.set_corner_radius_all(6)
		item_style.set_content_margin_all(10)
		item_panel.add_theme_stylebox_override("panel", item_style)
		outer.add_child(item_panel)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		item_panel.add_child(hbox)

		# Infos textuelles
		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 2)
		hbox.add_child(info_vbox)

		var name_lbl := Label.new()
		name_lbl.text = "💾  %s  —  %s" % [slot, level_label]
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85, 1.0))
		info_vbox.add_child(name_lbl)

		var detail_lbl := Label.new()
		detail_lbl.text = "%s   ❤ %.0f%%  🛡 %.0f%%  ✦ %d âmes" % [date_str, hp, armor, souls]
		detail_lbl.add_theme_font_size_override("font_size", 11)
		detail_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1.0))
		info_vbox.add_child(detail_lbl)

		# Bouton Charger
		var load_btn := Button.new()
		load_btn.text = "▶ Charger"
		load_btn.custom_minimum_size = Vector2(90, 0)
		load_btn.add_theme_font_size_override("font_size", 13)
		# Copier le style des autres boutons du menu
		load_btn.add_theme_stylebox_override("normal", _style_normal)
		load_btn.add_theme_stylebox_override("hover",  _style_active)
		hbox.add_child(load_btn)

		# Capturer la variable locale pour la lambda
		var captured_filename := filename
		var captured_scene    := scene
		load_btn.pressed.connect(func() -> void:
			_restore_save(captured_filename, captured_scene)
		)

	content_label.visible = false


func _restore_save(filename: String, scene: String) -> void:
	if filename == "" or scene == "":
		return
	SaveManager.pending_filename = filename
	GameData.deaths = 0
	# Pré-setter l'arme avant le changement de scène :
	# WeaponManager._ready() lit GameData.current_weapon avant qu'apply_pending_restore soit appelé.
	var save_data := SaveManager.get_save_data(filename)
	GameData.current_weapon = int(save_data.get("current_weapon", 0))
	var err := get_tree().change_scene_to_file(scene)
	if err != OK:
		push_error("MainMenu: impossible de charger la scène de sauvegarde : " + scene)
		SaveManager.pending_filename = ""


func _show_download() -> void:
	_hide_screenshot_grid()
	var current    := GameVersion.VERSION
	var build_date := GameVersion.BUILD_DATE
	var os_name    := OS.get_name()

	if not content_label.meta_clicked.is_connected(_on_link_clicked):
		content_label.meta_clicked.connect(_on_link_clicked)

	# Bannière mise à jour
	var update_banner := ""
	if _latest_version != "" and _latest_version != current and current != "dev":
		update_banner = "\n[color=#ffcc00]⬆  Mise à jour disponible : [b]%s[/b]  →  [url=https://neurohell.com/download]neurohell.com/download[/url][/color]\n" % _latest_version
	elif _latest_version == current:
		update_banner = "\n[color=#00e5ff]✔  Vous avez la dernière version.[/color]\n"

	# Version affichée (dev → dernière connue ou "–")
	var displayed_version := current if current != "dev" else \
		("dev  [color=#aaaaaa](dernière : %s)[/color]" % _latest_version if _latest_version != "" else "dev")

	# Mise en évidence plateforme actuelle
	var win_label := "[b]🪟 WINDOWS[/b]"
	var lin_label := "[b]🐧 LINUX[/b]"
	if os_name == "Windows":
		win_label = "[color=#00e5ff][b]🪟 WINDOWS  ◄ votre plateforme[/b][/color]"
	elif os_name == "Linux":
		lin_label = "[color=#00e5ff][b]🐧 LINUX  ◄ votre plateforme[/b][/color]"

	# Compteurs de téléchargement (-1 = fetch en cours)
	var win_dl := "[color=#555555]↓ chargement…[/color]" if _dl_windows < 0 \
		else "[color=#aaaaaa]↓ %d téléchargement%s (toutes versions)[/color]" \
			% [_dl_windows, "s" if _dl_windows > 1 else ""]
	var lin_dl := "[color=#555555]↓ chargement…[/color]" if _dl_linux < 0 \
		else "[color=#aaaaaa]↓ %d téléchargement%s (toutes versions)[/color]" \
			% [_dl_linux, "s" if _dl_linux > 1 else ""]

	content_label.text = """[font_size=22][b]TÉLÉCHARGER[/b][/font_size]
%s
[font_size=15][b]VERSION DESKTOP[/b][/font_size]

[color=#aaaaaa]La version bureau offre des modèles high poly, des particules GPU complexes et un éclairage dynamique Vulkan. Développée sous Godot 4.[/color]

Dernière version : [b]%s[/b]   ·   [color=#aaaaaa]build du %s[/color]

%s
[color=#aaaaaa]Windows 10 / 11 — 64 bit[/color]
[url=https://neurohell.com/download]⬇  Télécharger pour Windows[/url]
%s

%s
[color=#aaaaaa]x86_64 — Ubuntu, Debian, Arch...[/color]
[url=https://neurohell.com/download]⬇  Télécharger pour Linux[/url]
%s

[font_size=15][b]CONFIGURATION MINIMALE[/b][/font_size]

[color=#aaaaaa]GPU : Vulkan 1.0 ou OpenGL 3.3   ·   RAM : 4 Go   ·   Windows 10 64-bit / Linux glibc ≥ 2.31[/color]

[font_size=15][b]VERSION WEB (PROTOTYPE)[/b][/font_size]

[color=#aaaaaa]La démo navigateur reste accessible via[/color] [url=https://neurohell.com]neurohell.com[/url] [color=#aaaaaa]→ Lancer le jeu. Pas d'installation requise.[/color]
""" % [update_banner, displayed_version, build_date, win_label, win_dl, lin_label, lin_dl]


# ── Actions ──────────────────────────────────────────────────
func _on_play_pressed() -> void:
	_select(button_play)
	intro_overlay.visible = true
	intro_video.play()

func _play_launch_splash() -> void:
	var splash_stream := load(SPLASH_VIDEO_PATH) as VideoStream
	if splash_stream == null:
		return  # fichier absent → on affiche juste le menu

	# TextureRect cover : remplit toute la fenêtre en rognant si le ratio diffère
	_splash_cover = TextureRect.new()
	_splash_cover.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	_splash_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_splash_cover.layout_mode  = 1
	intro_overlay.add_child(_splash_cover)
	_splash_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_overlay.move_child(intro_overlay.get_node("SkipLabel"), intro_overlay.get_child_count() - 1)

	# intro_video joue en invisible (audio + décodage), on recopie sa texture chaque frame
	intro_video.visible = false
	var saved_stream    := intro_video.stream
	intro_video.finished.disconnect(_go_to_level_1)
	intro_video.finished.connect(func() -> void:
		if is_instance_valid(_splash_cover):
			_splash_cover.queue_free()
			_splash_cover = null
		AmbientManager.stop()
		intro_video.visible = true
		intro_video.stream  = saved_stream
		intro_video.finished.connect(_go_to_level_1)
		intro_overlay.visible = false
	, CONNECT_ONE_SHOT)
	intro_video.stream = splash_stream
	intro_overlay.visible = true
	intro_video.play()
	AmbientManager.play()

func _fit_background() -> void:
	if background == null or background.texture == null:
		return
	var vp      := get_viewport_rect().size
	var tex     := background.texture.get_size()
	var scale   := maxf(vp.x / tex.x, vp.y / tex.y)
	var new_sz  := tex * scale
	background.size     = new_sz
	background.position = (vp - new_sz) * 0.5

func _process(_delta: float) -> void:
	if _splash_cover != null and intro_video.is_playing():
		_splash_cover.texture = intro_video.get_video_texture()

func _go_to_level_1() -> void:
	intro_overlay.visible = false
	# Reset au début d'une nouvelle partie (morts + arme)
	# Les morts ne se reset PAS sur reload_current_scene() (mort en jeu),
	# seulement ici depuis le menu principal.
	GameData.deaths         = 0
	GameData.current_weapon = 0
	var err := get_tree().change_scene_to_file(LEVEL_1_SCENE)
	if err != OK:
		push_error("Impossible de charger le niveau 1 : " + LEVEL_1_SCENE)

func _on_link_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))

func _on_options_pressed() -> void:
	_select(button_options)
	# Créer le menu Options à la volée (overlay CanvasLayer)
	var om: Node = load("res://scripts/options_menu.gd").new()
	get_tree().root.add_child(om)
	om.closed.connect(func() -> void: om.queue_free())
	om.open()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if intro_overlay.visible and event.is_action_pressed("ui_cancel"):
		intro_video.stop()
		_go_to_level_1()
