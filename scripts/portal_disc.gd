extends Area3D

# ============================================================
#  NeuroHell — PortalDisc
#  Flow : approche → message → freeze joueur → blanc → stats
#         → clic/touche → changement de scène
# ============================================================

@export var next_scene:     String   = "res://scenes/level_2.tscn"
@export var spin_node:      NodePath = NodePath("")
@export var spin_speed:     float    = 140.0
@export var trigger_radius: float    = 2.8
@export var warning_radius: float    = 6.0

var _activated:    bool    = false
var _spin_target:  Node3D  = null
var _warning_shown: bool   = false
var _waiting_input: bool   = false
var _player_ref:   Node3D  = null
var _cl:           CanvasLayer = null   # canvas du blanc + stats

func _ready() -> void:
	monitoring     = true
	monitorable    = true
	# Joueur sur collision_layer=4 → le mask doit inclure ce bit
	collision_mask = 4
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if spin_node != NodePath(""):
		_spin_target = get_node_or_null(spin_node)

func _process(delta: float) -> void:
	if _activated:
		return
	if _spin_target:
		_spin_target.rotate_y(deg_to_rad(spin_speed) * delta)
	_check_player_distance_xz()

func _check_player_distance_xz() -> void:
	var disc_xz := Vector2(global_position.x, global_position.z)
	for node in get_tree().get_nodes_in_group("player"):
		if not node is Node3D:
			continue
		var player := node as Node3D
		var player_xz := Vector2(player.global_position.x, player.global_position.z)
		var dist := disc_xz.distance_to(player_xz)

		if dist <= trigger_radius:
			_activate_portal(player)
			return

		if not _warning_shown and dist <= warning_radius:
			_warning_shown = true
			var hud := get_tree().current_scene.find_child("HUD", true, false)
			if hud and hud.has_method("show_narration"):
				hud.show_narration("SORTIE DÉTECTÉE — Approchez du disque")

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_activate_portal(body)

func _activate_portal(player: Node3D) -> void:
	if _activated:
		return
	_activated = true
	_player_ref = player

	# Sauvegarder vie & armure
	if "health" in player and "armor" in player:
		GameData.health    = player.health
		GameData.armor     = player.armor
		GameData.has_saved = true

	# Bloquer le joueur
	player.set_physics_process(false)
	player.set_process_input(false)

	# Flash blanc (layer 99)
	_cl = CanvasLayer.new()
	_cl.layer = 99
	if next_scene.ends_with("game_win.tscn"):
		get_tree().current_scene.add_child(_cl)
	else:
		get_tree().root.add_child(_cl)

	var white := ColorRect.new()
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	white.color        = Color(1.0, 1.0, 1.0, 0.0)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cl.add_child(white)

	# Tween rattaché au SceneTree (pas au nœud) → ne s'arrête pas si le nœud est figé
	var tw := get_tree().create_tween()
	tw.tween_property(white, "color:a", 1.0, 1.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_on_white_done)

func _on_white_done() -> void:
	# Afficher les stats par-dessus le blanc (layer 100)
	var elapsed := (Time.get_ticks_msec() / 1000.0) - GameData.level_start_time
	var hud := get_tree().current_scene.find_child("HUD", true, false)
	if hud and hud.has_method("show_end_stats"):
		hud.show_end_stats(GameData.kills, GameData.soul_points, elapsed)
	_waiting_input = true

func _input(event: InputEvent) -> void:
	if not _waiting_input:
		return
	var valid := (event is InputEventKey     and event.pressed) \
			  or (event is InputEventMouseButton and event.pressed)
	if valid:
		_waiting_input = false
		_change_scene_safe()

func _change_scene_safe() -> void:
	if next_scene == "":
		push_error("PORTAL ERROR: next_scene est vide")
		return
	if not ResourceLoader.exists(next_scene):
		push_error("PORTAL ERROR: scène introuvable : " + next_scene)
		return
	var err := get_tree().change_scene_to_file(next_scene)
	if err != OK:
		push_error("PORTAL ERROR: code erreur : " + str(err))
