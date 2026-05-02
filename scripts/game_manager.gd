extends Node

# ============================================================
#  NeuroHell — Game Manager (autoload ou nœud racine)
#  Gère la musique contextuelle et les événements globaux
# ============================================================

# --- Tracks audio (équivalent musicFiles en JS) ---
const BGM_IDLE   := "res://assets/audio/musics/Cold Circuits of Hell.mp3"
const BGM_COMBAT := "res://assets/audio/musics/Riot Protocol.mp3"
const BGM_DEATH  := "res://assets/audio/musics/Signal Lost.mp3"

enum MusicContext { IDLE, COMBAT, DEATH }

var _current_ctx: MusicContext = MusicContext.IDLE
var _target_ctx:  MusicContext = MusicContext.IDLE

@onready var bgm_player: AudioStreamPlayer = $BGMPlayer

var _player_ref: CharacterBody3D = null
var _demons_ref: Array           = []

func _ready() -> void:
	_play_bgm(MusicContext.IDLE)

func register_player(p: CharacterBody3D) -> void:
	_player_ref = p
	p.health_changed.connect(_on_player_health_changed)
	p.player_died.connect(_on_player_died)

func register_demons(demons: Array) -> void:
	_demons_ref = demons

# ── Boucle de contexte musical ────────────────────────────
func _process(_delta: float) -> void:
	if _player_ref == null: return
	if _player_ref.dead: return

	var in_combat := false
	for d in _demons_ref:
		if is_instance_valid(d) and d.active and not d.dead:
			if _player_ref.global_position.distance_to(d.global_position) < d.spawn_dist + 5.0:
				in_combat = true
				break

	_target_ctx = MusicContext.COMBAT if in_combat else MusicContext.IDLE
	if _target_ctx != _current_ctx:
		_play_bgm(_target_ctx)

func _on_player_health_changed(hp: float) -> void:
	if hp <= 0.0: pass  # géré par player_died

func _on_player_died() -> void:
	_play_bgm(MusicContext.DEATH)

# ── Lecture BGM ───────────────────────────────────────────
func _play_bgm(ctx: MusicContext) -> void:
	if _current_ctx == ctx: return
	_current_ctx = ctx

	var path: String
	match ctx:
		MusicContext.IDLE:   path = BGM_IDLE
		MusicContext.COMBAT: path = BGM_COMBAT
		MusicContext.DEATH:  path = BGM_DEATH

	var stream := load(path)
	if stream == null:
		push_warning("GameManager: audio introuvable — " + path)
		return

	bgm_player.stream = stream
	# loop property exists on AudioStreamMP3 / AudioStreamOGGVorbis, not on the base class
	bgm_player.stream.set("loop", ctx != MusicContext.DEATH)
	bgm_player.play()
