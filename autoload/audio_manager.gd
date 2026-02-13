## AudioManager — Music and sound effect playback (autoloaded singleton)
##
## Manages background music, ambient sounds, and SFX.
## Placeholder for now — will be expanded in Phase 9.
extends Node

# Audio bus names
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

# Active audio players
var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_size: int = 8
var _sfx_index: int = 0

func _ready() -> void:
	# Create music player
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)

	# Create SFX pool (reuse players to avoid instantiation)
	for i in range(_sfx_pool_size):
		var player := AudioStreamPlayer.new()
		player.name = "SFX_%d" % i
		add_child(player)
		_sfx_pool.append(player)

	# Connect to settings changes
	EventBus.settings_changed.connect(_on_settings_changed)

## Play a sound effect by resource path
func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player := _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool_size
	player.stream = stream
	player.volume_db = volume_db
	player.play()

## Play background music (crossfade later)
func play_music(stream: AudioStream, volume_db: float = -10.0) -> void:
	if stream == null:
		return
	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_music_player.play()

## Stop music
func stop_music() -> void:
	_music_player.stop()

## Handle settings changes
func _on_settings_changed(key: String, value: Variant) -> void:
	match key:
		"music_volume":
			_music_player.volume_db = linear_to_db(float(value))
		"sfx_volume":
			for player in _sfx_pool:
				player.volume_db = linear_to_db(float(value))
