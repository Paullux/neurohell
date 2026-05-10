extends CanvasLayer

# ============================================================
#  NeuroHell — HUD Manager (Godot 4.x)
#  Reproduction fidèle du HUD HTML :
#  Orbitron + Exo2, portrait GIF, jauge armor ECharts,
#  slots armes avec lueur, scope canvas, flash dégâts.
# ============================================================

# ── Fonts ────────────────────────────────────────────────────
const _FONT_ORB_BOLD := preload("res://assets/font/Orbitron/static/Orbitron-Bold.ttf")
const _FONT_ORB_REG  := preload("res://assets/font/Orbitron/static/Orbitron-Regular.ttf")
const _FONT_EXO2     := preload("res://assets/font/Exo_2/static/Exo2-Regular.ttf")
const _FONT_EXO2_SB  := preload("res://assets/font/Exo_2/static/Exo2-SemiBold.ttf")

# ── Portraits (GIF → texture statique 1er frame) ────────────
const PORTRAITS := {
	100: "res://assets/videos/face/portrait_hp100.ogv",
	 90: "res://assets/videos/face/portrait_hp090.ogv",
	 80: "res://assets/videos/face/portrait_hp080.ogv",
	 70: "res://assets/videos/face/portrait_hp070.ogv",
	 60: "res://assets/videos/face/portrait_hp060.ogv",
	 50: "res://assets/videos/face/portrait_hp050.ogv",
	 40: "res://assets/videos/face/portrait_hp040.ogv",
	 30: "res://assets/videos/face/portrait_hp030.ogv",
	 20: "res://assets/videos/face/portrait_hp020.ogv",
	 10: "res://assets/videos/face/portrait_hp010.ogv",
	  0: "res://assets/videos/face/portrait_hp000.ogv",
}

# ── Couleurs par slot arme ───────────────────────────────────
const SLOT_COLORS := [
	Color(1.0,  0.55, 0.0,  1.0),   # Orange  — Iron Gazlet
	Color(0.31, 0.59, 1.0,  1.0),   # Bleu    — Plasma Std
	Color(1.0,  1.0,  1.0,  1.0),   # Blanc   — Plasma Elite
	Color(0.0,  1.0,  0.83, 1.0),   # Cyan    — Teal Sniper
	Color(0.69, 0.31, 1.0,  1.0),   # Violet  — Void Rifle
]

const WEAPON_ICONS := [
	"res://assets/images/plasma_types/plasma_irongazlet.jpg",
	"res://assets/images/plasma_types/plasma_plasmapistol_standard.jpg",
	"res://assets/images/plasma_types/plasma_plasmapistol_elite.jpg",
	"res://assets/images/plasma_types/plasma_tealsniper.jpg",
	"res://assets/images/plasma_types/plasma_voidrifle.jpg",
]

# ── Nodes (chemins fidèles à hud.tscn) ──────────────────────
@onready var portrait:        VideoStreamPlayer = $Root/TopLeft/PortraitFrame/Portrait
@onready var portrait_frame:  Panel          = $Root/TopLeft/PortraitFrame
@onready var hr_value:        Label          = $Root/TopLeft/Biometrics/HRLine/HRValue
@onready var armor_value:     Label          = $Root/TopLeft/Biometrics/ARMORLine/ARMORValue
@onready var pwr_value:       Label          = $Root/TopLeft/Biometrics/PWRLine/PWRValue
@onready var health_value:    Label          = $Root/BottomBar/BottomContent/HealthBlock/HealthIconRow/HealthValue
@onready var health_segs:     GridContainer  = $Root/BottomBar/BottomContent/HealthBlock/HealthIconRow/HealthSegments
@onready var armor_gauge:     Control        = $Root/BottomBar/BottomContent/EnergyBlock/ArmorGauge
@onready var weapon_slots:    HBoxContainer  = $Root/BottomBar/BottomContent/WeaponSlots
@onready var hit_flash:       ColorRect      = $Root/HitFlash
@onready var crosshair:       Label          = $Root/Crosshair
@onready var death_screen:    ColorRect      = $Root/DeathScreen
@onready var death_countdown: Label          = $Root/DeathScreen/DeathContent/DeathCountdown
@onready var start_overlay:   ColorRect      = $Root/StartOverlay
@onready var status_label:    Label          = $Root/StartOverlay/StatusLabel
@onready var scope_overlay:   ColorRect      = $Root/ScopeOverlay
@onready var _minimap_vp:     SubViewport    = $Root/TopRight/MinimapViewport
@onready var _minimap_cam:    Camera3D       = $Root/TopRight/MinimapViewport/MinimapCamera
@onready var _minimap_panel:  Panel          = $Root/TopRight
@onready var _torch_block:    VBoxContainer  = $Root/BottomBar/BottomContent/TorchBlock

var _hp_segments: Array[Panel] = []
var _minimap_target: Node3D = null   # référence joueur pour la caméra minimap
var torch_gauge: Control    = null   # créé dynamiquement dans _ready()
var _current_portrait_bracket: int = -1  # bracket actif du portrait vidéo

# ── Init ─────────────────────────────────────────────────────
func _ready() -> void:
	_build_hp_segments()
	_apply_fonts()
	_style_portrait_frame()
	_style_bottom_bar()
	_style_weapon_slots()
	_style_scope_overlay()
	_style_minimap_panel()
	_load_weapon_icons()
	_preload_portraits()
	# Partage du monde 3D principal avec le SubViewport minimap
	if _minimap_vp:
		_minimap_vp.world_3d = get_viewport().world_3d
	_build_torch_gauge()
	set_health(100.0)
	set_pwr(100.0)
	set_armor(100.0)
	set_active_weapon(0)
	set_torch(1.0, false)
	show_start_overlay("CLIQUEZ POUR COMMENCER\n[WASD] Déplacer  [ESPACE] Sauter  [1-5] Armes  [CLIC] Tirer")
	if death_screen:    death_screen.visible  = false
	if scope_overlay:   scope_overlay.visible = false

# ── Minimap ───────────────────────────────────────────────────
func set_minimap_target(node: Node3D) -> void:
	_minimap_target = node

func _process(_delta: float) -> void:
	if _minimap_target == null or _minimap_cam == null: return
	# Caméra minimap suit le joueur (même X/Z, hauteur fixe +30)
	var p := _minimap_target.global_position
	_minimap_cam.position = Vector3(p.x, p.y + 30.0, p.z)
	# Orientation : "haut" de la minimap = direction regard joueur
	_minimap_cam.rotation_degrees = Vector3(-90.0, _minimap_target.rotation_degrees.y, 0.0)

func _style_minimap_panel() -> void:
	if _minimap_panel == null: return
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.0, 0.02, 0.08, 0.88)
	s.border_color = Color(0.0, 0.898, 1.0, 1.0)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		s.set_border_width(side, 2)
	s.shadow_color = Color(0.0, 0.898, 1.0, 0.3)
	s.shadow_size  = 6
	_minimap_panel.add_theme_stylebox_override("panel", s)

# ── Pré-chargement portraits vidéo ───────────────────────────
var _portrait_streams: Dictionary = {}  # bracket → VideoStream

func _preload_portraits() -> void:
	for bracket: int in PORTRAITS.keys():
		var stream := load(PORTRAITS[bracket]) as VideoStream
		if stream:
			_portrait_streams[bracket] = stream
		else:
			push_warning("Portrait non chargé : " + PORTRAITS[bracket])

# ── Fonts ─────────────────────────────────────────────────────
func _apply_fonts() -> void:
	# Health value : Orbitron Bold 38px
	if health_value:
		health_value.add_theme_font_override("font", _FONT_ORB_BOLD)

	# Biométrics valeurs : Orbitron Reg
	if hr_value:  hr_value.add_theme_font_override("font",  _FONT_ORB_REG)
	if armor_value: armor_value.add_theme_font_override("font", _FONT_ORB_REG)
	if pwr_value: pwr_value.add_theme_font_override("font", _FONT_ORB_REG)

	# Crosshair : monospace (pas de custom font nécessaire)

	# Slots armes : Exo2 noms, Orbitron ammo, Exo2 key
	if weapon_slots:
		for i in range(weapon_slots.get_child_count()):
			var slot := weapon_slots.get_child(i)
			var nlbl: Label = slot.get_node_or_null("SlotName%d"  % (i + 1))
			var albl: Label = slot.get_node_or_null("AmmoLabel%d" % (i + 1))
			var klbl: Label = slot.get_node_or_null("KeyLabel%d"  % (i + 1))
			if nlbl: nlbl.add_theme_font_override("font", _FONT_EXO2)
			if albl: albl.add_theme_font_override("font", _FONT_ORB_BOLD)
			if klbl: klbl.add_theme_font_override("font", _FONT_EXO2)

	# Labels biométrics Exo2
	var bio_labels := [
		$Root/TopLeft/Biometrics/HRLine/HRLabel,
		$Root/TopLeft/Biometrics/SYSLine,
		$Root/TopLeft/Biometrics/ARMORLine/ARMORLabel,
		$Root/TopLeft/Biometrics/PWRLine/PWRLabel,
		$Root/TopLeft/Biometrics/BioLabel,
	]
	for lbl in bio_labels:
		if lbl is Label:
			(lbl as Label).add_theme_font_override("font", _FONT_EXO2)

	# Labels Orbitron
	var orb_labels := [
		$Root/BottomBar/BottomContent/HealthBlock/HealthLabel,
	]
	for lbl in orb_labels:
		if lbl is Label:
			(lbl as Label).add_theme_font_override("font", _FONT_ORB_REG)

	# Death screen
	var ds_title: Label = $Root/DeathScreen/DeathContent/DeathTitle
	var ds_sub:   Label = $Root/DeathScreen/DeathContent/DeathSubtitle
	if ds_title:    ds_title.add_theme_font_override("font",    _FONT_ORB_BOLD)
	if ds_sub:      ds_sub.add_theme_font_override("font",      _FONT_EXO2)
	if death_countdown: death_countdown.add_theme_font_override("font", _FONT_ORB_REG)

	# Start overlay
	if status_label: status_label.add_theme_font_override("font", _FONT_EXO2_SB)

# ── Style portrait (bordure cyan + ombre) ────────────────────
func _style_portrait_frame() -> void:
	if portrait_frame == null: return
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.0, 0.0, 0.0, 1.0)
	s.border_color = Color(0.0, 0.898, 1.0, 1.0)  # #00e5ff
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		s.set_border_width(side, 2)
	s.shadow_color = Color(0.0, 0.898, 1.0, 0.35)
	s.shadow_size  = 8
	portrait_frame.add_theme_stylebox_override("panel", s)

# ── Style barre du bas (fond sombre semi-transparent) ────────
func _style_bottom_bar() -> void:
	var bb: Panel = $Root/BottomBar
	if bb == null: return
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.0, 0.016, 0.071, 0.95)  # rgba(0,4,18,0.95)
	s.border_color = Color(0.0, 0.898, 1.0, 0.18)
	s.set_border_width(SIDE_TOP, 1)
	bb.add_theme_stylebox_override("panel", s)

# ── Style slots armes ────────────────────────────────────────
func _style_weapon_slots() -> void:
	if weapon_slots == null: return
	for i in range(weapon_slots.get_child_count()):
		var slot: Panel = weapon_slots.get_child(i) as Panel
		if slot == null: continue
		var s := StyleBoxFlat.new()
		s.bg_color     = Color(0.0, 0.031, 0.110, 0.85)
		s.border_color = Color(0.0, 0.898, 1.0, 0.22)
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			s.set_border_width(side, 1)
		slot.add_theme_stylebox_override("panel", s)

# ── Scope overlay transparent (ScopeCanvas gère le dessin) ──
func _style_scope_overlay() -> void:
	if scope_overlay == null:
		return

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec2 viewport_size = vec2(1920.0, 1080.0);
uniform float radius_px = 278.0;
uniform float softness_px = 25.0;
uniform float darkness = 1.0;

void fragment() {
	vec2 pixel = UV * viewport_size;
	vec2 center = viewport_size * 0.5;

	float d = distance(pixel, center);
	float mask = smoothstep(radius_px, radius_px + softness_px, d);

	COLOR = vec4(0.0, 0.0, 0.0, mask * darkness);
}
"""

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("viewport_size", get_viewport().get_visible_rect().size)
	scope_overlay.material = mat

# ── Segments HP ───────────────────────────────────────────────
func _build_hp_segments() -> void:
	if health_segs == null: return
	for _i in range(10):
		var seg := Panel.new()
		seg.custom_minimum_size = Vector2(14, 14)
		var style := StyleBoxFlat.new()
		style.bg_color     = Color(0, 0.898, 1, 0.18)
		style.border_color = Color(0, 0.898, 1, 0.30)
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			style.set_border_width(side, 1)
		seg.add_theme_stylebox_override("panel", style)
		health_segs.add_child(seg)
		_hp_segments.append(seg)

# ── Icônes armes ─────────────────────────────────────────────
func _load_weapon_icons() -> void:
	if weapon_slots == null: return
	for i in range(weapon_slots.get_child_count()):
		var slot := weapon_slots.get_child(i)
		var icon: TextureRect = slot.get_node_or_null("WeaponIcon%d" % (i + 1))
		if icon == null: continue
		if i >= WEAPON_ICONS.size(): continue
		var tex := load(WEAPON_ICONS[i])
		if tex: icon.texture = tex

# ── Santé ─────────────────────────────────────────────────────
func set_health(hp: float) -> void:
	if health_value == null: return
	health_value.text = "%d%%" % int(hp)
	set_pwr(hp)

	# Couleur + HR selon état
	var c: Color
	var hr := 72.0
	if hp <= 20.0:
		c = Color(1.0, 0.2,  0.2,  1.0);  hr = 145.0
	elif hp <= 50.0:
		c = Color(1.0, 0.67, 0.0,  1.0);  hr = 110.0
	else:
		c = Color(0.0, 0.898, 1.0, 1.0);  hr = 72.0 + (100.0 - hp) * 0.5

	health_value.add_theme_color_override("font_color", c)
	if hr_value: hr_value.text = "%d bpm" % int(hr)

	# Portrait vidéo — switch au bon bracket HP (ne redémarre que si le bracket change)
	var bracket := int(maxf(0.0, floor(hp / 10.0)) * 10.0)

	if bracket != _current_portrait_bracket:
		_current_portrait_bracket = bracket

		if portrait and _portrait_streams.has(bracket):
			portrait.stop()
			portrait.stream = _portrait_streams[bracket]
			portrait.loop = true
			portrait.play()

	# Segments
	var filled := int(ceil(hp / 10.0))
	for i in range(_hp_segments.size()):
		var style := _hp_segments[i].get_theme_stylebox("panel") as StyleBoxFlat
		if style == null: continue
		if i < filled:
			var seg_c: Color
			if hp <= 20.0:        seg_c = Color(1.0, 0.2,  0.2,  1.0)
			elif hp <= 50.0:      seg_c = Color(1.0, 0.67, 0.0,  1.0)
			else:                 seg_c = Color(0.0, 0.898, 1.0, 1.0)
			style.bg_color     = seg_c
			style.border_color = seg_c
			# Glow simulé via shadow
			style.shadow_color = Color(seg_c, 0.7)
			style.shadow_size  = 3
		else:
			style.bg_color     = Color(0, 0.898, 1, 0.18)
			style.border_color = Color(0, 0.898, 1, 0.30)
			style.shadow_size  = 0

# ── Armure ────────────────────────────────────────────────────
func set_armor(val: float) -> void:
	if armor_gauge and armor_gauge.has_method("set_value"):
		armor_gauge.set_value(val)

	if armor_value:
		armor_value.text = "%d%%" % int(val)

func set_pwr(val: float) -> void:
	if pwr_value:
		pwr_value.text = "%d%%" % int(val)

# ── Slot arme actif ──────────────────────────────────────────
func set_active_weapon(index: int) -> void:
	if weapon_slots == null: return
	for i in range(weapon_slots.get_child_count()):
		var slot: Panel = weapon_slots.get_child(i) as Panel
		if slot == null: continue
		var nlbl: Label = slot.get_node_or_null("SlotName%d"  % (i + 1))
		var albl: Label = slot.get_node_or_null("AmmoLabel%d" % (i + 1))
		if i == index:
			var sa := StyleBoxFlat.new()
			sa.bg_color     = Color(0.0, 0.078, 0.216, 0.95)
			sa.border_color = Color(1.0, 1.0, 1.0, 1.0)
			sa.shadow_color = Color(1.0, 1.0, 1.0, 0.35)
			sa.shadow_size  = 14
			for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
				sa.set_border_width(side, 4)
			slot.add_theme_stylebox_override("panel", sa)
			if nlbl:
				nlbl.add_theme_color_override("font_color", Color.WHITE)
				nlbl.add_theme_font_override("font", _FONT_ORB_BOLD)
			if albl: albl.add_theme_color_override("font_color", Color.WHITE)
		else:
			# Restaurer le style par défaut du slot
			var sd := StyleBoxFlat.new()
			sd.bg_color     = Color(0.0, 0.031, 0.110, 0.85)
			sd.border_color = Color(0.0, 0.898, 1.0, 0.22)
			for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
				sd.set_border_width(side, 1)
			slot.add_theme_stylebox_override("panel", sd)
			if nlbl:
				nlbl.add_theme_color_override("font_color", Color(0.7, 0.78, 0.94, 0.65))
				nlbl.add_theme_font_override("font", _FONT_EXO2)
			if albl and i < SLOT_COLORS.size():
				albl.add_theme_color_override("font_color", SLOT_COLORS[i])

# ── Torche ────────────────────────────────────────────────────
func _build_torch_gauge() -> void:
	if _torch_block == null: return
	var script := load("res://scripts/torch_gauge.gd")
	torch_gauge = Control.new()
	torch_gauge.set_script(script)
	torch_gauge.custom_minimum_size = Vector2(150.0, 80.0)
	torch_gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	torch_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_torch_block.add_child(torch_gauge)

func set_torch(ratio: float, dep: bool) -> void:
	if torch_gauge:
		torch_gauge.call("set_value", ratio, dep)

func set_ammo(index: int, ammo: float) -> void:
	if weapon_slots == null: return
	var slot := weapon_slots.get_child(index) if index < weapon_slots.get_child_count() else null
	if slot == null: return
	var lbl: Label = slot.get_node_or_null("AmmoLabel%d" % (index + 1))
	if lbl: lbl.text = "∞" if ammo >= 1e9 else str(int(ammo))

# ── Flash dégâts ──────────────────────────────────────────────
func show_hit_flash(color: Color = Color(1, 0.39, 0, 0.4)) -> void:
	if hit_flash == null: return
	hit_flash.color = color
	var tw := create_tween()
	tw.tween_property(hit_flash, "color:a", 0.0, 0.15)

# ── Scope sniper ──────────────────────────────────────────────
func set_scope(on: bool) -> void:
	if scope_overlay: scope_overlay.visible = on
	if crosshair:     crosshair.visible     = not on

# ── Mort ──────────────────────────────────────────────────────
func show_death_screen() -> void:
	if death_screen: death_screen.visible = true
	_countdown(5)

func _countdown(t: int) -> void:
	if death_countdown: death_countdown.text = "RELANCE DANS %ds..." % t
	if t <= 0: get_tree().reload_current_scene(); return
	await get_tree().create_timer(1.0).timeout
	_countdown(t - 1)

# ── Start overlay ─────────────────────────────────────────────
func show_start_overlay(msg: String) -> void:
	if start_overlay: start_overlay.visible = true
	if status_label:  status_label.text = msg

func hide_start_overlay() -> void:
	if start_overlay: start_overlay.visible = false

# ── Points d'âme ──────────────────────────────────────────────
var _souls_label: Label = null

func update_souls(points: int) -> void:
	if _souls_label == null:
		_souls_label = _build_souls_label()
	_souls_label.text = "✦ %d" % points
	# Flash bref à chaque gain
	var tw := create_tween()
	tw.tween_property(_souls_label, "modulate", Color(1.0, 0.85, 0.2, 1.0), 0.0)
	tw.tween_property(_souls_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)

func _build_souls_label() -> Label:
	var root := get_node_or_null("Root")
	if root == null: root = self
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lbl.offset_left   = -160.0
	lbl.offset_top    =  28.0
	lbl.offset_right  =  -28.0
	lbl.offset_bottom =  60.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.add_theme_font_override("font", _FONT_ORB_REG)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.15, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0.8, 0.5, 0.0, 0.9))
	lbl.add_theme_constant_override("shadow_outline_size", 6)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = "✦ 0"
	root.add_child(lbl)
	return lbl

# ── Narration ─────────────────────────────────────────────────
var _narr_label: Label = null
var _narr_tween: Tween = null

func show_narration(text: String) -> void:
	if _narr_label == null:
		_narr_label = _build_narration_label()

	if _narr_tween:
		_narr_tween.kill()

	_narr_label.text    = text
	_narr_label.visible = true
	_narr_label.modulate.a = 0.0

	_narr_tween = create_tween()
	_narr_tween.tween_property(_narr_label, "modulate:a", 1.0, 0.7) \
		.set_ease(Tween.EASE_OUT)
	_narr_tween.tween_interval(4.0)
	_narr_tween.tween_property(_narr_label, "modulate:a", 0.0, 0.9) \
		.set_ease(Tween.EASE_IN)

func _build_narration_label() -> Label:
	var root := get_node_or_null("Root")
	if root == null:
		root = self

	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lbl.offset_top    = -160.0
	lbl.offset_bottom = -100.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font",      _FONT_ORB_REG)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color",        Color(0.63, 0.94, 0.88, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0,  0.86, 0.71, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x",  0)
	lbl.add_theme_constant_override("shadow_offset_y",  0)
	lbl.add_theme_constant_override("shadow_outline_size", 8)
	lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	lbl.modulate.a    = 0.0
	root.add_child(lbl)
	return lbl

# ── Écran fin de niveau ───────────────────────────────────────
func show_end_stats(kills: int, souls: int, time_secs: float) -> void:
	var root := get_node_or_null("Root")
	if root == null: root = self

	var mins := int(time_secs) / 60
	var secs := int(time_secs) % 60

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color        = Color(0.0, 0.0, 0.0, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left   = -220.0
	vbox.offset_top    = -120.0
	vbox.offset_right  =  220.0
	vbox.offset_bottom =  120.0
	vbox.alignment     = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	overlay.add_child(vbox)

	var lines := [
		["NIVEAU TERMINÉ",        _FONT_ORB_BOLD, 22, Color(0.0, 0.9, 1.0, 1.0)],
		["",                      _FONT_EXO2,      8, Color.WHITE],
		["%02d:%02d" % [mins, secs], _FONT_ORB_REG, 32, Color.WHITE],
		["temps",                 _FONT_EXO2,     11, Color(0.6, 0.6, 0.6, 1.0)],
		["",                      _FONT_EXO2,     8,  Color.WHITE],
		["%d kills" % kills,      _FONT_ORB_REG,  18, Color(1.0, 0.4, 0.4, 1.0)],
		["✦ %d âmes" % souls,     _FONT_ORB_REG,  18, Color(0.95, 0.82, 0.15, 1.0)],
	]
	for line in lines:
		var lbl := Label.new()
		lbl.text = line[0]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", line[1])
		lbl.add_theme_font_size_override("font_size", line[2])
		lbl.add_theme_color_override("font_color", line[3])
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(lbl)

	# Fade in → tenu → la transition de scène arrive après
	var tw := create_tween()
	tw.tween_property(overlay, "color:a", 0.85, 0.6).set_ease(Tween.EASE_OUT)

# ── Fondu depuis le blanc (transition entre niveaux) ─────────
func fade_in_from_white(duration: float = 1.5) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 98
	add_child(cl)

	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color        = Color(1.0, 1.0, 1.0, 1.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(rect)

	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(cl.queue_free)
