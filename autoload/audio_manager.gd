## AudioManager — Procedural sound effects and ambient audio system (autoloaded singleton)
##
## Generates simple synthesized placeholder sounds at runtime using AudioStreamWAV.
## Manages SFX playback via a pool of AudioStreamPlayers and per-area ambient audio
## with crossfading. Connects to EventBus signals to auto-play SFX on game events.
##
## Public API:
##   AudioManager.play_sfx("attack_hit")
##   AudioManager.set_master_volume(0.8)
##   AudioManager.set_sfx_volume(0.7)
##   AudioManager.set_music_volume(0.5)
##   AudioManager.toggle_sfx(true)
##   AudioManager.toggle_music(true)
extends Node

# ── Constants ──────────────────────────────────────────────────────────────────

## Sample rate for all generated audio (low quality for retro feel)
const MIX_RATE: int = 22050

## Number of reusable AudioStreamPlayer nodes for SFX
const SFX_POOL_SIZE: int = 8

## Duration in seconds for ambient crossfade transitions
const AMBIENT_CROSSFADE_DURATION: float = 1.0

## Pi constant for waveform generation
const TAU_CONST: float = TAU

# ── Volume state ──────────────────────────────────────────────────────────────

## Master volume multiplier (0.0 to 1.0)
var master_volume: float = 1.0

## Sound effects volume multiplier (0.0 to 1.0)
var sfx_volume: float = 0.7

## Music / ambient volume multiplier (0.0 to 1.0)
var music_volume: float = 0.5

## Whether SFX playback is enabled
var _sfx_enabled: bool = true

## Whether ambient / music playback is enabled
var _music_enabled: bool = true

# ── SFX pool ──────────────────────────────────────────────────────────────────

## Pool of AudioStreamPlayer nodes for SFX
var _sfx_players: Array[AudioStreamPlayer] = []

## Round-robin index into the SFX pool
var _sfx_index: int = 0

## Pre-generated SFX streams keyed by name
var _sfx_streams: Dictionary = {}

# ── Ambient ───────────────────────────────────────────────────────────────────

## The currently playing ambient player (fading in or sustaining)
var _ambient_player_a: AudioStreamPlayer = null

## The previously playing ambient player (fading out)
var _ambient_player_b: AudioStreamPlayer = null

## Pre-generated ambient streams keyed by area_id
var _ambient_streams: Dictionary = {}

## Current area whose ambient is playing
var _current_ambient_area: String = ""

## Crossfade tween reference (so we can kill it on rapid transitions)
var _crossfade_tween: Tween = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	## Create SFX player pool
	for i: int in range(SFX_POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "SFX_%d" % i
		add_child(player)
		_sfx_players.append(player)

	## Create two ambient players for crossfading
	_ambient_player_a = AudioStreamPlayer.new()
	_ambient_player_a.name = "AmbientA"
	add_child(_ambient_player_a)

	_ambient_player_b = AudioStreamPlayer.new()
	_ambient_player_b.name = "AmbientB"
	add_child(_ambient_player_b)

	## Pre-generate all SFX streams
	_generate_all_sfx()

	## Pre-generate all ambient streams
	_generate_all_ambient()

	## Apply initial volumes from GameState settings
	_apply_initial_volumes()

	## Connect EventBus signals for automatic SFX playback
	_connect_signals()


# ══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ══════════════════════════════════════════════════════════════════════════════

## Play a named sound effect. Picks the next available player from the pool.
func play_sfx(sfx_name: String) -> void:
	if not _sfx_enabled:
		return
	if not _sfx_streams.has(sfx_name):
		push_warning("AudioManager.play_sfx: Unknown SFX '%s'" % sfx_name)
		return

	var player: AudioStreamPlayer = _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE

	player.stream = _sfx_streams[sfx_name] as AudioStreamWAV
	player.volume_db = _get_sfx_db()
	player.play()


## Set the master volume (0.0 to 1.0). Affects all audio output.
func set_master_volume(vol: float) -> void:
	master_volume = clampf(vol, 0.0, 1.0)
	_update_ambient_volume()


## Set the SFX volume (0.0 to 1.0).
func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)


## Set the music / ambient volume (0.0 to 1.0).
func set_music_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	_update_ambient_volume()


## Returns true if SFX playback is enabled.
func is_sfx_enabled() -> bool:
	return _sfx_enabled


## Enable or disable SFX playback.
func toggle_sfx(enabled: bool) -> void:
	_sfx_enabled = enabled
	if not enabled:
		for player: AudioStreamPlayer in _sfx_players:
			player.stop()


## Enable or disable ambient / music playback.
func toggle_music(enabled: bool) -> void:
	_music_enabled = enabled
	if not enabled:
		_ambient_player_a.stop()
		_ambient_player_b.stop()
	else:
		## Resume ambient for the current area
		if _current_ambient_area != "":
			_start_ambient(_current_ambient_area)


# ══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS
# ══════════════════════════════════════════════════════════════════════════════

func _connect_signals() -> void:
	EventBus.hit_landed.connect(_on_hit_landed)
	EventBus.hit_missed.connect(_on_hit_missed)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.item_added.connect(_on_item_added)
	EventBus.player_level_up.connect(_on_player_level_up)
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)
	EventBus.area_entered.connect(_on_area_entered)
	EventBus.settings_changed.connect(_on_settings_changed)


## hit_landed(target: Node, damage: int, is_crit: bool)
func _on_hit_landed(_target: Node, _damage: int, _is_crit: bool) -> void:
	play_sfx("attack_hit")


## hit_missed(target: Node)
func _on_hit_missed(_target: Node) -> void:
	play_sfx("attack_miss")


## enemy_killed(enemy_id: String, enemy_type: String)
func _on_enemy_killed(_enemy_id: String, _enemy_type: String) -> void:
	play_sfx("enemy_die")


## player_damaged(amount: int, source: String)
func _on_player_damaged(_amount: int, _source: String) -> void:
	play_sfx("player_hurt")


## item_added(item_id: String, quantity: int)
func _on_item_added(_item_id: String, _quantity: int) -> void:
	play_sfx("item_pickup")


## player_level_up(skill: String, new_level: int)
func _on_player_level_up(_skill: String, _new_level: int) -> void:
	play_sfx("level_up")


## achievement_unlocked(achievement_id: String)
func _on_achievement_unlocked(_achievement_id: String) -> void:
	play_sfx("achievement")


## area_entered(area_id: String)
func _on_area_entered(area_id: String) -> void:
	_crossfade_ambient(area_id)


## settings_changed(key: String, value: Variant)
func _on_settings_changed(key: String, value: Variant) -> void:
	match key:
		"music_volume":
			set_music_volume(float(value))
		"sfx_volume":
			set_sfx_volume(float(value))


# ══════════════════════════════════════════════════════════════════════════════
# SFX GENERATION
# ══════════════════════════════════════════════════════════════════════════════

## Pre-generate all SFX AudioStreamWAV resources and store them by name.
func _generate_all_sfx() -> void:
	_sfx_streams["attack_hit"] = _generate_attack_hit()
	_sfx_streams["attack_miss"] = _generate_attack_miss()
	_sfx_streams["enemy_die"] = _generate_enemy_die()
	_sfx_streams["player_hurt"] = _generate_player_hurt()
	_sfx_streams["item_pickup"] = _generate_item_pickup()
	_sfx_streams["level_up"] = _generate_level_up()
	_sfx_streams["ability_use"] = _generate_ability_use()
	_sfx_streams["eat_food"] = _generate_eat_food()
	_sfx_streams["button_click"] = _generate_button_click()
	_sfx_streams["achievement"] = _generate_achievement()
	_sfx_streams["error"] = _generate_error()


## attack_hit — Short sharp noise burst (50ms)
func _generate_attack_hit() -> AudioStreamWAV:
	var duration: float = 0.05
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Sharp noise with fast decay envelope
		var envelope: float = 1.0 - progress
		var noise: float = randf_range(-1.0, 1.0)
		## Mix in a bit of 800 Hz tone for impact feel
		var tone: float = sin(TAU_CONST * 800.0 * t)
		var sample: float = (noise * 0.6 + tone * 0.4) * envelope * 0.7
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## attack_miss — Soft whoosh (100ms)
func _generate_attack_miss() -> AudioStreamWAV:
	var duration: float = 0.1
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	for i: int in range(sample_count):
		var progress: float = float(i) / float(sample_count)
		## Filtered noise with bell-shaped envelope (peaks in middle)
		var envelope: float = sin(progress * PI) * 0.4
		var noise: float = randf_range(-1.0, 1.0)
		var sample: float = noise * envelope
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## enemy_die — Descending tone (200ms)
func _generate_enemy_die() -> AudioStreamWAV:
	var duration: float = 0.2
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Frequency sweeps from 600 Hz down to 100 Hz
		var freq: float = lerpf(600.0, 100.0, progress)
		var envelope: float = 1.0 - progress * progress
		var tone: float = sin(TAU_CONST * freq * t)
		var sample: float = tone * envelope * 0.5
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## player_hurt — Low thud (80ms)
func _generate_player_hurt() -> AudioStreamWAV:
	var duration: float = 0.08
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Low frequency thud (120 Hz) with sharp attack
		var envelope: float = (1.0 - progress) * (1.0 - progress)
		var tone: float = sin(TAU_CONST * 120.0 * t)
		var noise: float = randf_range(-1.0, 1.0) * 0.3
		var sample: float = (tone * 0.7 + noise) * envelope * 0.6
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## item_pickup — Rising two-tone chime (150ms)
func _generate_item_pickup() -> AudioStreamWAV:
	var duration: float = 0.15
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var half: int = sample_count / 2

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## First half: 523 Hz (C5), second half: 659 Hz (E5)
		var freq: float = 523.0 if i < half else 659.0
		var local_progress: float = float(i % half) / float(half)
		var envelope: float = (1.0 - local_progress) * 0.8
		## Add quick attack
		if local_progress < 0.1:
			envelope = lerpf(0.0, 0.8, local_progress / 0.1)
		var tone: float = sin(TAU_CONST * freq * t)
		var sample: float = tone * envelope * 0.5
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## level_up — Ascending three-tone fanfare (400ms)
func _generate_level_up() -> AudioStreamWAV:
	var duration: float = 0.4
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var third: int = sample_count / 3

	## C5 -> E5 -> G5 (major chord arpeggio)
	var freqs: Array[float] = [523.0, 659.0, 784.0]

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		## Determine which note segment we're in
		var segment: int = clampi(i / third, 0, 2)
		var local_i: int = i - (segment * third)
		var local_len: int = third if segment < 2 else (sample_count - 2 * third)
		var local_progress: float = float(local_i) / float(local_len)

		var freq: float = freqs[segment]
		## Envelope per note: quick attack, sustain, gentle release
		var envelope: float = 0.7
		if local_progress < 0.05:
			envelope = lerpf(0.0, 0.7, local_progress / 0.05)
		elif local_progress > 0.7:
			envelope = lerpf(0.7, 0.0, (local_progress - 0.7) / 0.3)

		var tone: float = sin(TAU_CONST * freq * t)
		## Add a soft harmonic for richness
		var harmonic: float = sin(TAU_CONST * freq * 2.0 * t) * 0.15
		var sample: float = (tone + harmonic) * envelope * 0.5
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## ability_use — Energy pulse sound (200ms)
func _generate_ability_use() -> AudioStreamWAV:
	var duration: float = 0.2
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Rising frequency pulse: 200 Hz -> 800 Hz
		var freq: float = lerpf(200.0, 800.0, progress)
		var envelope: float = sin(progress * PI) * 0.6
		var tone: float = sin(TAU_CONST * freq * t)
		## Add slight noise for energy feel
		var noise: float = randf_range(-1.0, 1.0) * 0.15
		var sample: float = (tone + noise) * envelope
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## eat_food — Soft crunch (100ms)
func _generate_eat_food() -> AudioStreamWAV:
	var duration: float = 0.1
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	for i: int in range(sample_count):
		var progress: float = float(i) / float(sample_count)
		## Noise bursts that simulate crunching
		var envelope: float = 0.0
		## Three short crunch peaks
		if progress < 0.15:
			envelope = sin(progress / 0.15 * PI) * 0.6
		elif progress > 0.3 and progress < 0.5:
			envelope = sin((progress - 0.3) / 0.2 * PI) * 0.4
		elif progress > 0.6 and progress < 0.8:
			envelope = sin((progress - 0.6) / 0.2 * PI) * 0.25
		var noise: float = randf_range(-1.0, 1.0)
		var sample: float = noise * envelope
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## button_click — Subtle click (30ms)
func _generate_button_click() -> AudioStreamWAV:
	var duration: float = 0.03
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Very short 1500 Hz ping with immediate decay
		var envelope: float = (1.0 - progress) * (1.0 - progress) * (1.0 - progress)
		var tone: float = sin(TAU_CONST * 1500.0 * t)
		var sample: float = tone * envelope * 0.4
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## achievement — Bright ascending chime (500ms)
func _generate_achievement() -> AudioStreamWAV:
	var duration: float = 0.5
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var quarter: int = sample_count / 4

	## C5 -> E5 -> G5 -> C6 (ascending major arpeggio over an octave)
	var freqs: Array[float] = [523.0, 659.0, 784.0, 1047.0]

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var segment: int = clampi(i / quarter, 0, 3)
		var local_i: int = i - (segment * quarter)
		var local_len: int = quarter if segment < 3 else (sample_count - 3 * quarter)
		var local_progress: float = float(local_i) / float(local_len)

		var freq: float = freqs[segment]
		## Bright envelope with quick attack and moderate sustain
		var envelope: float = 0.6
		if local_progress < 0.05:
			envelope = lerpf(0.0, 0.6, local_progress / 0.05)
		elif local_progress > 0.6:
			envelope = lerpf(0.6, 0.1, (local_progress - 0.6) / 0.4)

		var tone: float = sin(TAU_CONST * freq * t)
		var harmonic: float = sin(TAU_CONST * freq * 3.0 * t) * 0.1
		var sample: float = (tone + harmonic) * envelope * 0.5
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## error — Low buzz (100ms)
func _generate_error() -> AudioStreamWAV:
	var duration: float = 0.1
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Low 100 Hz square-ish wave for buzzy feel
		var envelope: float = 1.0 - progress
		var tone: float = sin(TAU_CONST * 100.0 * t)
		## Clip to create harsh square-wave-like buzz
		tone = clampf(tone * 3.0, -1.0, 1.0)
		var sample: float = tone * envelope * 0.4
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


# ══════════════════════════════════════════════════════════════════════════════
# AMBIENT GENERATION
# ══════════════════════════════════════════════════════════════════════════════

## Pre-generate all area ambient loops.
func _generate_all_ambient() -> void:
	_ambient_streams["station-hub"] = _generate_ambient_station_hub()
	_ambient_streams["gathering-grounds"] = _generate_ambient_gathering_grounds()
	_ambient_streams["alien-wastes"] = _generate_ambient_alien_wastes()
	_ambient_streams["the-abyss"] = _generate_ambient_the_abyss()
	_ambient_streams["asteroid-mines"] = _generate_ambient_asteroid_mines()
	_ambient_streams["bio-research-lab"] = _generate_ambient_bio_research_lab()
	## Corrupted variants (glitchy distorted versions)
	_ambient_streams["corrupted-gathering-grounds"] = _generate_ambient_corrupted("gathering-grounds")
	_ambient_streams["corrupted-alien-wastes"] = _generate_ambient_corrupted("alien-wastes")
	_ambient_streams["corrupted-the-abyss"] = _generate_ambient_corrupted("the-abyss")


## station-hub — Low warm hum (80 Hz base)
func _generate_ambient_station_hub() -> AudioStreamWAV:
	var duration: float = 2.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		## Warm 80 Hz hum with gentle 160 Hz harmonic
		var base: float = sin(TAU_CONST * 80.0 * t) * 0.5
		var harmonic: float = sin(TAU_CONST * 160.0 * t) * 0.15
		## Slow amplitude modulation for life
		var mod: float = 0.85 + sin(TAU_CONST * 0.5 * t) * 0.15
		var sample: float = (base + harmonic) * mod * 0.3
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav_loop(data)


## gathering-grounds — Nature-like tones (200-300 Hz soft waves)
func _generate_ambient_gathering_grounds() -> AudioStreamWAV:
	var duration: float = 3.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		## Layered soft tones simulating organic ambience
		var wave_a: float = sin(TAU_CONST * 220.0 * t) * 0.25
		var wave_b: float = sin(TAU_CONST * 277.0 * t) * 0.15
		var wave_c: float = sin(TAU_CONST * 330.0 * t) * 0.1
		## Slow panning / modulation
		var mod: float = 0.7 + sin(TAU_CONST * 0.3 * t) * 0.2 + sin(TAU_CONST * 0.17 * t) * 0.1
		var sample: float = (wave_a + wave_b + wave_c) * mod * 0.25
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav_loop(data)


## alien-wastes — Wind-like noise with low rumble
func _generate_ambient_alien_wastes() -> AudioStreamWAV:
	var duration: float = 2.5
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	## Simple low-pass filter state for wind noise
	var filtered: float = 0.0

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		## Low rumble at 50 Hz
		var rumble: float = sin(TAU_CONST * 50.0 * t) * 0.3
		## Filtered noise for wind
		var noise: float = randf_range(-1.0, 1.0)
		filtered = filtered * 0.95 + noise * 0.05
		## Slow volume swell
		var mod: float = 0.6 + sin(TAU_CONST * 0.25 * t) * 0.3
		var sample: float = (rumble + filtered * 0.5) * mod * 0.25
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav_loop(data)


## the-abyss — Deep unsettling drone (40-60 Hz)
func _generate_ambient_the_abyss() -> AudioStreamWAV:
	var duration: float = 3.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		## Deep sub-bass drone that slowly shifts between 40 and 60 Hz
		var freq: float = 50.0 + sin(TAU_CONST * 0.1 * t) * 10.0
		var drone: float = sin(TAU_CONST * freq * t) * 0.5
		## Dissonant harmonic for unease
		var dissonance: float = sin(TAU_CONST * 57.0 * t) * 0.2
		## Very slow throb
		var mod: float = 0.7 + sin(TAU_CONST * 0.15 * t) * 0.3
		var sample: float = (drone + dissonance) * mod * 0.25
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav_loop(data)


## asteroid-mines — Mechanical rhythmic thumping
func _generate_ambient_asteroid_mines() -> AudioStreamWAV:
	var duration: float = 2.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	## Rhythmic thump every 0.5 seconds (4 thumps in 2s loop)
	var thump_interval: float = 0.5
	var thump_duration: float = 0.08

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		## Background mechanical hum at 100 Hz
		var hum: float = sin(TAU_CONST * 100.0 * t) * 0.15
		## Rhythmic thump
		var thump_phase: float = fmod(t, thump_interval)
		var thump: float = 0.0
		if thump_phase < thump_duration:
			var thump_env: float = 1.0 - (thump_phase / thump_duration)
			thump = sin(TAU_CONST * 60.0 * thump_phase) * thump_env * 0.5
		var sample: float = (hum + thump) * 0.35
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav_loop(data)


## bio-research-lab — Clean electronic hum (440 Hz quiet)
func _generate_ambient_bio_research_lab() -> AudioStreamWAV:
	var duration: float = 2.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		## Clean 440 Hz hum (A4) — sterile laboratory feel
		var tone: float = sin(TAU_CONST * 440.0 * t) * 0.2
		## Soft 880 Hz overtone
		var overtone: float = sin(TAU_CONST * 880.0 * t) * 0.05
		## Very gentle electronic pulse
		var pulse: float = sin(TAU_CONST * 2.0 * t) * 0.1
		var sample: float = (tone + overtone) * (0.8 + pulse) * 0.2
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav_loop(data)


## Corrupted variant — Takes a base area and generates a glitchy distorted version
func _generate_ambient_corrupted(base_area: String) -> AudioStreamWAV:
	## Generate the base ambient first, then distort it
	var duration: float = 2.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	## Base frequency depends on the area
	var base_freq: float = 80.0
	match base_area:
		"gathering-grounds":
			base_freq = 220.0
		"alien-wastes":
			base_freq = 50.0
		"the-abyss":
			base_freq = 45.0

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Base tone
		var tone: float = sin(TAU_CONST * base_freq * t) * 0.4
		## Glitchy frequency modulation
		var glitch_freq: float = base_freq * (1.0 + sin(TAU_CONST * 7.3 * t) * 0.5)
		var glitch: float = sin(TAU_CONST * glitch_freq * t) * 0.3
		## Random static bursts
		var static_burst: float = 0.0
		if fmod(progress * 17.0, 1.0) < 0.1:
			static_burst = randf_range(-1.0, 1.0) * 0.4
		## Distort by clipping
		var raw: float = tone + glitch + static_burst
		var sample: float = clampf(raw * 2.0, -0.8, 0.8) * 0.3
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav_loop(data)


# ══════════════════════════════════════════════════════════════════════════════
# AMBIENT PLAYBACK
# ══════════════════════════════════════════════════════════════════════════════

## Start playing ambient audio for the given area (no crossfade).
func _start_ambient(area_id: String) -> void:
	var stream: AudioStreamWAV = _get_ambient_stream(area_id)
	if stream == null:
		return

	_current_ambient_area = area_id
	_ambient_player_a.stream = stream
	_ambient_player_a.volume_db = _get_ambient_db()
	_ambient_player_a.play()


## Crossfade from current ambient to the new area's ambient.
func _crossfade_ambient(area_id: String) -> void:
	if area_id == _current_ambient_area:
		return

	if not _music_enabled:
		_current_ambient_area = area_id
		return

	var new_stream: AudioStreamWAV = _get_ambient_stream(area_id)
	if new_stream == null:
		## No ambient for this area — just fade out current
		_fade_out_current_ambient()
		_current_ambient_area = area_id
		return

	_current_ambient_area = area_id

	## Kill any existing crossfade tween
	if _crossfade_tween != null and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	## Swap players: B gets the old sound (to fade out), A gets the new sound (to fade in)
	var temp: AudioStreamPlayer = _ambient_player_b
	_ambient_player_b = _ambient_player_a
	_ambient_player_a = temp

	## Set up the new ambient on player A
	_ambient_player_a.stream = new_stream
	_ambient_player_a.volume_db = -80.0
	_ambient_player_a.play()

	## Create crossfade tween
	var target_db: float = _get_ambient_db()
	_crossfade_tween = create_tween()
	_crossfade_tween.set_parallel(true)

	## Fade in new ambient (player A)
	_crossfade_tween.tween_property(
		_ambient_player_a, "volume_db", target_db, AMBIENT_CROSSFADE_DURATION
	)

	## Fade out old ambient (player B)
	if _ambient_player_b.playing:
		_crossfade_tween.tween_property(
			_ambient_player_b, "volume_db", -80.0, AMBIENT_CROSSFADE_DURATION
		)
		_crossfade_tween.chain().tween_callback(_ambient_player_b.stop)


## Fade out whatever ambient is currently playing.
func _fade_out_current_ambient() -> void:
	if _crossfade_tween != null and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	if _ambient_player_a.playing:
		_crossfade_tween = create_tween()
		_crossfade_tween.tween_property(
			_ambient_player_a, "volume_db", -80.0, AMBIENT_CROSSFADE_DURATION
		)
		_crossfade_tween.tween_callback(_ambient_player_a.stop)


## Look up the ambient stream for an area, including corrupted fallback.
func _get_ambient_stream(area_id: String) -> AudioStreamWAV:
	if _ambient_streams.has(area_id):
		return _ambient_streams[area_id] as AudioStreamWAV

	## Check if it's a corrupted area with a known base
	if area_id.begins_with("corrupted-") and _ambient_streams.has(area_id):
		return _ambient_streams[area_id] as AudioStreamWAV

	## Unknown area — no ambient
	return null


# ══════════════════════════════════════════════════════════════════════════════
# AUDIO HELPERS
# ══════════════════════════════════════════════════════════════════════════════

## Create a non-looping AudioStreamWAV from raw 16-bit PCM data.
func _make_wav(data: PackedByteArray) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	wav.data = data
	return wav


## Create a looping AudioStreamWAV from raw 16-bit PCM data.
func _make_wav_loop(data: PackedByteArray) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = data.size() / 2  ## loop_end is in samples, not bytes
	wav.data = data
	return wav


## Calculate the effective SFX volume in decibels.
func _get_sfx_db() -> float:
	var linear: float = master_volume * sfx_volume
	if linear <= 0.0:
		return -80.0
	return linear_to_db(linear)


## Calculate the effective ambient/music volume in decibels.
func _get_ambient_db() -> float:
	var linear: float = master_volume * music_volume
	if linear <= 0.0:
		return -80.0
	return linear_to_db(linear)


## Update the volume of the active ambient player.
func _update_ambient_volume() -> void:
	if _ambient_player_a.playing:
		_ambient_player_a.volume_db = _get_ambient_db()


## Apply initial volumes from GameState settings.
func _apply_initial_volumes() -> void:
	if GameState.settings.has("music_volume"):
		music_volume = float(GameState.settings["music_volume"])
	if GameState.settings.has("sfx_volume"):
		sfx_volume = float(GameState.settings["sfx_volume"])
