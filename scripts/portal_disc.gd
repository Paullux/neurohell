extends Area3D

# ============================================================
#  NeuroHell — PortalDisc
#  Zone de fin de niveau : tourne au contact/proximité du joueur,
#  flash blanc progressif → changement de scène.
# ============================================================

@export var next_scene: String = "res://scenes/level_2.tscn"
@export var spin_node: NodePath = NodePath("")
@export var spin_speed: float = 140.0
@export var trigger_radius: float = 2.2  # rayon déclenchement
@export var warning_radius: float = 6.0  # rayon message d'approche

var _activated: bool = false
var _spin_target: Node3D = null
var _warning_shown: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = true

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

func _activate_portal(_player: Node3D) -> void:
	if _activated:
		return

	_activated = true

	# Sauvegarder vie & armure avant de changer de scène
	if "health" in _player and "armor" in _player:
		GameData.health    = _player.health
		GameData.armor     = _player.armor
		GameData.has_saved = true

	# Afficher les stats de fin de niveau
	var elapsed := (Time.get_ticks_msec() / 1000.0) - GameData.level_start_time
	var hud := get_tree().current_scene.find_child("HUD", true, false)
	if hud and hud.has_method("show_end_stats"):
		hud.show_end_stats(GameData.kills, GameData.soul_points, elapsed)

	_do_transition()

func _change_scene_safe() -> void:
	print("PORTAL - next_scene = ", next_scene)

	if next_scene == "":
		push_error("PORTAL ERROR: next_scene est vide")
		return

	if not ResourceLoader.exists(next_scene):
		push_error("PORTAL ERROR: scène introuvable : " + next_scene)
		return

	var err := get_tree().change_scene_to_file(next_scene)
	if err != OK:
		push_error("PORTAL ERROR: impossible de charger la scène. Code erreur : " + str(err))

func _do_transition() -> void:
	if _spin_target == null:
		_spin_target = self

	var cl := CanvasLayer.new()
	cl.layer = 99

	if next_scene.ends_with("game_win.tscn"):
		get_tree().current_scene.add_child(cl)
	else:
		get_tree().root.add_child(cl)

	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(1.0, 1.0, 1.0, 0.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(rect)

	var tw := create_tween()
	tw.tween_property(rect, "color:a", 1.0, 1.0) \
		.set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD)

	tw.tween_interval(0.15)
	tw.tween_callback(_change_scene_safe)
