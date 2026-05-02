extends Control

# ============================================================
#  NeuroHell — TorchGauge
#  Barre de charge segmentée de la torche électrique
# ============================================================

const FONT_ORB := preload("res://assets/font/Orbitron/static/Orbitron-Bold.ttf")
const FONT_REG := preload("res://assets/font/Orbitron/static/Orbitron-Regular.ttf")

const _COL_ON   := Color(1.00, 0.85, 0.04, 1.0)   # jaune électrique
const _COL_BG   := Color(1.00, 0.85, 0.04, 0.10)  # fond éteint
const _COL_DEP  := Color(1.00, 0.28, 0.00, 1.0)   # orange-rouge : épuisée
const _COL_GLOW := Color(1.00, 0.85, 0.04, 0.22)
const _COL_LBL  := Color(1.00, 0.85, 0.04, 0.65)

var charge:   float = 1.0
var depleted: bool  = false
var _blink_t: float = 0.0

func set_value(ratio: float, dep: bool) -> void:
	charge   = clampf(ratio, 0.0, 1.0)
	depleted = dep
	queue_redraw()

func _process(delta: float) -> void:
	if depleted:
		_blink_t += delta
		queue_redraw()

func _draw() -> void:
	var w  := size.x
	var h  := size.y

	var seg_count := 20
	var gap       := 3.0
	var seg_w     := (w - gap * float(seg_count - 1)) / float(seg_count)
	var seg_h     := maxf(10.0, h * 0.32)
	var bar_y     := h * 0.42

	# ── Glow sous les segments actifs ─────────────────────
	if charge > 0.01 and not depleted:
		for i in range(seg_count):
			if float(i) < charge * float(seg_count):
				var gx := float(i) * (seg_w + gap)
				draw_rect(Rect2(gx - 1.5, bar_y - 2.0, seg_w + 3.0, seg_h + 4.0),
					Color(_COL_GLOW, 0.38), true)

	# ── Segments ──────────────────────────────────────────
	var blink_on := fmod(_blink_t, 0.6) < 0.3
	for i in range(seg_count):
		var x      := float(i) * (seg_w + gap)
		var active := float(i) < charge * float(seg_count)
		var col: Color
		if depleted:
			col = Color(_COL_DEP, 0.70 if blink_on else 0.20) if active \
				else Color(_COL_BG, 0.06)
		else:
			col = _COL_ON if active else _COL_BG
		draw_rect(Rect2(x, bar_y, seg_w, seg_h), col, true)

	# ── Pourcentage (au-dessus de la barre) ───────────────
	var pfs  := maxi(10, roundi(h * 0.22))
	var pct  := "%d%%" % int(charge * 100.0)
	var pcol := _COL_ON if not depleted else Color(_COL_DEP, 0.75)
	var pw   := FONT_ORB.get_string_size(pct, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs).x
	draw_string(FONT_ORB,
		Vector2((w - pw) * 0.5, bar_y - 3.0),
		pct, HORIZONTAL_ALIGNMENT_LEFT, -1, pfs, pcol)

	# ── Label (sous la barre) ─────────────────────────────
	var lfs  := maxi(8, roundi(h * 0.16))
	var lbl  := "RECHARGING..." if depleted else "TORCH  [ F ]"
	var lcol := Color(_COL_DEP, 0.80) if depleted else _COL_LBL
	var lw   := FONT_REG.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
	draw_string(FONT_REG,
		Vector2((w - lw) * 0.5, bar_y + seg_h + lfs + 4.0),
		lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, lcol)
