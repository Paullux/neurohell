extends Node

# ============================================================
#  AmbientManager — Ambiance sonore de l'enfer en boucle
#  Autoload : actif pendant le splash d'intro et le gameplay.
#  Silence pendant les cinématiques Sonya et l'écran de victoire.
# ============================================================

const AMBIENT_PATH := "res://assets/audio/sound_fx/hellish_ambient_sounds.ogg"
const VOLUME_DB    := -8.0
const FADE_TIME    := 1.5

var _player: AudioStreamPlayer = null
var _tween:  Tween             = null

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	var stream := load(AMBIENT_PATH) as AudioStreamOggVorbis
	if stream:
		stream.loop = true
	_player.stream    = stream
	_player.volume_db = -80.0
	_player.bus       = "Master"
	add_child(_player)

func play(fade: bool = true) -> void:
	if _player == null or _player.stream == null:
		return
	if not _player.playing:
		_player.play()
	_fade_to(VOLUME_DB, fade)

func stop(fade: bool = true) -> void:
	if _player == null or not _player.playing:
		return
	if fade:
		_fade_to(-80.0, true, true)
	else:
		_player.stop()
		_player.volume_db = -80.0

func _fade_to(target_db: float, animated: bool, stop_after: bool = false) -> void:
	if _tween:
		_tween.kill()
	if not animated:
		_player.volume_db = target_db
		return
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", target_db, FADE_TIME)
	if stop_after:
		_tween.tween_callback(func() -> void:
			_player.stop()
			_player.volume_db = -80.0
		)
