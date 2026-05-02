extends Node

# ============================================================
#  NeuroHell — UpdateChecker
#  Vérifie silencieusement si une nouvelle version est disponible
#  sur GitHub Releases au démarrage du jeu.
#
#  Usage : ajouter ce script en Autoload (Project → Autoloads)
#          Nom de nœud : UpdateChecker
# ============================================================

const GITHUB_API  := "https://api.github.com/repos/Paullux/neurohell/releases/latest"
const CHECK_DELAY := 3.0   # secondes après le démarrage avant d'envoyer la requête

var _http: HTTPRequest = null
var _notif: CanvasLayer = null
var _latest_version: String = ""

func _ready() -> void:
	# Ne rien faire en mode éditeur
	if Engine.is_editor_hint():
		return

	# Délai léger pour ne pas bloquer le chargement de la scène
	await get_tree().create_timer(CHECK_DELAY).timeout
	_check_update()


# ── Requête HTTP ─────────────────────────────────────────────

func _check_update() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_response)

	var headers := PackedStringArray([
		"User-Agent: NeuroHell-UpdateChecker/" + GameVersion.VERSION,
		"Accept: application/vnd.github+json"
	])

	var err := _http.request(GITHUB_API, headers)
	if err != OK:
		push_warning("UpdateChecker: impossible d'envoyer la requête (%d)" % err)
		_http.queue_free()


func _on_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http.queue_free()
	_http = null

	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return

	var text := body.get_string_from_utf8()
	var json  := JSON.parse_string(text)
	if not json or not json.has("tag_name"):
		return

	var latest_tag:   String = json.get("tag_name",    "")
	var published_at: String = json.get("published_at", "")

	# Pas de mise à jour si on est déjà sur la dernière version ou en dev
	if latest_tag == "" or latest_tag == GameVersion.VERSION or GameVersion.VERSION == "dev":
		return

	_latest_version = latest_tag
	_show_notification(latest_tag, published_at)


# ── UI de notification ───────────────────────────────────────

func _show_notification(version: String, iso_date: String) -> void:
	# CanvasLayer sur un layer élevé mais pas au-dessus du HUD (layer 10)
	_notif = CanvasLayer.new()
	_notif.layer = 5
	get_tree().root.add_child(_notif)

	# Panneau de fond
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_bottom = -18.0
	panel.offset_right  = -18.0
	panel.offset_top    = -110.0
	panel.offset_left   = -380.0
	panel.mouse_filter  = Control.MOUSE_FILTER_STOP

	# Style cyberpunk
	var style := StyleBoxFlat.new()
	style.bg_color        = Color(0.04, 0.04, 0.07, 0.92)
	style.border_color    = Color(0.0, 0.85, 1.0, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	_notif.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Titre
	var title := Label.new()
	title.text = "⬆  MISE À JOUR DISPONIBLE"
	title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0, 1.0))
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	# Version + date
	var date_str := _format_date(iso_date)
	var info := Label.new()
	info.text = "Version %s  ·  publiée le %s" % [version, date_str]
	info.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
	info.add_theme_font_size_override("font_size", 12)
	vbox.add_child(info)

	# Bouton fermer
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(row)

	var close_btn := Button.new()
	close_btn.text = "Fermer"
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.pressed.connect(_dismiss_notification)
	row.add_child(close_btn)

	# Auto-dismiss après 12 secondes
	await get_tree().create_timer(12.0).timeout
	if is_instance_valid(_notif):
		_dismiss_notification()


func _dismiss_notification() -> void:
	if is_instance_valid(_notif):
		_notif.queue_free()
		_notif = null


# ── Utilitaire : formater une date ISO 8601 en français ──────

func _format_date(iso: String) -> String:
	if iso.length() < 10:
		return iso
	# "2025-06-15T12:00:00Z" → "15/06/2025"
	var parts := iso.substr(0, 10).split("-")
	if parts.size() == 3:
		return "%s/%s/%s" % [parts[2], parts[1], parts[0]]
	return iso
