extends Node

# ============================================================
#  GameOptions  —  Autoload singleton
#  Charge, sauvegarde et applique tous les réglages du jeu.
#  Accès : GameOptions.music_vol, GameOptions.save(), etc.
# ============================================================

signal options_applied

const SAVE_PATH := "user://options.cfg"

# ── Affichage ────────────────────────────────────────────────
var fullscreen:   bool     = false
var resolution:   Vector2i = Vector2i(1920, 1080)
var aspect_ratio: String   = "auto"   # "auto" | "16:9" | "21:9" | "32:9"

# ── Son ──────────────────────────────────────────────────────
var music_on:   bool  = true
var music_vol:  float = 0.8   # 0.0 – 1.0
var sfx_on:     bool  = true
var sfx_vol:    float = 0.8
var voice_on:   bool  = true
var voice_vol:  float = 0.9
var demons_on:  bool  = true
var demons_vol: float = 0.8

# ── Contrôles ────────────────────────────────────────────────
var mouse_sensitivity: float = 0.002   # même unité que player.gd

# Actions reconfigurables (ordre d'affichage dans le menu)
const REBINDABLE := {
	"move_forward":  "Avancer",
	"move_backward": "Reculer",
	"move_left":     "Aller à gauche",
	"move_right":    "Aller à droite",
	"jump":          "Sauter",
	"fire":          "Tirer",
	"aim":           "Viser",
	"torch":         "Torche",
	"pause":         "Pause",
	"weapon_next":   "Arme suivante",
	"weapon_prev":   "Arme précédente",
}

# ── Indices buses (remplis dans _ensure_buses) ───────────────
var bus_music:  int = -1
var bus_sfx:    int = -1
var bus_voice:  int = -1
var bus_demons: int = -1


# ────────────────────────────────────────────────────────────
func _ready() -> void:
	_ensure_buses()
	load_options()
	apply_all()


# ── Buses audio ──────────────────────────────────────────────
func _ensure_buses() -> void:
	for bname: String in ["Music", "SFX", "Voice", "Demons"]:
		if AudioServer.get_bus_index(bname) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, bname)
			AudioServer.set_bus_send(idx, "Master")
	bus_music  = AudioServer.get_bus_index("Music")
	bus_sfx    = AudioServer.get_bus_index("SFX")
	bus_voice  = AudioServer.get_bus_index("Voice")
	bus_demons = AudioServer.get_bus_index("Demons")


# ── Appliquer tous les réglages ───────────────────────────────
func apply_all() -> void:
	_apply_display()
	_apply_audio()
	options_applied.emit()


func _apply_display() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution)
		# Centrer la fenêtre
		var screen_size := DisplayServer.screen_get_size()
		var win_size    := DisplayServer.window_get_size()
		DisplayServer.window_set_position((screen_size - win_size) / 2)


func _apply_audio() -> void:
	if bus_music >= 0:
		AudioServer.set_bus_volume_db(bus_music, linear_to_db(music_vol))
		AudioServer.set_bus_mute(bus_music, not music_on)
	if bus_sfx >= 0:
		AudioServer.set_bus_volume_db(bus_sfx, linear_to_db(sfx_vol))
		AudioServer.set_bus_mute(bus_sfx, not sfx_on)
	if bus_voice >= 0:
		AudioServer.set_bus_volume_db(bus_voice, linear_to_db(voice_vol))
		AudioServer.set_bus_mute(bus_voice, not voice_on)
	if bus_demons >= 0:
		AudioServer.set_bus_volume_db(bus_demons, linear_to_db(demons_vol))
		AudioServer.set_bus_mute(bus_demons, not demons_on)


# ── Sauvegarde ────────────────────────────────────────────────
func save_options() -> void:
	var cfg := ConfigFile.new()

	cfg.set_value("display", "fullscreen",    fullscreen)
	cfg.set_value("display", "resolution_x",  resolution.x)
	cfg.set_value("display", "resolution_y",  resolution.y)
	cfg.set_value("display", "aspect_ratio",  aspect_ratio)

	cfg.set_value("audio", "music_on",    music_on)
	cfg.set_value("audio", "music_vol",   music_vol)
	cfg.set_value("audio", "sfx_on",      sfx_on)
	cfg.set_value("audio", "sfx_vol",     sfx_vol)
	cfg.set_value("audio", "voice_on",    voice_on)
	cfg.set_value("audio", "voice_vol",   voice_vol)
	cfg.set_value("audio", "demons_on",   demons_on)
	cfg.set_value("audio", "demons_vol",  demons_vol)

	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)

	# Touches rebindées
	for action: String in REBINDABLE.keys():
		var events := InputMap.action_get_events(action)
		if not events.is_empty():
			cfg.set_value("bindings", action, _event_to_str(events[0]))

	cfg.save(SAVE_PATH)


# ── Chargement ────────────────────────────────────────────────
func load_options() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return

	fullscreen    = cfg.get_value("display", "fullscreen",   false)
	resolution    = Vector2i(
		cfg.get_value("display", "resolution_x", 1920),
		cfg.get_value("display", "resolution_y", 1080)
	)
	aspect_ratio  = cfg.get_value("display", "aspect_ratio", "auto")

	music_on      = cfg.get_value("audio", "music_on",    true)
	music_vol     = cfg.get_value("audio", "music_vol",   0.8)
	sfx_on        = cfg.get_value("audio", "sfx_on",      true)
	sfx_vol       = cfg.get_value("audio", "sfx_vol",     0.8)
	voice_on      = cfg.get_value("audio", "voice_on",    true)
	voice_vol     = cfg.get_value("audio", "voice_vol",   0.9)
	demons_on     = cfg.get_value("audio", "demons_on",   true)
	demons_vol    = cfg.get_value("audio", "demons_vol",  0.8)

	mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", 0.002)

	for action: String in REBINDABLE.keys():
		var val: String = cfg.get_value("bindings", action, "")
		if val != "":
			var ev := _str_to_event(val)
			if ev:
				InputMap.action_erase_events(action)
				InputMap.action_add_event(action, ev)


# ── Résolutions disponibles ───────────────────────────────────
func get_available_resolutions() -> Array[Vector2i]:
	# Godot 4 n'expose pas la liste des modes vidéo — on filtre une liste
	# standard en ne gardant que les résolutions <= taille réelle de l'écran.
	var screen := DisplayServer.screen_get_size()
	const COMMON: Array = [
		Vector2i(7680, 2160),   # 32:9  8K
		Vector2i(5120, 1440),   # 32:9
		Vector2i(3840, 1080),   # 32:9
		Vector2i(3440, 1440),   # 21:9 UW-QHD
		Vector2i(2560, 1080),   # 21:9 UW-FHD
		Vector2i(3840, 2160),   # 16:9 4K
		Vector2i(2560, 1440),   # 16:9 2K
		Vector2i(1920, 1080),   # 16:9 FHD
		Vector2i(1600,  900),   # 16:9
		Vector2i(1366,  768),   # 16:9
		Vector2i(1280,  720),   # 16:9 HD
	]
	var result: Array[Vector2i] = []
	for r: Vector2i in COMMON:
		if r.x <= screen.x and r.y <= screen.y:
			result.append(r)
	if result.is_empty():
		result.append(screen)   # fallback : résolution native
	return result


# ── Ratio réel de la fenêtre courante ─────────────────────────
func get_window_aspect() -> float:
	var ws := DisplayServer.window_get_size()
	return float(ws.x) / float(ws.y) if ws.y > 0 else 1.777


# ── Helpers sérialisation d'InputEvent ───────────────────────
func _event_to_str(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return "KEY:%d" % (ev as InputEventKey).physical_keycode
	if ev is InputEventMouseButton:
		return "MOUSE:%d" % (ev as InputEventMouseButton).button_index
	if ev is InputEventJoypadButton:
		return "JOY:%d" % (ev as InputEventJoypadButton).button_index
	return ""


func _str_to_event(s: String) -> InputEvent:
	var parts := s.split(":")
	if parts.size() != 2:
		return null
	match parts[0]:
		"KEY":
			var ev := InputEventKey.new()
			ev.physical_keycode = int(parts[1])
			return ev
		"MOUSE":
			var ev := InputEventMouseButton.new()
			ev.button_index = int(parts[1]) as MouseButton
			return ev
		"JOY":
			var ev := InputEventJoypadButton.new()
			ev.button_index = int(parts[1]) as JoyButton
			return ev
	return null


# ── Nom lisible d'un InputEvent ───────────────────────────────
func event_label(ev: InputEvent) -> String:
	if ev == null:
		return "—"
	if ev is InputEventKey:
		var phys := (ev as InputEventKey).physical_keycode
		if phys == 0:
			return "?"
		# Convertir le physical_keycode en keycode logique pour la disposition
		# clavier actuelle (ex: KEY_W → KEY_Z sur AZERTY)
		var logical := DisplayServer.keyboard_get_keycode_from_physical(phys)
		var display_kc := logical if logical != KEY_NONE else phys
		return OS.get_keycode_string(display_kc)
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:    return "Clic gauche"
			MOUSE_BUTTON_RIGHT:   return "Clic droit"
			MOUSE_BUTTON_MIDDLE:  return "Clic milieu"
			MOUSE_BUTTON_WHEEL_UP:   return "Molette ↑"
			MOUSE_BUTTON_WHEEL_DOWN: return "Molette ↓"
			_: return "Souris %d" % (ev as InputEventMouseButton).button_index
	if ev is InputEventJoypadButton:
		return "Manette %d" % (ev as InputEventJoypadButton).button_index
	return ev.as_text()


func current_binding_label(action: String) -> String:
	var events := InputMap.action_get_events(action)
	return event_label(events[0]) if not events.is_empty() else "—"
