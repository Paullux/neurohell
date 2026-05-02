extends Control

# ============================================================
#  NeuroHell — ArmorGauge
#  Reproduit le gauge HTML : arc 240°, graduations radiales,
#  glow multi-couches, texte Orbitron centré.
# ============================================================

const FONT_ORB := preload("res://assets/font/Orbitron/static/Orbitron-Bold.ttf")
const FONT_REG := preload("res://assets/font/Orbitron/static/Orbitron-Regular.ttf")

const _COL_FILL  := Color(0.0, 1.0, 0.502, 1.0)
const _COL_BG    := Color(0.0, 1.0, 0.502, 0.08)
const _COL_LBL   := Color(0.0, 1.0, 0.502, 0.70)
const _COL_GLOW1 := Color(0.0, 1.0, 0.502, 0.18)
const _COL_GLOW2 := Color(0.0, 1.0, 0.502, 0.07)

# Arc ∩ 240° : de 150° (bas-gauche) jusqu'à 30° (bas-droite) en passant par le HAUT (270°)
# draw_arc(start, end) : en Godot Y-down, l'arc croît de start vers end par angles croissants
# 150° + 240° = 390° = 30° (mod 360) → passe par 270° = visuel HAUT ✓
const _A_BEGIN := 2.6180   # deg_to_rad(150)
const _A_SPAN  := 4.1888   # deg_to_rad(240)

var value: float = 100.0

func set_value(v: float) -> void:
	value = clampf(v, 0.0, 100.0)
	queue_redraw()

func _draw() -> void:
	var cx  := size.x * 0.5
	var cy  := size.y * 0.52          # assure cy - r > 0 : l'arc reste dans le nœud
	var r   := minf(size.x * 0.40, size.y * 0.46)
	var th  := maxf(6.0, r * 0.11)
	var ctr := Vector2(cx, cy)
	var fill_ratio := value / 100.0

	# ── Glow sur portion active seulement ─────────────────────
	if value > 0.5:
		var fill_to := _A_BEGIN + fill_ratio * _A_SPAN
		draw_arc(ctr, r, _A_BEGIN, fill_to, 120, _COL_GLOW2, th + 10.0, true)
		draw_arc(ctr, r, _A_BEGIN, fill_to, 120, _COL_GLOW1, th + 4.0,  true)

	# ── Arc discontinu : 48 segments séparés ─────────────────
	var seg_count := 48
	var slot      := _A_SPAN / float(seg_count)
	var gap_half  := slot * 0.32          # 64 % de gap total, 32 % de chaque côté

	for i in range(seg_count):
		var t_mid   := (float(i) + 0.5) / float(seg_count)
		var a_seg_s := _A_BEGIN + float(i)     * slot + gap_half
		var a_seg_e := _A_BEGIN + float(i + 1) * slot - gap_half
		var active  := t_mid <= fill_ratio
		var col     := _COL_FILL if active else _COL_BG
		draw_arc(ctr, r, a_seg_s, a_seg_e, 3, col, th, true)

	# ── Graduations dans la bande ────────────────────────────
	# Les lignes restent entre le bord interne (r - th/2) et externe (r + th/2)
	var tick_count := 48
	var r_edge_out := r + th * 0.48           # juste à l'intérieur du bord extérieur
	var r_edge_in  := r - th * 0.48           # juste à l'intérieur du bord intérieur
	for i in range(tick_count + 1):
		var t        := float(i) / float(tick_count)
		var angle    := _A_BEGIN + t * _A_SPAN
		var is_major := (i % 6 == 0)
		# Major : traverse toute la bande ; minor : moitié extérieure seulement
		var p_in_r   := r_edge_in if is_major else r + th * 0.04
		var alpha    := 0.95 if is_major else 0.55
		var active   := t <= fill_ratio
		var col      := Color(_COL_FILL, alpha) if active \
						else Color(0.0, 1.0, 0.502, alpha * 0.35)
		var dir   := Vector2(cos(angle), sin(angle))
		draw_line(ctr + dir * p_in_r, ctr + dir * r_edge_out,
				  col, 2.0 if is_major else 1.0, true)

	# ── Texte pourcentage — dans l'ouverture (bas) ────────────
	var fs  := maxi(14, roundi(r * 0.36))
	var txt := "%d%%" % int(value)
	var tw  := FONT_ORB.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(FONT_ORB,
		Vector2(cx - tw * 0.5, cy + r * 0.52 + fs * 0.85),
		txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _COL_FILL)

	# ── Label bas ────────────────────────────────────────────
	var lfs := maxi(8, roundi(r * 0.16))
	var lbl := "ARMOR"
	var lw  := FONT_REG.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
	draw_string(FONT_REG,
		Vector2(cx - lw * 0.5, size.y - 2.0),
		lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, _COL_LBL)
