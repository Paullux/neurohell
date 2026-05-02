extends Node3D

# ============================================================
#  NeuroHell — Decor Scatter
#  Place les décors Rodin aléatoirement dans Level 1
#  Ajoute des StaticBody3D pour bloquer démons + joueur
# ============================================================

const DECOR_SCENES := [
	"res://assets/decors/decor_altar/decor_altar.glb",
	"res://assets/decors/decor_bone_pile/decor_bone_pile.glb",
	"res://assets/decors/decor_broken_arch/decor_broken_arch.glb",
	"res://assets/decors/decor_column/decor_column.glb",
	"res://assets/decors/decor_flesh_pillar/decor_flesh_pillar.glb",
	"res://assets/decors/decor_gargoyle/decor_gargoyle.glb",
	"res://assets/decors/decor_gothic_panel/decor_gothic_panel.glb",
	"res://assets/decors/decor_iron_cage/decor_iron_cage.glb",
	"res://assets/decors/decor_lava_crack/decor_lava_crack.glb",
	"res://assets/decors/decor_ritual_circle/decor_ritual_circle.glb",
]

# Points de spawn par défaut (Level 1 — remplacés par l'export dans les autres niveaux)
const SPAWN_POINTS_DEFAULT := [
	Vector3(-12.0, 0.0, -10.0),
	Vector3( 12.0, 0.0, -10.0),
	Vector3(-8.0,  0.0, -20.0),
	Vector3( 8.0,  0.0, -20.0),
	Vector3(-15.0, 0.0, -30.0),
	Vector3( 15.0, 0.0, -30.0),
	Vector3( 0.0,  0.0, -15.0),
	Vector3(-5.0,  0.0, -40.0),
	Vector3( 5.0,  0.0, -40.0),
	Vector3( 0.0,  0.0, -45.0),
	Vector3(-10.0, 0.0, -35.0),
	Vector3( 10.0, 0.0, -35.0),
]

@export var spawn_points: Array[Vector3] = []  # vide = utilise SPAWN_POINTS_DEFAULT
@export var decors_per_room: int = 2
@export var random_seed: int     = 42

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed

	var points := spawn_points if spawn_points.size() > 0 else SPAWN_POINTS_DEFAULT

	for point: Vector3 in points:
		for _i in range(decors_per_room):
			# Éviter les superpositions
			var offset: Vector3 = Vector3(
				rng.randf_range(-1.5, 1.5),
				0.0,
				rng.randf_range(-1.5, 1.5)
			)
			var pos: Vector3 = point + offset

			# Choisir un décor aléatoire
			var scene_path: String = DECOR_SCENES[rng.randi() % DECOR_SCENES.size()]
			var scene: PackedScene = load(scene_path) as PackedScene
			if scene == null:
				push_warning("DecorScatter: introuvable — " + scene_path)
				continue

			# Créer un StaticBody3D qui wrappe le décor
			var body := StaticBody3D.new()
			body.collision_layer = 1   # monde physique (démons + joueur)
			body.collision_mask  = 0
			body.add_to_group("decor") # exclut l'anti-stuck player/démon

			var decor_instance: Node3D = scene.instantiate()
			decor_instance.position = Vector3.ZERO
			# Rotation aléatoire sur Y
			decor_instance.rotation.y = rng.randf_range(0.0, TAU)

			# Collider box générique (sera affiné à l'import GLB)
			var col := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(1.2, 2.0, 1.2)
			col.shape = box
			col.position = Vector3(0.0, 1.0, 0.0)

			body.add_child(decor_instance)
			body.add_child(col)
			add_child(body)          # dans le tree d'abord
			body.global_position = pos  # ensuite global_position est valide

		if rng.randf() < 0.4:
			break  # variation : certains points ont moins de décors
