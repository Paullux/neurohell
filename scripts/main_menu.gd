extends Control

@onready var button_play: Button = $RootMargin/Center/VBox/MainContent/MenuPanel/MenuVBox/ButtonPlay
@onready var button_story: Button = $RootMargin/Center/VBox/MainContent/MenuPanel/MenuVBox/ButtonStory
@onready var button_screenshots: Button = $RootMargin/Center/VBox/MainContent/MenuPanel/MenuVBox/ButtonScreenshots
@onready var button_download: Button = $RootMargin/Center/VBox/MainContent/MenuPanel/MenuVBox/ButtonDownload
@onready var button_quit: Button = $RootMargin/Center/VBox/MainContent/MenuPanel/MenuVBox/ButtonQuit

@onready var content_label: RichTextLabel = $RootMargin/Center/VBox/MainContent/ContentPanel/ContentLabel
@onready var intro_overlay: ColorRect = $IntroOverlay
@onready var intro_video: VideoStreamPlayer = $IntroOverlay/IntroVideo

const LEVEL_1_SCENE := "res://scenes/level_1.tscn"

func _ready() -> void:
	intro_overlay.visible = false

	button_play.pressed.connect(_on_play_pressed)
	button_story.pressed.connect(_show_story)
	button_screenshots.pressed.connect(_show_screenshots)
	button_download.pressed.connect(_show_download)
	button_quit.pressed.connect(_on_quit_pressed)

	intro_video.finished.connect(_go_to_level_1)

	# Crânes au survol sur tous les boutons du menu
	for btn: Button in [button_play, button_story, button_screenshots, button_download, button_quit]:
		_setup_skull_hover(btn)

	_show_home()

# ── Effet crâne au survol ────────────────────────────────────
func _setup_skull_hover(btn: Button) -> void:
	var original_text := btn.text
	btn.mouse_entered.connect(func() -> void:
		btn.text = "💀  " + original_text + "  💀"
	)
	btn.mouse_exited.connect(func() -> void:
		btn.text = original_text
	)

func _input(event: InputEvent) -> void:
	if intro_overlay.visible and event.is_action_pressed("ui_cancel"):
		_skip_intro()

func _skip_intro() -> void:
	intro_video.stop()
	_go_to_level_1()

func _show_home() -> void:
	content_label.text = """
[center][font_size=28][b]Entrée en enfer[/b][/font_size][/center]

[center]Lance l'intro cinématique, puis enchaîne directement sur le premier niveau.[/center]

[center][color=#ff7070]NeuroHell[/color] - prototype desktop Godot 4[/center]
"""


func _show_story() -> void:
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
	content_label.text = """
[font_size=24][b]Captures d'écran[/b][/font_size]

Les captures de la version desktop seront ajoutées plus tard.

Tu pourras créer une galerie avec des TextureButton ou des TextureRect dans un GridContainer.
"""


func _show_download() -> void:
	content_label.text = """
[font_size=24][b]Télécharger[/b][/font_size]

[b]Windows[/b]
Bientôt disponible.

[b]Linux[/b]
Bientôt disponible.

La version Godot desktop permettra de profiter de meilleurs effets visuels, particules GPU et éclairages dynamiques.
"""


func _on_play_pressed() -> void:
	intro_overlay.visible = true
	intro_video.play()


func _go_to_level_1() -> void:
	intro_overlay.visible = false

	var err := get_tree().change_scene_to_file(LEVEL_1_SCENE)
	if err != OK:
		push_error("Impossible de charger le niveau 1 : " + LEVEL_1_SCENE)

func _on_quit_pressed() -> void:
	get_tree().quit()
