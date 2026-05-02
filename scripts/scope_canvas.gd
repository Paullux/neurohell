extends Control

# ============================================================
#  NeuroHell — ScopeCanvas
#  Réplique du canvas HTML drawScope() : vignette noire,
#  cercle central transparent, fils croisés, graduations.
# ============================================================

const FONT_ORB := preload("res://assets/font/Orbitron/static/Orbitron-Regular.ttf")

func _draw() -> void:
	var w  := size.x
	var h  := size.y
	var cx := w * 0.5
	var cy := h * 0.5
	# Rayon du cercle scope (~295 / 540 ≈ 0.272 de la hauteur 1080)
	var r  := minf(w, h) * 0.272

	var col_cx  := Color(0.0, 0.867, 0.733, 0.28)   # fils croisés
	var col_rng := Color(0.0, 0.867, 0.733, 0.55)   # anneau
	var ctr     := Vector2(cx, cy)

	# ── Anneau extérieur ──────────────────────────────────────
	draw_arc(ctr, r, 0.0, TAU, 80, col_rng, 1.5, true)

	# ── Cercle central (point de mire) ────────────────────────
	draw_arc(ctr, r * 0.025, 0.0, TAU, 16, col_rng, 1.0, true)

	# ── Fils croisés ──────────────────────────────────────────
	# Horizontal (interrompu au centre)
	draw_line(Vector2(cx - r + 2, cy), Vector2(cx - r * 0.06, cy), col_cx, 1.0)
	draw_line(Vector2(cx + r * 0.06, cy), Vector2(cx + r - 2, cy), col_cx, 1.0)
	# Vertical
	draw_line(Vector2(cx, cy - r + 2), Vector2(cx, cy - r * 0.06), col_cx, 1.0)
	draw_line(Vector2(cx, cy + r * 0.06), Vector2(cx, cy + r - 2), col_cx, 1.0)

	# ── Graduations horizontales (mil-dot rangefinder) ───────
	# Petites marques verticales le long du fil horizontal, à intervalles réguliers
	var step    := r * 0.22   # espacement entre marques
	var main_h  := r * 0.055  # hauteur grande marque (tous les 2)
	var sub_h   := r * 0.030  # hauteur petite marque
	for i in range(1, 5):     # 4 marques de chaque côté
		var x_off  := float(i) * step
		var is_big := (i % 2 == 0)
		var mh     := main_h if is_big else sub_h
		var alpha  := 0.65 if is_big else 0.40
		var col_m  := Color(0.0, 0.867, 0.733, alpha)
		# Droite
		draw_line(Vector2(cx + x_off, cy - mh), Vector2(cx + x_off, cy + mh), col_m, 1.0)
		# Gauche
		draw_line(Vector2(cx - x_off, cy - mh), Vector2(cx - x_off, cy + mh), col_m, 1.0)

	# ── Zoom label (haut droite) ──────────────────────────────
	draw_string(FONT_ORB,
		Vector2(cx + r - 64, cy - r + 26),
		"× 8.0",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(0.0, 0.867, 0.733, 0.8))
