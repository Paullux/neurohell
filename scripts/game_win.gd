extends Control

# ============================================================
#  NeuroHell — Écran de victoire
#  Cyberpunk / horreur — "JEU TERMINÉ"
# ============================================================

const FONT_BOLD := preload("res://assets/font/Orbitron/static/Orbitron-Bold.ttf")
const FONT_REG  := preload("res://assets/font/Orbitron/static/Orbitron-Regular.ttf")
const FONT_EXO  := preload("res://assets/font/Exo_2/static/Exo2-SemiBold.ttf")

const _COL_BG    := Color(0.010, 0.008, 0.020, 1.0)
const _COL_CYAN  := Color(0.000, 0.898, 1.000, 1.0)
const _COL_GREEN := Color(0.000, 1.000, 0.502, 1.0)
const _COL_RED   := Color(0.900, 0.120, 0.100, 1.0)
const _COL_DIM   := Color(0.420, 0.530, 0.620, 0.65)

const ENDING_VIDEO := preload("res://assets/videos/Le_soldat_et_la_porte_celeste.ogv")
const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

var _ending_started: bool = false
var _video_overlay: ColorRect = null
var _video_player: VideoStreamPlayer = null
var _lbl_skip: Label = null

var _t:             float = 0.0
var _can_exit:      bool  = false
var _blink_t:       float = 0.0
var _blink_on:      bool  = true
var _glitch_x:      float = 0.0
var _next_glitch:   float = 3.0

var _lbl_header:  Label = null
var _lbl_title:   Label = null
var _lbl_sub:     Label = null
var _lbl_flavor:  Label = null
var _lbl_press:   Label = null
var _btn_video:   Button = null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_lbl_header = _mk("// NEUROHELL — PROTOCOLE EXÉCUTÉ // TOUS LES SECTEURS NETTOYÉS //",
		FONT_REG, 11, Color(_COL_CYAN, 0.45), 0.082)

	_lbl_title  = _mk("NEUROSYSTÈME\nLIBÉRÉ", FONT_BOLD, 66, _COL_GREEN, 0.31)

	_lbl_sub    = _mk("LE NÉANT A ÉTÉ VAINCU", FONT_REG, 22, _COL_CYAN, 0.60)

	_lbl_flavor = _mk(
		"INTÉGRITÉ NEURALE : 100 %\n" +
		"CONNEXION CENTRALE RÉTABLIE  —  SYSTÈMES EN LIGNE\n" +
		"CONTAMINATION NEUROHELL : ÉRADIQUÉE",
		FONT_EXO, 13, _COL_DIM, 0.71)

	_lbl_press  = _mk("[ APPUYEZ SUR UNE TOUCHE POUR RECOMMENCER ]",
		FONT_REG, 15, _COL_CYAN, 0.91)

	_btn_video = _mk_btn("▶   LANCER LA CINÉMATIQUE FINALE", 0.81)
	_btn_video.pressed.connect(_start_ending_video)

	# Fade-in séquentiel
	for lbl: Label in [_lbl_header, _lbl_title, _lbl_sub, _lbl_flavor, _lbl_press]:
		lbl.modulate.a = 0.0
	_btn_video.modulate.a = 0.0

	var tw: Tween = create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(_lbl_header, "modulate:a", 1.0, 0.4)
	tw.tween_interval(0.15)
	tw.tween_property(_lbl_title,  "modulate:a", 1.0, 1.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tw.tween_interval(0.35)
	tw.tween_property(_lbl_sub,    "modulate:a", 1.0, 0.7)
	tw.tween_interval(0.2)
	tw.tween_property(_lbl_flavor, "modulate:a", 1.0, 0.6)
	tw.tween_interval(0.5)
	tw.tween_property(_btn_video,  "modulate:a", 1.0, 0.5)
	tw.tween_interval(0.2)
	tw.tween_property(_lbl_press,  "modulate:a", 1.0, 0.4)
	tw.tween_callback(func(): _can_exit = true)
	
	_create_ending_video_overlay()

	await get_tree().create_timer(10.0).timeout
	_start_ending_video()

# ── Vidéo de fin ────────────────────────────
func _create_ending_video_overlay() -> void:
	_video_overlay = ColorRect.new()
	_video_overlay.name = "EndingVideoOverlay"
	_video_overlay.color = Color(0, 0, 0, 1)
	_video_overlay.visible = false
	_video_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_video_overlay)

	_video_player = VideoStreamPlayer.new()
	_video_player.name = "EndingVideoPlayer"
	_video_player.stream = ENDING_VIDEO
	_video_player.expand = true
	_video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	_video_overlay.add_child(_video_player)

	_lbl_skip = _mk_skip_label(_video_overlay)

	_video_player.finished.connect(_return_to_menu)


func _start_ending_video() -> void:
	if _ending_started:
		return

	_ending_started = true
	_can_exit = false

	if _btn_video:
		_btn_video.visible = false

	_video_overlay.visible = true
	_video_player.play()


func _return_to_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

# ── Création d'un bouton cyberpunk ancré ─────────────────────
func _mk_btn(text: String, anchor_y: float) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_override("font", FONT_REG)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color",       _COL_CYAN)
	btn.add_theme_color_override("font_hover_color", _COL_GREEN)
	btn.add_theme_color_override("font_focus_color", _COL_CYAN)

	var _mk_style := func(bg_a: float, border_a: float) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color     = Color(_COL_CYAN, bg_a)
		s.border_color = Color(_COL_CYAN, border_a)
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			s.set_border_width(side, 1)
		s.corner_radius_top_left     = 4
		s.corner_radius_top_right    = 4
		s.corner_radius_bottom_right = 4
		s.corner_radius_bottom_left  = 4
		s.content_margin_left   = 28.0
		s.content_margin_right  = 28.0
		s.content_margin_top    = 11.0
		s.content_margin_bottom = 11.0
		return s

	btn.add_theme_stylebox_override("normal",  _mk_style.call(0.05, 0.40))
	btn.add_theme_stylebox_override("hover",   _mk_style.call(0.14, 0.90))
	btn.add_theme_stylebox_override("pressed", _mk_style.call(0.20, 1.00))
	btn.add_theme_stylebox_override("focus",   _mk_style.call(0.05, 0.40))

	btn.anchor_left   = 0.28
	btn.anchor_right  = 0.72
	btn.anchor_top    = anchor_y
	btn.anchor_bottom = anchor_y
	btn.offset_top    = -24.0
	btn.offset_bottom =  24.0
	btn.grow_vertical = Control.GROW_DIRECTION_BOTH

	add_child(btn)
	return btn

# ── Label "[ ESC TO SKIP ]" — bas centre, fond sombre ────────
func _mk_skip_label(parent: Control) -> Label:
	var lbl := Label.new()
	lbl.text = "[ ESC TO SKIP ]"
	lbl.add_theme_font_override("font", FONT_REG)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.05, 0.05, 0.08, 0.88)
	s.border_color = Color(0.9, 0.9, 0.9, 0.30)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		s.set_border_width(side, 1)
	s.corner_radius_top_left     = 3
	s.corner_radius_top_right    = 3
	s.corner_radius_bottom_right = 3
	s.corner_radius_bottom_left  = 3
	s.content_margin_left   = 10.0
	s.content_margin_right  = 10.0
	s.content_margin_top    = 5.0
	s.content_margin_bottom = 5.0
	lbl.add_theme_stylebox_override("normal", s)

	lbl.anchor_left   = 0.0
	lbl.anchor_right  = 1.0
	lbl.anchor_top    = 1.0
	lbl.anchor_bottom = 1.0
	lbl.offset_top    = -52.0
	lbl.offset_bottom = -20.0
	lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN

	parent.add_child(lbl)
	return lbl

# ── Création d'un Label ancré ──────────────────────────────
func _mk(text: String, font: Font, fs: int, col: Color, anchor_y: float) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	l.anchor_left           = 0.0
	l.anchor_right          = 1.0
	l.anchor_top            = anchor_y
	l.anchor_bottom         = anchor_y
	l.offset_top            = -72.0
	l.offset_bottom         =  72.0
	l.grow_vertical         = Control.GROW_DIRECTION_BOTH
	add_child(l)
	return l

# ── Boucle ────────────────────────────────────────────────
func _process(delta: float) -> void:
	_t         += delta
	_blink_t   += delta
	_next_glitch -= delta

	# Blink "press key"
	if _blink_t >= 0.60:
		_blink_t = 0.0
		_blink_on = not _blink_on
		if _lbl_press and _can_exit:
			_lbl_press.modulate.a = 1.0 if _blink_on else 0.22

	# Glitch aléatoire sur le titre
	if _next_glitch <= 0.0:
		_glitch_x    = randf_range(-14.0, 14.0)
		_next_glitch = randf_range(2.5, 7.0)
	else:
		_glitch_x = move_toward(_glitch_x, 0.0, delta * 90.0)
	if _lbl_title:
		_lbl_title.position.x = _glitch_x

	# Pulsation couleur titre (après fade-in)
	if _lbl_title and _can_exit:
		var p := 0.82 + 0.18 * sin(_t * 1.6)
		_lbl_title.add_theme_color_override("font_color",
			Color(0.0, p, 0.502 * p, 1.0))

	queue_redraw()

# ── Dessin fond + décorations ─────────────────────────────
func _draw() -> void:
	var w := size.x
	var h := size.y

	# Fond noir-violet
	draw_rect(Rect2(0, 0, w, h), _COL_BG)

	# Scanlines
	var sy := 0.0
	while sy < h:
		draw_line(Vector2(0, sy), Vector2(w, sy), Color(0, 0, 0, 0.05), 1.0)
		sy += 3.0

	# Vignette latérale
	for _i in range(24):
		var ratio := float(_i) / 24.0
		var a     := ratio * ratio * 0.55
		draw_rect(Rect2(0,           0, w * ratio * 0.14, h), Color(0, 0, 0, a / 24.0))
		draw_rect(Rect2(w * (1.0 - ratio * 0.14), 0, w, h),   Color(0, 0, 0, a / 24.0))

	# Lignes horizontales encadrement
	var lc := Color(_COL_CYAN, 0.22)
	draw_line(Vector2(w*0.055, h*0.108), Vector2(w*0.945, h*0.108), lc, 1.0)
	draw_line(Vector2(w*0.055, h*0.892), Vector2(w*0.945, h*0.892), lc, 1.0)

	# Lignes verticales (accent vert pulsant)
	var lv := Color(_COL_GREEN, 0.14 + 0.06 * sin(_t * 1.8))
	draw_line(Vector2(w*0.055, h*0.108), Vector2(w*0.055, h*0.892), lv, 1.0)
	draw_line(Vector2(w*0.945, h*0.108), Vector2(w*0.945, h*0.892), lv, 1.0)

	# Coins (brackets L)
	var cs := 26.0
	var bc := Color(_COL_CYAN, 0.72)
	for corner in [
		[Vector2(w*0.046, h*0.088),  Vector2(1,0),  Vector2(0,1)],
		[Vector2(w*0.954, h*0.088),  Vector2(-1,0), Vector2(0,1)],
		[Vector2(w*0.046, h*0.912),  Vector2(1,0),  Vector2(0,-1)],
		[Vector2(w*0.954, h*0.912),  Vector2(-1,0), Vector2(0,-1)],
	]:
		var p : Vector2 = corner[0]
		var dx: Vector2 = corner[1]
		var dy: Vector2 = corner[2]
		draw_line(p, p + dx * cs, bc, 2.0)
		draw_line(p, p + dy * cs, bc, 2.0)

	# Symbole triangle ▲ (horreur, entre header et titre)
	var tx := w * 0.5
	var ty := h * 0.20
	var ts := 13.0
	var tc := Color(_COL_RED, 0.28 + 0.14 * sin(_t * 2.8))
	draw_line(Vector2(tx, ty - ts),           Vector2(tx + ts, ty + ts*0.65), tc, 1.5)
	draw_line(Vector2(tx + ts, ty + ts*0.65), Vector2(tx - ts, ty + ts*0.65), tc, 1.5)
	draw_line(Vector2(tx - ts, ty + ts*0.65), Vector2(tx, ty - ts),           tc, 1.5)

	# Séparateur sous le titre (ligne avec losange central)
	var sep_y   := h * 0.578
	var sep_gw  := Color(_COL_GREEN, 0.12 + 0.07 * sin(_t * 2.2))
	draw_line(Vector2(w*0.12, sep_y), Vector2(w*0.88, sep_y), sep_gw, 4.0)
	draw_line(Vector2(w*0.12, sep_y), Vector2(w*0.88, sep_y), Color(_COL_GREEN, 0.50), 1.0)
	# Losange
	var dm := Vector2(w*0.5, sep_y)
	var ds := 6.0
	var dc := Color(_COL_GREEN, 0.85)
	draw_line(dm + Vector2(-ds, 0), dm + Vector2(0, -ds), dc, 2.0)
	draw_line(dm + Vector2(0, -ds), dm + Vector2(ds, 0),  dc, 2.0)
	draw_line(dm + Vector2(ds, 0),  dm + Vector2(0, ds),  dc, 2.0)
	draw_line(dm + Vector2(0, ds),  dm + Vector2(-ds, 0), dc, 2.0)

	# Petits points de coin sur le séparateur
	draw_circle(Vector2(w*0.12, sep_y), 2.5, Color(_COL_GREEN, 0.5))
	draw_circle(Vector2(w*0.88, sep_y), 2.5, Color(_COL_GREEN, 0.5))

# ── Input : n'importe quelle touche / clic lance la vidéo ──
func _input(event: InputEvent) -> void:
	if _ending_started:
		if event is InputEventKey and event.pressed and not event.is_echo():
			if event.keycode == KEY_ESCAPE:
				_video_player.stop()
				_return_to_menu()
		return

	# Dès que le fade-in est terminé, toute touche ou clic lance la vidéo
	if _can_exit:
		var is_key:   bool = event is InputEventKey   and event.pressed and not event.is_echo()
		var is_click: bool = event is InputEventMouseButton and event.pressed
		if is_key or is_click:
			_start_ending_video()
