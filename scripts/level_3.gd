extends Node3D

# ============================================================
#  NeuroHell — Level 3 Controller (niveau final)
# ============================================================

@onready var player:        CharacterBody3D = $Player
@onready var hud:           CanvasLayer     = $HUD
@onready var game_manager:  Node            = $GameManager
@onready var demons_root:   Node3D          = $Demons
@onready var nav_region:    NavigationRegion3D = $NavigationRegion3D

var _demons: Array = []

func _ready() -> void:
	# Supprimer l'overlay de transition du niveau précédent
	for child in get_tree().root.get_children():
		if child is CanvasLayer and child.layer >= 99:
			child.queue_free()

	# Fondu depuis le blanc
	hud.fade_in_from_white(1.5)

	# Joueur → HUD
	player.health_changed.connect(hud.set_health)
	player.armor_changed.connect(hud.set_armor)
	player.torch_changed.connect(hud.set_torch)
	player.player_died.connect(_on_player_died)
	hud.set_minimap_target(player)

	# Armes → HUD
	var wm: Node = player.get_node_or_null("Head/Camera3D/WeaponHolder/WeaponManager")
	if wm:
		wm.weapon_switched.connect(hud.set_active_weapon)
		wm.ammo_changed.connect(hud.set_ammo)
		wm.scope_toggled.connect(hud.set_scope)

	# Démons
	for demon: Node in demons_root.get_children():
		if demon.has_method("set_player"):
			demon.set_player(player)
			demon.demon_hit_player.connect(_on_demon_hit_player)
			_demons.append(demon)

	game_manager.register_player(player)
	game_manager.register_demons(_demons)

	# Spawn point
	var world: Node3D = nav_region.get_node_or_null("World")
	var spawn: Node3D = null
	if world:
		spawn = world.find_child("Spawn", true, false) as Node3D
	var spawn_pos := Vector3(0, 2, 0)
	if spawn:
		spawn_pos = spawn.global_position + Vector3(0, 0.5, 0)
	player.global_position = spawn_pos
	player._spawn_position = spawn_pos

	# Restaurer vie & armure du niveau précédent
	if GameData.has_saved:
		player.health = GameData.health
		player.armor  = GameData.armor
		player.health_changed.emit(player.health)
		player.armor_changed.emit(player.armor)

	if world:
		_generate_colliders(world)

	# Créer le NavigationMesh s'il n'existe pas, puis cuire
	if nav_region.navigation_mesh == null:
		var nav_mesh := NavigationMesh.new()
		nav_mesh.agent_radius        = 0.4
		nav_mesh.agent_height        = 1.8
		nav_mesh.agent_max_climb     = 0.4
		nav_mesh.agent_max_slope     = 45.0
		nav_mesh.cell_size           = 0.25
		nav_mesh.cell_height         = 0.25
		nav_region.navigation_mesh   = nav_mesh
	nav_region.bake_navigation_mesh.call_deferred()

	hud.show_start_overlay("NIVEAU 3 — NIVEAU FINAL\n[WASD] Déplacer  [ESPACE] Sauter  [1-5] Armes  [CLIC] Tirer  [F] Torche")

	print("Colliders générés : ", _collider_count)

var _collider_count := 0

func _generate_colliders(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D

		# déjà géré → skip
		if mesh_inst.get_parent() is StaticBody3D:
			return

		var n := mesh_inst.name.to_upper()

		# 🔴 DECOR = collider SIMPLE
		if n.begins_with("DECOR_SRC_"):
			_create_simple_collider(mesh_inst)
			return

		# 🟢 STRUCTURE = collider précis
		if n.contains("WALL") \
		or n.contains("FLOOR") \
		or n.contains("CEIL") \
		or n.contains("CORRIDOR") \
		or n.contains("ROOM"):

			mesh_inst.create_trimesh_collision()
			_collider_count += 1

	for child: Node in node.get_children():
		_generate_colliders(child)

func _create_simple_collider(mesh_inst: MeshInstance3D) -> void:
	var body := StaticBody3D.new()
	body.add_to_group("decor")

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()

	var aabb := mesh_inst.get_aabb()
	box.size = aabb.size

	col.shape = box
	col.position = aabb.position + aabb.size * 0.5

	body.add_child(col)
	mesh_inst.add_child(body)


func _on_demon_hit_player(damage: float) -> void:
	player.take_damage(damage)
	hud.show_hit_flash(Color(1.0, 0.0, 0.0, 0.35))

func _on_player_died() -> void:
	hud.show_death_screen()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hud.hide_start_overlay()
