extends Node

# ============================================================
#  NeuroHell — Save Manager (autoload: SaveManager)
#  Sauvegardes nommées + horodatées, style FarCry 1.
#  Dossier : user://saves/
#  Format  : JSON, un fichier par sauvegarde.
# ============================================================

const SAVE_DIR := "user://saves/"

# ── Sauvegarde ────────────────────────────────────────────────
func save_game(player: CharacterBody3D, level_scene: String, slot_name: String = "") -> String:
	"""
	Crée une nouvelle sauvegarde et retourne son nom de fichier.
	Retourne "" en cas d'erreur.
	"""
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	var dt := Time.get_datetime_dict_from_system()
	var ts := "%04d%02d%02d_%02d%02d%02d" % [
		dt["year"], dt["month"], dt["day"],
		dt["hour"], dt["minute"], dt["second"]
	]
	var base_name := "save_%s_%s" % [slot_name.strip_edges().replace(" ", "_"), ts] \
		if slot_name.strip_edges() != "" else "save_%s" % ts
	var filename := base_name + ".json"

	var data := {
		"timestamp":        ts,
		"slot_name":        slot_name.strip_edges() if slot_name.strip_edges() != "" else ts,
		"level_scene":      level_scene,
		"player_position":  {
			"x": player.global_position.x,
			"y": player.global_position.y,
			"z": player.global_position.z,
		},
		"player_rotation_y": player.rotation.y,
		"health":           player.health,
		"armor":            player.armor,
		"soul_points":      GameData.soul_points,
		"kills":            GameData.kills,
		"deaths":           GameData.deaths,
		"damage_dealt":     GameData.damage_dealt,
	}

	var path := SAVE_DIR + filename
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] Impossible d'écrire : " + path)
		return ""
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("[SaveManager] Sauvegarde : ", path)
	return filename


# ── Lister les sauvegardes ────────────────────────────────────
func load_saves() -> Array:
	"""
	Retourne un tableau de Dictionaries triés du plus récent au plus ancien.
	Chaque dict inclut la clé "filename" (nom du fichier).
	"""
	var saves: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return saves

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var f := FileAccess.open(SAVE_DIR + fname, FileAccess.READ)
			if f != null:
				var parsed: Variant = JSON.parse_string(f.get_as_text())
				f.close()
				if parsed is Dictionary:
					parsed["filename"] = fname
					saves.append(parsed)
		fname = dir.get_next()
	dir.list_dir_end()

	# Trier du plus récent au plus ancien (comparaison lexicographique du timestamp)
	saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("timestamp", "")) > str(b.get("timestamp", ""))
	)
	return saves


# ── Charger une sauvegarde ────────────────────────────────────
func apply_save(filename: String, player: CharacterBody3D) -> bool:
	"""
	Applique les données d'une sauvegarde sur le joueur.
	Retourne true en cas de succès.
	"""
	var path := SAVE_DIR + filename
	if not FileAccess.file_exists(path):
		push_error("[SaveManager] Fichier introuvable : " + path)
		return false

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()

	if not data is Dictionary:
		push_error("[SaveManager] JSON invalide : " + path)
		return false

	# Position du joueur
	if data.has("player_position"):
		var pos: Dictionary = data["player_position"]
		player.global_position = Vector3(
			float(pos.get("x", 0.0)),
			float(pos.get("y", 2.0)),
			float(pos.get("z", 0.0))
		)
	if data.has("player_rotation_y"):
		player.rotation.y = float(data["player_rotation_y"])

	# Santé & armure
	if data.has("health"):
		player.health = float(data["health"])
		player.health_changed.emit(player.health)
	if data.has("armor"):
		player.armor = float(data["armor"])
		player.armor_changed.emit(player.armor)

	# Statistiques de session
	if data.has("soul_points"):  GameData.soul_points  = int(data["soul_points"])
	if data.has("kills"):        GameData.kills        = int(data["kills"])
	if data.has("deaths"):       GameData.deaths       = int(data["deaths"])
	if data.has("damage_dealt"): GameData.damage_dealt = float(data["damage_dealt"])

	return true


# ── Supprimer une sauvegarde ──────────────────────────────────
func delete_save(filename: String) -> void:
	var path := SAVE_DIR + filename
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[SaveManager] Supprimé : ", path)


# ── Scène associée à une sauvegarde ──────────────────────────
func get_save_scene(filename: String) -> String:
	var path := SAVE_DIR + filename
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary:
		return str(data.get("level_scene", ""))
	return ""
