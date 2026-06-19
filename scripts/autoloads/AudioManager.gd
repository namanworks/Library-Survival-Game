# AudioManager.gd
# Singleton — centralized audio playback with state-driven music.
# Phase 1: Full API stubs. Phase 5 replaces stubs with real audio.
extends Node

# ── Audio buses / players (wired in Phase 5) ───────────────────────────────────
@onready var _music_player_a: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var _music_player_b: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var _sfx_pool: Array[AudioStreamPlayer] = []
@onready var _ambience_player: AudioStreamPlayer = AudioStreamPlayer.new()

var _current_music_track: String = ""
var _sfx_pool_index: int = 0
const SFX_POOL_SIZE: int = 8

# ── Audio resource paths ────────────────────────────────────────────────────────
const MUSIC_TRACKS: Dictionary = {
	"early_game":    "res://assets/audio/music/music_early_game.ogg",
	"mid_game":      "res://assets/audio/music/music_mid_game.ogg",
	"late_game":     "res://assets/audio/music/music_late_game.ogg",
	"boss_overlay":  "res://assets/audio/music/music_boss_overlay.ogg",
	"closing_time":  "res://assets/audio/music/music_closing_time.ogg",
	"main_menu":     "res://assets/audio/music/music_main_menu.ogg",
	"game_over":     "res://assets/audio/music/music_game_over.ogg",
}

const SFX_NAMES: Dictionary = {
	"book_pickup":       "res://assets/audio/sfx/sfx_book_pickup.ogg",
	"book_shelved":      "res://assets/audio/sfx/sfx_book_shelved.ogg",
	"book_dropped":      "res://assets/audio/sfx/sfx_book_dropped.ogg",
	"intercept":         "res://assets/audio/sfx/sfx_child_intercept.ogg",
	"chaos_spike":       "res://assets/audio/sfx/sfx_chaos_spike.ogg",
	"level_up":          "res://assets/audio/sfx/sfx_level_up.ogg",
	"upgrade_select":    "res://assets/audio/sfx/sfx_upgrade_select.ogg",
	"event_warning":     "res://assets/audio/sfx/sfx_event_warning.ogg",
	"boss_incoming":     "res://assets/audio/sfx/sfx_boss_incoming.ogg",
	"game_over":         "res://assets/audio/sfx/sfx_game_over.ogg",
	"win":               "res://assets/audio/sfx/sfx_win.ogg",
	"story_time":        "res://assets/audio/sfx/sfx_story_time.ogg",
	"shush":             "res://assets/audio/sfx/sfx_shush.ogg",
	"parent_call":       "res://assets/audio/sfx/sfx_parent_call.ogg",
	"shortcut_door":     "res://assets/audio/sfx/sfx_shortcut_door.ogg",
	"rare_book_spawn":   "res://assets/audio/sfx/sfx_rare_book_spawn.ogg",
	"cluster_warning":   "res://assets/audio/sfx/sfx_cluster_warning.ogg",
}

func _ready() -> void:
	# Create SFX pool
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)

	_music_player_a.bus = "Music"
	_music_player_b.bus = "Music"
	_ambience_player.bus = "SFX"
	
	add_child(_music_player_a)
	add_child(_music_player_b)
	add_child(_ambience_player)

	# Connect to game state for automatic music transitions
	GameManager.run_started.connect(_on_run_started)
	GameManager.run_ended.connect(_on_run_ended)
	GameManager.run_time_updated.connect(_on_run_time_updated)
	ChaosManager.chaos_changed.connect(_on_chaos_changed)

# ── Public API ─────────────────────────────────────────────────────────────────
func play_sfx(sfx_name: String) -> void:
	if not sfx_name in SFX_NAMES:
		return
	var path: String = SFX_NAMES[sfx_name]
	var stream: AudioStream
	if ResourceLoader.exists(path):
		stream = load(path)
	else:
		stream = _create_placeholder_beep(sfx_name)
		
	var player: AudioStreamPlayer = _sfx_pool[_sfx_pool_index % SFX_POOL_SIZE]
	player.stream = stream
	player.play()
	_sfx_pool_index += 1

func _create_placeholder_beep(seed_name: String) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 44100
	var freq = 200.0 + (posmod(seed_name.hash(), 800))
	var duration = 0.15
	var data = PackedByteArray()
	data.resize(int(44100 * duration))
	for i in range(data.size()):
		var val = 100 if int(i / (44100 / freq)) % 2 == 0 else 155
		data[i] = val
	stream.data = data
	return stream

func play_music(track_name: String, _crossfade: bool = true) -> void:
	if track_name == _current_music_track:
		return
	_current_music_track = track_name
	if not track_name in MUSIC_TRACKS:
		return
	var path: String = MUSIC_TRACKS[track_name]
	if not ResourceLoader.exists(path):
		return # Silently skip missing music so it doesn't drone
		
	var stream: AudioStream = load(path)
	_music_player_a.stream = stream
	_music_player_a.play()

func set_chaos_ambience_level(_chaos_percent: float) -> void:
	## Drives ambient chatter volume from chaos %.  Phase 5: wire to ambience bus.
	pass  # Phase 5 implementation

# ── Private ────────────────────────────────────────────────────────────────────
func _on_run_started() -> void:
	play_music("early_game")

func _on_run_ended(won: bool) -> void:
	if won:
		play_music("closing_time", false)
		play_sfx("win")
	else:
		play_music("game_over", false)
		play_sfx("game_over")

func _on_run_time_updated(_time_string: String) -> void:
	## Drive automatic music transitions based on run time
	var run_time: float = GameManager.run_time
	if run_time < 600.0:
		if _current_music_track != "early_game":
			play_music("early_game")
	elif run_time < 1200.0:
		if _current_music_track != "mid_game":
			play_music("mid_game")
	else:
		if _current_music_track != "late_game":
			play_music("late_game")

func _on_chaos_changed(new_percent: float) -> void:
	set_chaos_ambience_level(new_percent)
