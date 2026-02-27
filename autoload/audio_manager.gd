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

## Sample rate for all generated audio (44.1 kHz for full-quality synthesis)
const MIX_RATE: int = 44100

## Number of reusable AudioStreamPlayer nodes for SFX
const SFX_POOL_SIZE: int = 8

## Duration in seconds for ambient crossfade transitions
const AMBIENT_CROSSFADE_DURATION: float = 2.5

## Pi constant for waveform generation
const TAU_CONST: float = TAU

## Audio bus names
const BUS_SFX: String = "SFX"
const BUS_AMBIENT: String = "Ambient"
const BUS_UI: String = "UI"
const BUS_SFX_REVERB: String = "SFXReverb"

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

## Whether all audio is globally muted
var _is_muted: bool = false

# ── SFX pool ──────────────────────────────────────────────────────────────────

## Pool of AudioStreamPlayer nodes for SFX
var _sfx_players: Array[AudioStreamPlayer] = []

## Round-robin index into the SFX pool
var _sfx_index: int = 0

## Current variant offset (0, 1, 2) — used by generators to shift frequencies
var _variant_offset: int = 0

## Pre-generated SFX streams keyed by name → Array[AudioStreamWAV] (1-3 variants each)
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

## Dedicated player for random ambient one-shot events
var _ambient_event_player: AudioStreamPlayer = null

## Timer for ambient event scheduling
var _ambient_event_timer: float = 0.0

## Next interval before playing an ambient event
var _ambient_event_interval: float = 5.0

## Pre-generated ambient event one-shots keyed by area_id → Array[AudioStreamWAV]
var _ambient_events: Dictionary = {}

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	## Set up audio buses (SFX, Ambient, UI, Reverb send, Master limiter)
	_setup_audio_buses()

	## Create SFX player pool — routed to SFX bus
	for i: int in range(SFX_POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "SFX_%d" % i
		player.bus = BUS_SFX
		add_child(player)
		_sfx_players.append(player)

	## Create two ambient players for crossfading — routed to Ambient bus
	_ambient_player_a = AudioStreamPlayer.new()
	_ambient_player_a.name = "AmbientA"
	_ambient_player_a.bus = BUS_AMBIENT
	add_child(_ambient_player_a)

	_ambient_player_b = AudioStreamPlayer.new()
	_ambient_player_b.name = "AmbientB"
	_ambient_player_b.bus = BUS_AMBIENT
	add_child(_ambient_player_b)

	## Create ambient event player for random one-shot ambient sounds
	_ambient_event_player = AudioStreamPlayer.new()
	_ambient_event_player.name = "AmbientEvent"
	_ambient_event_player.bus = BUS_AMBIENT
	add_child(_ambient_event_player)

	## Pre-generate all SFX streams
	_generate_all_sfx()

	## Pre-generate all ambient streams
	_generate_all_ambient()

	## Pre-generate ambient event one-shots
	_generate_ambient_events()

	## Apply initial volumes from GameState settings
	_apply_initial_volumes()

	## Re-apply volumes after save data is loaded (autoloads _ready before main.gd loads save)
	EventBus.game_loaded.connect(_apply_initial_volumes)

	## Connect EventBus signals for automatic SFX playback
	_connect_signals()


## Create runtime audio buses with effects for spatial depth.
func _setup_audio_buses() -> void:
	## --- SFX bus (sends to SFXReverb + Master) ---
	var sfx_idx: int = AudioServer.bus_count
	AudioServer.add_bus(sfx_idx)
	AudioServer.set_bus_name(sfx_idx, BUS_SFX)
	AudioServer.set_bus_send(sfx_idx, "Master")

	## --- Ambient bus ---
	var amb_idx: int = AudioServer.bus_count
	AudioServer.add_bus(amb_idx)
	AudioServer.set_bus_name(amb_idx, BUS_AMBIENT)
	AudioServer.set_bus_send(amb_idx, "Master")

	## --- UI bus (dry, no reverb) ---
	var ui_idx: int = AudioServer.bus_count
	AudioServer.add_bus(ui_idx)
	AudioServer.set_bus_name(ui_idx, BUS_UI)
	AudioServer.set_bus_send(ui_idx, "Master")

	## --- SFX Reverb send bus ---
	var rev_idx: int = AudioServer.bus_count
	AudioServer.add_bus(rev_idx)
	AudioServer.set_bus_name(rev_idx, BUS_SFX_REVERB)
	AudioServer.set_bus_send(rev_idx, "Master")
	var reverb: AudioEffectReverb = AudioEffectReverb.new()
	reverb.room_size = 0.4
	reverb.damping = 0.6
	reverb.wet = 0.3
	reverb.dry = 0.0
	AudioServer.add_bus_effect(rev_idx, reverb)

	## Add a send effect on SFX bus → SFXReverb bus
	## Godot 4 doesn't have a dedicated send effect, so we route SFX bus send to SFXReverb
	AudioServer.set_bus_send(AudioServer.get_bus_index(BUS_SFX), BUS_SFX_REVERB)

	## --- Master bus limiter ---
	var master_idx: int = AudioServer.get_bus_index("Master")
	var limiter: AudioEffectLimiter = AudioEffectLimiter.new()
	limiter.ceiling_db = -0.5
	limiter.threshold_db = -6.0
	AudioServer.add_bus_effect(master_idx, limiter)


## Process ambient event one-shots on a random timer.
func _process(delta: float) -> void:
	if not _music_enabled or _current_ambient_area == "":
		return
	_ambient_event_timer -= delta
	if _ambient_event_timer <= 0.0:
		_ambient_event_timer = randf_range(4.0, 10.0)
		_play_ambient_event()


## Play a random ambient event one-shot for the current area.
func _play_ambient_event() -> void:
	if not _ambient_events.has(_current_ambient_area):
		return
	var events: Array = _ambient_events[_current_ambient_area] as Array
	if events.is_empty():
		return
	if _ambient_event_player.playing:
		return
	var stream: AudioStreamWAV = events[randi() % events.size()] as AudioStreamWAV
	_ambient_event_player.stream = stream
	_ambient_event_player.volume_db = randf_range(-6.0, -2.0)
	_ambient_event_player.pitch_scale = randf_range(0.9, 1.1)
	_ambient_event_player.play()


# ══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ══════════════════════════════════════════════════════════════════════════════

## UI sounds that should bypass reverb and route to the dry UI bus.
const _UI_SOUNDS: Array[String] = ["button_click", "error"]

## Play a named sound effect. Picks the next available player from the pool.
## Applies random pitch and volume variation for organic feel.
## Selects a random variant if multiple exist for the sound.
func play_sfx(sfx_name: String) -> void:
	if not _sfx_enabled:
		return
	if not _sfx_streams.has(sfx_name):
		push_warning("AudioManager.play_sfx: Unknown SFX '%s'" % sfx_name)
		return

	var player: AudioStreamPlayer = _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % SFX_POOL_SIZE

	## Route UI sounds to the dry UI bus, everything else to SFX (with reverb)
	player.bus = BUS_UI if sfx_name in _UI_SOUNDS else BUS_SFX

	## Select a random variant
	var variants: Array = _sfx_streams[sfx_name] as Array
	var stream: AudioStreamWAV = variants[randi() % variants.size()] as AudioStreamWAV
	player.stream = stream

	## Play-time variation for organic feel
	player.pitch_scale = randf_range(0.95, 1.05)
	player.volume_db = randf_range(-2.0, 1.0)
	player.play()


## Set the master volume (0.0 to 1.0). Affects all audio output via Master bus.
func set_master_volume(vol: float) -> void:
	master_volume = clampf(vol, 0.0, 1.0)
	_apply_bus_volumes()


## Set the SFX volume (0.0 to 1.0). Affects SFX + UI buses.
func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)
	_apply_bus_volumes()


## Set the music / ambient volume (0.0 to 1.0). Affects Ambient bus.
func set_music_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	_apply_bus_volumes()


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


## Check if all audio is globally muted.
func is_muted() -> bool:
	return _is_muted


## Toggle global mute on/off. Persists in GameState.settings.
func toggle_mute() -> void:
	_is_muted = not _is_muted
	toggle_sfx(not _is_muted)
	toggle_music(not _is_muted)
	GameState.settings["muted"] = _is_muted
	EventBus.settings_changed.emit("muted", _is_muted)


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
	EventBus.gathering_started.connect(_on_gathering_started)
	EventBus.gathering_complete.connect(_on_gathering_complete)
	EventBus.crafting_complete.connect(_on_crafting_complete)
	EventBus.quest_completed.connect(_on_quest_completed)
	EventBus.quest_accepted.connect(_on_quest_accepted)
	EventBus.combo_completed.connect(_on_combo_completed)
	EventBus.rare_loot_dropped.connect(_on_rare_loot_dropped)


## hit_landed(target: Node, damage: int, is_crit: bool, attacker: Node)
func _on_hit_landed(_target: Node, _damage: int, is_crit: bool, _attacker: Node) -> void:
	if is_crit:
		play_sfx("attack_crit")
	else:
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


func _on_gathering_started(_skill: String, _node_id: String) -> void:
	play_sfx("gathering_start")


func _on_gathering_complete(_skill: String, _item_id: String) -> void:
	play_sfx("gathering_complete")


func _on_crafting_complete(_recipe_id: String) -> void:
	play_sfx("crafting_complete")


func _on_quest_completed(_quest_id: String) -> void:
	play_sfx("quest_complete")


func _on_quest_accepted(_quest_id: String) -> void:
	play_sfx("quest_accepted")


func _on_combo_completed(_combo_id: String, _combo_name: String) -> void:
	play_sfx("combo_complete")


func _on_rare_loot_dropped(_item_id: String, _position: Vector3) -> void:
	play_sfx("rare_loot")


# ══════════════════════════════════════════════════════════════════════════════
# SFX GENERATION
# ══════════════════════════════════════════════════════════════════════════════

## Pre-generate all SFX AudioStreamWAV resources and store them by name.
## Each entry is an Array of 1-3 variants for random selection.
func _generate_all_sfx() -> void:
	_sfx_streams["attack_hit"] = _make_variants("attack_hit", 3)
	_sfx_streams["attack_crit"] = _make_variants("attack_crit", 2)
	_sfx_streams["attack_miss"] = _make_variants("attack_miss", 2)
	_sfx_streams["enemy_die"] = _make_variants("enemy_die", 2)
	_sfx_streams["player_hurt"] = _make_variants("player_hurt", 2)
	_sfx_streams["item_pickup"] = _make_variants("item_pickup", 2)
	_sfx_streams["level_up"] = [_generate_level_up()]
	_sfx_streams["ability_use"] = _make_variants("ability_use", 2)
	_sfx_streams["eat_food"] = _make_variants("eat_food", 2)
	_sfx_streams["button_click"] = [_generate_button_click()]
	_sfx_streams["achievement"] = [_generate_achievement()]
	_sfx_streams["error"] = [_generate_error()]
	_sfx_streams["telegraph_charge"] = _make_variants("telegraph_charge", 2)
	_sfx_streams["telegraph_impact"] = _make_variants("telegraph_impact", 2)
	_sfx_streams["boss_enrage"] = [_generate_boss_enrage()]
	_sfx_streams["boss_phase"] = [_generate_boss_phase()]
	_sfx_streams["footstep"] = _make_variants("footstep", 3)
	## Phase 5 new SFX
	_sfx_streams["gathering_start"] = _make_variants("gathering_start", 2)
	_sfx_streams["gathering_complete"] = _make_variants("gathering_complete", 2)
	_sfx_streams["crafting_complete"] = [_generate_crafting_complete()]
	_sfx_streams["quest_complete"] = [_generate_quest_complete()]
	_sfx_streams["quest_accepted"] = [_generate_quest_accepted()]
	_sfx_streams["ability_ready"] = [_generate_ability_ready()]
	_sfx_streams["combo_complete"] = [_generate_combo_complete()]
	_sfx_streams["rare_loot"] = [_generate_rare_loot()]


## Generate N variants of a named SFX with subtle parameter shifts.
## Each variant uses a different random seed offset for unique character.
func _make_variants(sfx_name: String, count: int) -> Array:
	var variants: Array = []
	for v: int in range(count):
		_variant_offset = v  ## Used by generators to shift parameters
		match sfx_name:
			"attack_hit": variants.append(_generate_attack_hit())
			"attack_crit": variants.append(_generate_attack_crit())
			"attack_miss": variants.append(_generate_attack_miss())
			"enemy_die": variants.append(_generate_enemy_die())
			"player_hurt": variants.append(_generate_player_hurt())
			"item_pickup": variants.append(_generate_item_pickup())
			"ability_use": variants.append(_generate_ability_use())
			"eat_food": variants.append(_generate_eat_food())
			"telegraph_charge": variants.append(_generate_telegraph_charge())
			"telegraph_impact": variants.append(_generate_telegraph_impact())
			"footstep": variants.append(_generate_footstep())
			"gathering_start": variants.append(_generate_gathering_start())
			"gathering_complete": variants.append(_generate_gathering_complete())
	_variant_offset = 0
	return variants


## attack_hit — Layered impact: sub thud + mid crack + high transient (150ms)
func _generate_attack_hit() -> AudioStreamWAV:
	var duration: float = 0.15
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var freq_shift: float = _variant_offset * 15.0

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Layer 1: Sub thud (60 Hz) — fast exponential decay
		var sub_env: float = exp(-progress * 12.0)
		var sub: float = sin(TAU_CONST * (60.0 + freq_shift) * t) * sub_env * 0.5
		## Layer 2: Mid crack — filtered noise burst (decays faster)
		var crack_env: float = exp(-progress * 18.0)
		var noise: float = randf_range(-1.0, 1.0)
		var crack: float = noise * crack_env * 0.35
		## Layer 3: High transient (3 kHz sine, very fast decay)
		var hi_env: float = exp(-progress * 30.0)
		var hi: float = sin(TAU_CONST * (3000.0 + freq_shift * 5.0) * t) * hi_env * 0.2
		## Layer 4: Mid tone body (400 Hz)
		var mid_env: float = exp(-progress * 10.0)
		var mid: float = sin(TAU_CONST * (400.0 + freq_shift * 2.0) * t) * mid_env * 0.25
		var sample: float = (sub + crack + hi + mid) * 0.7
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## attack_miss — Airy whoosh: bandpass noise sweep 800→400Hz + body tone (150ms)
func _generate_attack_miss() -> AudioStreamWAV:
	var duration: float = 0.15
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var freq_shift: float = _variant_offset * 30.0
	var filtered: float = 0.0

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Bell-shaped envelope peaking at 40%
		var envelope: float = sin(progress * PI) * 0.5
		## Sweeping low-pass filter cutoff (simulated)
		var cutoff_alpha: float = lerpf(0.15, 0.05, progress)
		var noise: float = randf_range(-1.0, 1.0)
		filtered = filtered * (1.0 - cutoff_alpha) + noise * cutoff_alpha
		## Soft body tone at 200 Hz
		var body: float = sin(TAU_CONST * (200.0 + freq_shift) * t) * 0.15 * envelope
		var sample: float = (filtered * 0.6 + body) * envelope
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## enemy_die — Descending sweep 800→60Hz + onset noise + tail (400ms)
func _generate_enemy_die() -> AudioStreamWAV:
	var duration: float = 0.4
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var freq_shift: float = _variant_offset * 20.0

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Frequency sweeps from 800 Hz down to 60 Hz (exponential curve)
		var freq: float = lerpf(800.0 + freq_shift, 60.0, progress * progress)
		var envelope: float = exp(-progress * 4.0)
		var tone: float = sin(TAU_CONST * freq * t) * 0.5
		## Sub harmonic for weight
		var sub: float = sin(TAU_CONST * freq * 0.5 * t) * 0.25
		## Onset noise burst (first 20%)
		var noise_env: float = maxf(0.0, 1.0 - progress * 5.0)
		var noise: float = randf_range(-1.0, 1.0) * noise_env * 0.3
		## Tail resonance
		var tail: float = sin(TAU_CONST * 80.0 * t) * exp(-progress * 2.5) * 0.15
		var sample: float = (tone + sub + noise + tail) * envelope * 0.6
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## player_hurt — Low thud + distorted square + noise burst (120ms)
func _generate_player_hurt() -> AudioStreamWAV:
	var duration: float = 0.12
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var freq_shift: float = _variant_offset * 10.0

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Layer 1: Sub thud (80 Hz)
		var sub_env: float = exp(-progress * 15.0)
		var sub: float = sin(TAU_CONST * (80.0 + freq_shift) * t) * sub_env * 0.5
		## Layer 2: Distorted square wave (150 Hz) — clipped sine
		var sq_env: float = exp(-progress * 10.0)
		var sq_raw: float = sin(TAU_CONST * (150.0 + freq_shift) * t)
		var sq: float = clampf(sq_raw * 2.5, -1.0, 1.0) * sq_env * 0.25
		## Layer 3: Noise burst at onset
		var noise_env: float = exp(-progress * 25.0)
		var noise: float = randf_range(-1.0, 1.0) * noise_env * 0.3
		var sample: float = (sub + sq + noise) * 0.65
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## item_pickup — Two-tone chime with harmonics + high sparkle (200ms)
func _generate_item_pickup() -> AudioStreamWAV:
	var duration: float = 0.2
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var half: int = sample_count / 2
	var freq_shift: float = _variant_offset * 8.0

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## First half: C5 (523 Hz), second half: E5 (659 Hz)
		var freq: float = (523.0 if i < half else 659.0) + freq_shift
		var local_i: int = i % half
		var local_len: int = half if i < half else (sample_count - half)
		var local_progress: float = float(local_i) / float(local_len)
		## ADSR-like envelope per note
		var envelope: float = 0.0
		if local_progress < 0.05:
			envelope = lerpf(0.0, 0.8, local_progress / 0.05)
		else:
			envelope = 0.8 * exp(-(local_progress - 0.05) * 4.0)
		## Fundamental + 3rd harmonic for shimmer
		var tone: float = sin(TAU_CONST * freq * t) * 0.6
		var harm3: float = sin(TAU_CONST * freq * 3.0 * t) * 0.12
		## High sparkle on second note (C7 = 2093 Hz)
		var sparkle: float = 0.0
		if i >= half:
			sparkle = sin(TAU_CONST * 2093.0 * t) * exp(-local_progress * 8.0) * 0.1
		var sample: float = (tone + harm3 + sparkle) * envelope * 0.5
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## level_up — 4-note ascending fanfare with sustained final chord (800ms)
func _generate_level_up() -> AudioStreamWAV:
	var duration: float = 0.8
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	## C5 -> E5 -> G5 -> C6 (ascending major arpeggio)
	var freqs: Array[float] = [523.0, 659.0, 784.0, 1047.0]
	var quarter: int = sample_count / 4

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var segment: int = clampi(i / quarter, 0, 3)
		var local_i: int = i - (segment * quarter)
		var local_len: int = quarter if segment < 3 else (sample_count - 3 * quarter)
		var local_progress: float = float(local_i) / float(local_len)

		var freq: float = freqs[segment]
		## ADSR envelope per note
		var envelope: float = 0.0
		if local_progress < 0.03:
			envelope = lerpf(0.0, 0.7, local_progress / 0.03)
		elif local_progress < 0.6:
			envelope = 0.7
		else:
			envelope = lerpf(0.7, 0.15, (local_progress - 0.6) / 0.4)
		## Last note sustains longer
		if segment == 3 and local_progress > 0.3:
			envelope = 0.7 * exp(-(local_progress - 0.3) * 2.0)

		## Fundamental + octave harmonic + 5th harmonic
		var tone: float = sin(TAU_CONST * freq * t) * 0.5
		var harm2: float = sin(TAU_CONST * freq * 2.0 * t) * 0.15
		var harm3: float = sin(TAU_CONST * freq * 1.5 * t) * 0.1
		var sample: float = (tone + harm2 + harm3) * envelope * 0.55
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## ability_use — Energy pulse: exponential sweep 150→1200Hz + harmonics (300ms)
func _generate_ability_use() -> AudioStreamWAV:
	var duration: float = 0.3
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var freq_shift: float = _variant_offset * 25.0

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Exponential frequency sweep 150→1200 Hz
		var freq: float = (150.0 + freq_shift) * pow(8.0, progress)
		## Bell envelope peaking at 30%
		var envelope: float = sin(clampf(progress * 1.5, 0.0, 1.0) * PI) * 0.6
		## Fundamental + sub-octave harmonic
		var tone: float = sin(TAU_CONST * freq * t) * 0.5
		var sub: float = sin(TAU_CONST * freq * 0.5 * t) * 0.2
		## Filtered noise for energy texture
		var noise: float = randf_range(-1.0, 1.0) * 0.12 * envelope
		var sample: float = (tone + sub + noise) * envelope
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## eat_food — 3 noise bursts with warm undertone (180ms)
func _generate_eat_food() -> AudioStreamWAV:
	var duration: float = 0.18
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var freq_shift: float = _variant_offset * 20.0

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Three crunch peaks at different amplitudes
		var envelope: float = 0.0
		if progress < 0.12:
			envelope = sin(progress / 0.12 * PI) * 0.6
		elif progress > 0.25 and progress < 0.45:
			envelope = sin((progress - 0.25) / 0.2 * PI) * 0.45
		elif progress > 0.55 and progress < 0.75:
			envelope = sin((progress - 0.55) / 0.2 * PI) * 0.3
		var noise: float = randf_range(-1.0, 1.0)
		## Warm undertone (200 Hz) throughout
		var warm: float = sin(TAU_CONST * (200.0 + freq_shift) * t) * 0.1 * (1.0 - progress)
		var sample: float = noise * envelope + warm
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## button_click — Subtle click: 1800Hz sine + tiny noise transient (50ms)
func _generate_button_click() -> AudioStreamWAV:
	var duration: float = 0.05
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Fast cubic decay
		var envelope: float = (1.0 - progress) * (1.0 - progress) * (1.0 - progress)
		var tone: float = sin(TAU_CONST * 1800.0 * t) * 0.4
		## Tiny noise transient at onset
		var noise: float = randf_range(-1.0, 1.0) * exp(-progress * 40.0) * 0.15
		var sample: float = (tone + noise) * envelope
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## achievement — 5-note ascending arpeggio + sparkle (700ms)
func _generate_achievement() -> AudioStreamWAV:
	var duration: float = 0.7
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	## C5 -> E5 -> G5 -> B5 -> C6 (ascending major 7th arpeggio)
	var freqs: Array[float] = [523.0, 659.0, 784.0, 988.0, 1047.0]
	var fifth: int = sample_count / 5

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		var segment: int = clampi(i / fifth, 0, 4)
		var local_i: int = i - (segment * fifth)
		var local_len: int = fifth if segment < 4 else (sample_count - 4 * fifth)
		var local_progress: float = float(local_i) / float(local_len)

		var freq: float = freqs[segment]
		## ADSR per note
		var envelope: float = 0.0
		if local_progress < 0.04:
			envelope = lerpf(0.0, 0.6, local_progress / 0.04)
		elif local_progress < 0.5:
			envelope = 0.6
		else:
			envelope = 0.6 * exp(-(local_progress - 0.5) * 3.0)

		var tone: float = sin(TAU_CONST * freq * t) * 0.45
		var harm3: float = sin(TAU_CONST * freq * 3.0 * t) * 0.08
		## High sparkle layer on last 2 notes
		var sparkle: float = 0.0
		if segment >= 3:
			sparkle = sin(TAU_CONST * freq * 4.0 * t) * 0.06 * exp(-local_progress * 5.0)
		var sample: float = (tone + harm3 + sparkle) * envelope * 0.55
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## error — Two rapid dissonant buzzes (80Hz+87Hz beating) (120ms)
func _generate_error() -> AudioStreamWAV:
	var duration: float = 0.12
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)

	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		var envelope: float = exp(-progress * 6.0)
		## Two close frequencies for dissonant beating
		var tone_a: float = sin(TAU_CONST * 80.0 * t)
		var tone_b: float = sin(TAU_CONST * 87.0 * t)
		## Clip for harsh buzz
		var raw: float = (tone_a + tone_b) * 0.5
		raw = clampf(raw * 2.5, -1.0, 1.0)
		var sample: float = raw * envelope * 0.4
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	return _make_wav(data)


## telegraph_charge — Rising sweep + noise + intensifying 8Hz AM (400ms)
func _generate_telegraph_charge() -> AudioStreamWAV:
	var duration: float = 0.4
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var freq_shift: float = _variant_offset * 20.0
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		var freq: float = lerpf(200.0 + freq_shift, 800.0 + freq_shift, progress * progress)
		## Fade in quickly, sustain
		var envelope: float = minf(progress * 5.0, 1.0)
		## Intensifying 8Hz AM pulsing (gets stronger toward end)
		var am: float = 1.0 - (sin(TAU_CONST * 8.0 * t) * 0.5 + 0.5) * progress * 0.4
		var tone: float = sin(TAU_CONST * freq * t) * 0.5
		var harm: float = sin(TAU_CONST * freq * 1.5 * t) * 0.15
		var noise: float = randf_range(-1.0, 1.0) * 0.15 * progress
		var sample: float = (tone + harm + noise) * envelope * am * 0.55
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	return _make_wav(data)


## telegraph_impact — 50Hz boom + broadband burst + 120Hz ring (250ms)
func _generate_telegraph_impact() -> AudioStreamWAV:
	var duration: float = 0.25
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var freq_shift: float = _variant_offset * 8.0
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Layer 1: Deep sub boom (50 Hz)
		var boom_env: float = exp(-progress * 8.0)
		var boom: float = sin(TAU_CONST * (50.0 + freq_shift) * t) * boom_env * 0.5
		## Layer 2: Broadband noise burst (fast decay)
		var burst_env: float = exp(-progress * 20.0)
		var burst: float = randf_range(-1.0, 1.0) * burst_env * 0.4
		## Layer 3: Resonant ring (120 Hz, slower decay)
		var ring_env: float = exp(-progress * 5.0)
		var ring: float = sin(TAU_CONST * (120.0 + freq_shift * 2.0) * t) * ring_env * 0.2
		var sample: float = (boom + burst + ring) * 0.65
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	return _make_wav(data)


## boss_enrage — Distorted multi-harmonic sweep + noise swell + sub pulse (600ms)
func _generate_boss_enrage() -> AudioStreamWAV:
	var duration: float = 0.6
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		var envelope: float = 1.0 - progress * 0.5
		## Distorted rising sweep with harmonics
		var freq: float = lerpf(80.0, 200.0, progress)
		var h1: float = sin(TAU_CONST * freq * t)
		var h2: float = sin(TAU_CONST * freq * 2.0 * t) * 0.5
		var h3: float = sin(TAU_CONST * freq * 3.0 * t) * 0.3
		var h4: float = sin(TAU_CONST * freq * 5.0 * t) * 0.15
		var raw: float = h1 + h2 + h3 + h4
		raw = clampf(raw * 1.5, -1.0, 1.0)  ## Soft clip distortion
		## Noise swell (grows with progress)
		var noise: float = randf_range(-1.0, 1.0) * progress * 0.35
		## Sub pulse (30 Hz)
		var sub: float = sin(TAU_CONST * 30.0 * t) * 0.2
		var sample: float = (raw * 0.4 + noise + sub) * envelope * 0.5
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	return _make_wav(data)


## boss_phase — Descending minor chord slide with reverb tail (500ms)
func _generate_boss_phase() -> AudioStreamWAV:
	var duration: float = 0.5
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Slow exponential decay with sustained tail
		var envelope: float = exp(-progress * 3.0)
		## Descending minor third: E4 (329.6) → C4 (261.6)
		var freq: float = lerpf(329.6, 261.6, progress)
		var tone1: float = sin(TAU_CONST * freq * t) * 0.4
		## Perfect fifth for richness
		var tone2: float = sin(TAU_CONST * freq * 1.5 * t) * 0.2
		## Minor third (Eb) for dark coloring
		var tone3: float = sin(TAU_CONST * freq * 1.2 * t) * 0.15
		## Sub octave rumble
		var sub: float = sin(TAU_CONST * freq * 0.5 * t) * 0.1
		var sample: float = (tone1 + tone2 + tone3 + sub) * envelope * 0.5
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	return _make_wav(data)


## footstep — Soft thud: 100Hz tone + filtered noise (60ms)
func _generate_footstep() -> AudioStreamWAV:
	var duration: float = 0.06
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var freq_shift: float = _variant_offset * 15.0
	var filtered: float = 0.0
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		var envelope: float = exp(-progress * 12.0)
		## Low tone (100 Hz)
		var tone: float = sin(TAU_CONST * (100.0 + freq_shift) * t) * 0.4
		## Low-pass filtered noise
		var noise: float = randf_range(-1.0, 1.0)
		filtered = filtered * 0.9 + noise * 0.1
		var sample: float = (tone + filtered * 0.3) * envelope * 0.25
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	return _make_wav(data)


## attack_crit — Punchier hit + metallic inharmonic ring (200ms)
func _generate_attack_crit() -> AudioStreamWAV:
	var duration: float = 0.2
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var freq_shift: float = _variant_offset * 20.0
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Base impact (same as attack_hit but louder)
		var sub_env: float = exp(-progress * 10.0)
		var sub: float = sin(TAU_CONST * (65.0 + freq_shift) * t) * sub_env * 0.5
		var crack_env: float = exp(-progress * 16.0)
		var crack: float = randf_range(-1.0, 1.0) * crack_env * 0.4
		## Metallic inharmonic ring (1200Hz + 1800Hz — not harmonically related)
		var ring_env: float = exp(-progress * 6.0)
		var ring1: float = sin(TAU_CONST * (1200.0 + freq_shift * 3.0) * t) * 0.2
		var ring2: float = sin(TAU_CONST * (1800.0 + freq_shift * 4.0) * t) * 0.12
		var ring: float = (ring1 + ring2) * ring_env
		## High transient
		var hi: float = sin(TAU_CONST * 4000.0 * t) * exp(-progress * 35.0) * 0.15
		var sample: float = (sub + crack + ring + hi) * 0.7
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	return _make_wav(data)


## gathering_start — Tool-engaging rising tone (200ms)
func _generate_gathering_start() -> AudioStreamWAV:
	var duration: float = 0.2
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var freq_shift: float = _variant_offset * 15.0
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Rising tone 300→600 Hz
		var freq: float = lerpf(300.0 + freq_shift, 600.0 + freq_shift, progress)
		var envelope: float = sin(progress * PI) * 0.6
		var tone: float = sin(TAU_CONST * freq * t) * 0.5
		## Metallic click at onset
		var click: float = randf_range(-1.0, 1.0) * exp(-progress * 30.0) * 0.3
		var sample: float = (tone + click) * envelope
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	return _make_wav(data)


## gathering_complete — Satisfying descending chime + sparkle (250ms)
func _generate_gathering_complete() -> AudioStreamWAV:
	var duration: float = 0.25
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var freq_shift: float = _variant_offset * 10.0
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Two-note chime: G5 (784) then E5 (659)
		var half: int = sample_count / 2
		var freq: float = (784.0 if i < half else 659.0) + freq_shift
		var local_p: float = float(i % half) / float(half)
		var envelope: float = 0.0
		if local_p < 0.05:
			envelope = lerpf(0.0, 0.7, local_p / 0.05)
		else:
			envelope = 0.7 * exp(-(local_p - 0.05) * 4.0)
		var tone: float = sin(TAU_CONST * freq * t) * 0.5
		var harm: float = sin(TAU_CONST * freq * 2.0 * t) * 0.1
		## Sparkle on second note
		var sparkle: float = 0.0
		if i >= half:
			sparkle = sin(TAU_CONST * 2093.0 * t) * exp(-local_p * 10.0) * 0.08
		var sample: float = (tone + harm + sparkle) * envelope * 0.55
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	return _make_wav(data)


## crafting_complete — Anvil-like ting with inharmonic ring (300ms)
func _generate_crafting_complete() -> AudioStreamWAV:
	var duration: float = 0.3
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Sharp metallic attack
		var attack_env: float = exp(-progress * 20.0)
		var attack: float = randf_range(-1.0, 1.0) * attack_env * 0.4
		## Inharmonic ring (multiple non-integer-related frequencies)
		var ring_env: float = exp(-progress * 4.0)
		var r1: float = sin(TAU_CONST * 1100.0 * t) * 0.3
		var r2: float = sin(TAU_CONST * 1570.0 * t) * 0.2
		var r3: float = sin(TAU_CONST * 2340.0 * t) * 0.1
		## Low body
		var body: float = sin(TAU_CONST * 220.0 * t) * exp(-progress * 8.0) * 0.2
		var sample: float = (attack + (r1 + r2 + r3) * ring_env + body) * 0.55
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	return _make_wav(data)


## quest_complete — Triumphant G4-B4-D5 major arpeggio with sustain (600ms)
func _generate_quest_complete() -> AudioStreamWAV:
	var duration: float = 0.6
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	## G4 (392) -> B4 (494) -> D5 (587) — G major
	var freqs: Array[float] = [392.0, 494.0, 587.0]
	var third: int = sample_count / 3
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		var segment: int = clampi(i / third, 0, 2)
		var local_i: int = i - (segment * third)
		var local_len: int = third if segment < 2 else (sample_count - 2 * third)
		var local_p: float = float(local_i) / float(local_len)
		var freq: float = freqs[segment]
		## ADSR with longer sustain on last note
		var envelope: float = 0.0
		if local_p < 0.04:
			envelope = lerpf(0.0, 0.7, local_p / 0.04)
		elif segment == 2:
			envelope = 0.7 * exp(-local_p * 1.5)
		else:
			envelope = 0.7 * exp(-local_p * 3.0)
		var tone: float = sin(TAU_CONST * freq * t) * 0.45
		var harm: float = sin(TAU_CONST * freq * 2.0 * t) * 0.15
		var fifth: float = sin(TAU_CONST * freq * 1.5 * t) * 0.1
		var sample: float = (tone + harm + fifth) * envelope * 0.55
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	return _make_wav(data)


## quest_accepted — Brief ascending D5-G5 (200ms)
func _generate_quest_accepted() -> AudioStreamWAV:
	var duration: float = 0.2
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var half: int = sample_count / 2
	## D5 (587) -> G5 (784)
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var freq: float = 587.0 if i < half else 784.0
		var local_p: float = float(i % half) / float(half)
		var envelope: float = 0.0
		if local_p < 0.05:
			envelope = lerpf(0.0, 0.6, local_p / 0.05)
		else:
			envelope = 0.6 * exp(-(local_p - 0.05) * 5.0)
		var tone: float = sin(TAU_CONST * freq * t) * 0.5
		var harm: float = sin(TAU_CONST * freq * 2.0 * t) * 0.1
		var sample: float = (tone + harm) * envelope * 0.5
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	return _make_wav(data)


## ability_ready — Quick bright 2kHz ping (100ms)
func _generate_ability_ready() -> AudioStreamWAV:
	var duration: float = 0.1
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		var envelope: float = 0.0
		if progress < 0.03:
			envelope = lerpf(0.0, 0.5, progress / 0.03)
		else:
			envelope = 0.5 * exp(-(progress - 0.03) * 6.0)
		var tone: float = sin(TAU_CONST * 2000.0 * t) * 0.5
		var harm: float = sin(TAU_CONST * 3000.0 * t) * 0.1
		var sample: float = (tone + harm) * envelope
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	return _make_wav(data)


## combo_complete — Rapid ascending arpeggio (400ms)
func _generate_combo_complete() -> AudioStreamWAV:
	var duration: float = 0.4
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	## Rapid C5-E5-G5-C6 arpeggio
	var freqs: Array[float] = [523.0, 659.0, 784.0, 1047.0]
	var quarter: int = sample_count / 4
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var segment: int = clampi(i / quarter, 0, 3)
		var local_i: int = i - (segment * quarter)
		var local_len: int = quarter if segment < 3 else (sample_count - 3 * quarter)
		var local_p: float = float(local_i) / float(local_len)
		var freq: float = freqs[segment]
		var envelope: float = 0.0
		if local_p < 0.03:
			envelope = lerpf(0.0, 0.65, local_p / 0.03)
		else:
			envelope = 0.65 * exp(-(local_p - 0.03) * 4.0)
		var tone: float = sin(TAU_CONST * freq * t) * 0.5
		var harm: float = sin(TAU_CONST * freq * 2.0 * t) * 0.12
		var sample: float = (tone + harm) * envelope * 0.5
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	return _make_wav(data)


## rare_loot — Dramatic low swell + sparkle cascade (500ms)
func _generate_rare_loot() -> AudioStreamWAV:
	var duration: float = 0.5
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Low swell (80 Hz rising to 120 Hz)
		var swell_freq: float = lerpf(80.0, 120.0, progress)
		var swell_env: float = sin(clampf(progress * 2.0, 0.0, 1.0) * PI) * 0.4
		var swell: float = sin(TAU_CONST * swell_freq * t) * swell_env
		## Sparkle cascade — multiple high tones fading in sequence
		var sparkle: float = 0.0
		if progress > 0.2:
			var sp: float = (progress - 0.2) / 0.8
			sparkle += sin(TAU_CONST * 1568.0 * t) * exp(-sp * 3.0) * 0.15
		if progress > 0.35:
			var sp2: float = (progress - 0.35) / 0.65
			sparkle += sin(TAU_CONST * 2093.0 * t) * exp(-sp2 * 3.0) * 0.12
		if progress > 0.5:
			var sp3: float = (progress - 0.5) / 0.5
			sparkle += sin(TAU_CONST * 2637.0 * t) * exp(-sp3 * 3.0) * 0.1
		## Body chord (G4 + B4)
		var chord_env: float = sin(clampf(progress * 1.5, 0.0, 1.0) * PI) * 0.3
		var chord: float = (sin(TAU_CONST * 392.0 * t) + sin(TAU_CONST * 494.0 * t) * 0.7) * chord_env
		var sample: float = (swell + sparkle + chord * 0.3) * 0.55
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	return _make_wav(data)


# ══════════════════════════════════════════════════════════════════════════════
# AMBIENT GENERATION
# ══════════════════════════════════════════════════════════════════════════════

## Apply loop crossfade to PCM data — blends end into beginning for seamless looping.
func _apply_loop_crossfade(data: PackedByteArray, crossfade_samples: int) -> void:
	var total_samples: int = data.size() / 2
	if crossfade_samples > total_samples / 2:
		crossfade_samples = total_samples / 2
	for i: int in range(crossfade_samples):
		var blend: float = float(i) / float(crossfade_samples)
		var end_idx: int = (total_samples - crossfade_samples + i) * 2
		var begin_idx: int = i * 2
		var end_val: float = float(data.decode_s16(end_idx))
		var begin_val: float = float(data.decode_s16(begin_idx))
		## Crossfade: end fades out, beginning fades in
		var mixed: int = clampi(int(end_val * (1.0 - blend) + begin_val * blend), -32768, 32767)
		data.encode_s16(end_idx, mixed)

## Pre-generate all area ambient loops — each area gets a unique stream.
func _generate_all_ambient() -> void:
	_ambient_streams["station-hub"] = _generate_ambient_station_hub()
	_ambient_streams["gathering-grounds"] = _generate_ambient_gathering_grounds()
	_ambient_streams["spore-marshes"] = _generate_ambient_spore_marshes()
	_ambient_streams["hive-tunnels"] = _generate_ambient_hive_tunnels()
	_ambient_streams["fungal-wastes"] = _generate_ambient_fungal_wastes()
	_ambient_streams["stalker-reaches"] = _generate_ambient_stalker_reaches()
	_ambient_streams["the-abyss"] = _generate_ambient_the_abyss()
	_ambient_streams["asteroid-mines"] = _generate_ambient_asteroid_mines()
	_ambient_streams["bio-lab"] = _generate_ambient_bio_lab()
	_ambient_streams["mycelium-hollows"] = _generate_ambient_mycelium_hollows()
	_ambient_streams["solarith-wastes"] = _generate_ambient_solarith_wastes()
	_ambient_streams["void-citadel"] = _generate_ambient_void_citadel()
	_ambient_streams["corrupted-wastes"] = _generate_ambient_corrupted_wastes()
	## Corrupted variants
	_ambient_streams["corrupted-gathering-grounds"] = _generate_ambient_corrupted("gathering-grounds")
	_ambient_streams["corrupted-the-abyss"] = _generate_ambient_corrupted("the-abyss")


## station-hub — Warm hum + electrical buzz + ventilation + beep (12s)
func _generate_ambient_station_hub() -> AudioStreamWAV:
	var duration: float = 12.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var filtered_vent: float = 0.0
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		## Layer 1: Warm 80 Hz power hum + 160 Hz harmonic
		var hum: float = sin(TAU_CONST * 80.0 * t) * 0.3 + sin(TAU_CONST * 160.0 * t) * 0.1
		## Layer 2: Electrical buzz (subtle 120 Hz buzz with harmonics)
		var buzz: float = sin(TAU_CONST * 120.0 * t) * 0.06
		buzz += sin(TAU_CONST * 240.0 * t) * 0.03
		## Layer 3: Ventilation noise (filtered white noise, slow swell)
		var vent_noise: float = randf_range(-1.0, 1.0)
		filtered_vent = filtered_vent * 0.97 + vent_noise * 0.03
		var vent_mod: float = 0.6 + sin(TAU_CONST * 0.15 * t) * 0.3
		var vent: float = filtered_vent * 0.08 * vent_mod
		## Layer 4: Occasional soft beep (every ~4s, very quiet)
		var beep_phase: float = fmod(t, 4.0)
		var beep: float = 0.0
		if beep_phase < 0.06:
			beep = sin(TAU_CONST * 880.0 * beep_phase) * (1.0 - beep_phase / 0.06) * 0.04
		## Overall modulation
		var mod: float = 0.85 + sin(TAU_CONST * 0.08 * t) * 0.1
		var sample: float = (hum + buzz + vent + beep) * mod * 0.35
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	_apply_loop_crossfade(data, int(MIX_RATE * 0.5))
	return _make_wav_loop(data)


## gathering-grounds — Organic drone + wind noise + fauna chirps + drip (15s)
func _generate_ambient_gathering_grounds() -> AudioStreamWAV:
	var duration: float = 15.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var filtered_wind: float = 0.0
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		## Layer 1: Organic minor drone (A3 + C4 + E4)
		var drone_mod: float = 0.8 + sin(TAU_CONST * 0.07 * t) * 0.15
		var drone: float = sin(TAU_CONST * 220.0 * t) * 0.15
		drone += sin(TAU_CONST * 261.6 * t) * 0.1
		drone += sin(TAU_CONST * 330.0 * t) * 0.07
		drone *= drone_mod
		## Layer 2: Wind noise (slow filtered)
		var wind_noise: float = randf_range(-1.0, 1.0)
		filtered_wind = filtered_wind * 0.96 + wind_noise * 0.04
		var wind_swell: float = 0.5 + sin(TAU_CONST * 0.1 * t) * 0.35
		var wind: float = filtered_wind * 0.06 * wind_swell
		## Layer 3: Alien fauna chirps (periodic short tones ~every 3s)
		var chirp: float = 0.0
		var chirp_phase: float = fmod(t, 3.2)
		if chirp_phase < 0.04:
			chirp = sin(TAU_CONST * 1800.0 * chirp_phase) * (1.0 - chirp_phase / 0.04) * 0.03
		var chirp2_phase: float = fmod(t + 1.5, 5.0)
		if chirp2_phase < 0.03:
			chirp += sin(TAU_CONST * 2200.0 * chirp2_phase) * (1.0 - chirp2_phase / 0.03) * 0.02
		## Layer 4: Water drip (every ~5s)
		var drip_phase: float = fmod(t, 5.5)
		var drip: float = 0.0
		if drip_phase < 0.02:
			drip = sin(TAU_CONST * 3000.0 * drip_phase) * (1.0 - drip_phase / 0.02) * 0.025
		var sample: float = (drone + wind + chirp + drip) * 0.4
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	_apply_loop_crossfade(data, int(MIX_RATE * 0.5))
	return _make_wav_loop(data)


## spore-marshes — Marsh rumble + bubbling + spore drift + chirps (15s)
func _generate_ambient_spore_marshes() -> AudioStreamWAV:
	var duration: float = 15.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var filtered: float = 0.0
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		## Layer 1: Marsh rumble (45 Hz + 90 Hz)
		var rumble_mod: float = 0.7 + sin(TAU_CONST * 0.12 * t) * 0.25
		var rumble: float = (sin(TAU_CONST * 45.0 * t) * 0.25 + sin(TAU_CONST * 90.0 * t) * 0.1) * rumble_mod
		## Layer 2: Bubbling bursts (random-ish short pops)
		var bubble: float = 0.0
		var b1: float = fmod(t * 1.7, 1.0)
		if b1 < 0.015:
			bubble += sin(TAU_CONST * 600.0 * b1) * (1.0 - b1 / 0.015) * 0.06
		var b2: float = fmod(t * 0.9 + 0.3, 1.3)
		if b2 < 0.012:
			bubble += sin(TAU_CONST * 800.0 * b2) * (1.0 - b2 / 0.012) * 0.04
		## Layer 3: Spore drift (filtered noise, very slow)
		var noise: float = randf_range(-1.0, 1.0)
		filtered = filtered * 0.97 + noise * 0.03
		var drift: float = filtered * 0.05 * (0.6 + sin(TAU_CONST * 0.06 * t) * 0.3)
		## Layer 4: Insect chirps
		var chirp: float = 0.0
		var cp: float = fmod(t, 2.7)
		if cp < 0.03:
			chirp = sin(TAU_CONST * 3500.0 * cp) * (1.0 - cp / 0.03) * 0.025
		var sample: float = (rumble + bubble + drift + chirp) * 0.4
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	_apply_loop_crossfade(data, int(MIX_RATE * 0.5))
	return _make_wav_loop(data)


## hive-tunnels — Sawtooth drone + chitin clicking + amber hum (12s)
func _generate_ambient_hive_tunnels() -> AudioStreamWAV:
	var duration: float = 12.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		## Layer 1: Sawtooth-ish drone at 70 Hz (sum of harmonics)
		var saw_mod: float = 0.8 + sin(TAU_CONST * 0.09 * t) * 0.15
		var saw: float = sin(TAU_CONST * 70.0 * t) * 0.2
		saw += sin(TAU_CONST * 140.0 * t) * 0.1
		saw += sin(TAU_CONST * 210.0 * t) * 0.06
		saw *= saw_mod
		## Layer 2: Chitin clicking (rapid short clicks)
		var click: float = 0.0
		var ck1: float = fmod(t, 0.8)
		if ck1 < 0.005:
			click += (1.0 - ck1 / 0.005) * 0.04
		var ck2: float = fmod(t + 0.35, 1.1)
		if ck2 < 0.004:
			click += (1.0 - ck2 / 0.004) * 0.03
		## Layer 3: Warm amber hum (200 Hz, gentle)
		var amber: float = sin(TAU_CONST * 200.0 * t) * 0.06 * (0.8 + sin(TAU_CONST * 0.2 * t) * 0.15)
		## Layer 4: Distant scraping
		var scrape_phase: float = fmod(t, 4.5)
		var scrape: float = 0.0
		if scrape_phase > 2.0 and scrape_phase < 2.3:
			var sp: float = (scrape_phase - 2.0) / 0.3
			scrape = randf_range(-1.0, 1.0) * sin(sp * PI) * 0.03
		var sample: float = (saw + click + amber + scrape) * 0.4
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	_apply_loop_crossfade(data, int(MIX_RATE * 0.5))
	return _make_wav_loop(data)


## fungal-wastes — Deep 45Hz drone + mycelium whisper + mushroom pop (12s)
func _generate_ambient_fungal_wastes() -> AudioStreamWAV:
	var duration: float = 12.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var filtered_whisper: float = 0.0
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		## Layer 1: Deep fungal drone (45 Hz) with slow tremolo
		var trem: float = 0.8 + sin(TAU_CONST * 0.3 * t) * 0.15
		var drone: float = sin(TAU_CONST * 45.0 * t) * 0.3 * trem
		drone += sin(TAU_CONST * 67.5 * t) * 0.08  ## Perfect fifth
		## Layer 2: Mycelium whisper (very gentle filtered noise)
		var w_noise: float = randf_range(-1.0, 1.0)
		filtered_whisper = filtered_whisper * 0.98 + w_noise * 0.02
		var whisper: float = filtered_whisper * 0.04 * (0.5 + sin(TAU_CONST * 0.05 * t) * 0.4)
		## Layer 3: Mushroom spore pops (periodic)
		var pop: float = 0.0
		var pp: float = fmod(t, 3.8)
		if pp < 0.008:
			pop = sin(TAU_CONST * 1200.0 * pp) * (1.0 - pp / 0.008) * 0.035
		var pp2: float = fmod(t + 1.9, 5.1)
		if pp2 < 0.006:
			pop += sin(TAU_CONST * 900.0 * pp2) * (1.0 - pp2 / 0.006) * 0.025
		var sample: float = (drone + whisper + pop) * 0.4
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	_apply_loop_crossfade(data, int(MIX_RATE * 0.5))
	return _make_wav_loop(data)


## stalker-reaches — Low rumble + web vibrations + stalker sweeps (12s)
func _generate_ambient_stalker_reaches() -> AudioStreamWAV:
	var duration: float = 12.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		## Layer 1: Deep tense rumble (35 Hz)
		var rumble: float = sin(TAU_CONST * 35.0 * t) * 0.25 * (0.7 + sin(TAU_CONST * 0.08 * t) * 0.25)
		## Layer 2: Web vibrations (high resonant tones, quiet)
		var web: float = sin(TAU_CONST * 1500.0 * t) * 0.015 * (0.3 + sin(TAU_CONST * 0.4 * t) * 0.25)
		web += sin(TAU_CONST * 2200.0 * t) * 0.01 * (0.3 + sin(TAU_CONST * 0.6 * t) * 0.2)
		## Layer 3: Distant stalker sweep (slow frequency sweep every ~6s)
		var sweep_phase: float = fmod(t, 6.5)
		var sweep: float = 0.0
		if sweep_phase > 3.0 and sweep_phase < 4.0:
			var sp: float = (sweep_phase - 3.0)
			var sf: float = lerpf(100.0, 400.0, sp)
			sweep = sin(TAU_CONST * sf * t) * sin(sp * PI) * 0.03
		## Layer 4: Dim haze (filtered noise, very quiet)
		var haze: float = randf_range(-1.0, 1.0) * 0.015
		var sample: float = (rumble + web + sweep + haze) * 0.4
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	_apply_loop_crossfade(data, int(MIX_RATE * 0.5))
	return _make_wav_loop(data)


## the-abyss — Dissonant drones + void wind + heartbeat + cosmic whisper (15s)
func _generate_ambient_the_abyss() -> AudioStreamWAV:
	var duration: float = 15.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var filtered_void: float = 0.0
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		## Layer 1: Dissonant beating drones (35 Hz + 42 Hz)
		var d1: float = sin(TAU_CONST * 35.0 * t) * 0.25
		var d2: float = sin(TAU_CONST * 42.0 * t) * 0.2
		var drone_mod: float = 0.7 + sin(TAU_CONST * 0.05 * t) * 0.25
		var drone: float = (d1 + d2) * drone_mod
		## Layer 2: Void wind (very slow filtered noise)
		var v_noise: float = randf_range(-1.0, 1.0)
		filtered_void = filtered_void * 0.985 + v_noise * 0.015
		var void_wind: float = filtered_void * 0.06 * (0.4 + sin(TAU_CONST * 0.04 * t) * 0.35)
		## Layer 3: Heartbeat pulse (~50bpm = every 1.2s)
		var hb_phase: float = fmod(t, 1.2)
		var heartbeat: float = 0.0
		if hb_phase < 0.08:
			heartbeat = sin(TAU_CONST * 40.0 * hb_phase) * (1.0 - hb_phase / 0.08) * 0.12
		elif hb_phase > 0.15 and hb_phase < 0.22:
			var hb2: float = hb_phase - 0.15
			heartbeat = sin(TAU_CONST * 45.0 * hb2) * (1.0 - hb2 / 0.07) * 0.08
		## Layer 4: Cosmic whisper (very high, barely audible sine sweep)
		var whisper_freq: float = 4000.0 + sin(TAU_CONST * 0.03 * t) * 1500.0
		var whisper: float = sin(TAU_CONST * whisper_freq * t) * 0.008
		var sample: float = (drone + void_wind + heartbeat + whisper) * 0.35
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	_apply_loop_crossfade(data, int(MIX_RATE * 0.5))
	return _make_wav_loop(data)


## asteroid-mines — Mech hum + rhythmic thumps + clangs + grinding (12s)
func _generate_ambient_asteroid_mines() -> AudioStreamWAV:
	var duration: float = 12.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		## Layer 1: Mechanical hum (100 Hz + harmonics)
		var hum: float = sin(TAU_CONST * 100.0 * t) * 0.15
		hum += sin(TAU_CONST * 200.0 * t) * 0.05
		hum *= 0.85 + sin(TAU_CONST * 0.1 * t) * 0.1
		## Layer 2: Rhythmic thumps (every 0.8s, heavy)
		var thump_phase: float = fmod(t, 0.8)
		var thump: float = 0.0
		if thump_phase < 0.06:
			var te: float = 1.0 - thump_phase / 0.06
			thump = sin(TAU_CONST * 55.0 * thump_phase) * te * te * 0.3
		## Layer 3: Metallic clangs (every ~3.5s)
		var clang_phase: float = fmod(t, 3.5)
		var clang: float = 0.0
		if clang_phase < 0.04:
			clang = sin(TAU_CONST * 1800.0 * clang_phase) * (1.0 - clang_phase / 0.04) * 0.04
			clang += sin(TAU_CONST * 2700.0 * clang_phase) * (1.0 - clang_phase / 0.04) * 0.02
		## Layer 4: Grinding noise (periodic)
		var grind_phase: float = fmod(t, 6.0)
		var grind: float = 0.0
		if grind_phase > 2.0 and grind_phase < 3.0:
			var gp: float = (grind_phase - 2.0)
			grind = randf_range(-1.0, 1.0) * sin(gp * PI) * 0.025
		var sample: float = (hum + thump + clang + grind) * 0.4
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	_apply_loop_crossfade(data, int(MIX_RATE * 0.5))
	return _make_wav_loop(data)


## bio-lab — Clean hum + equipment drone + bubbling + data chirps (12s)
func _generate_ambient_bio_lab() -> AudioStreamWAV:
	var duration: float = 12.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		## Layer 1: Clean A4 hum (440 Hz) + octave
		var hum: float = sin(TAU_CONST * 440.0 * t) * 0.1
		hum += sin(TAU_CONST * 880.0 * t) * 0.03
		hum *= 0.85 + sin(TAU_CONST * 0.15 * t) * 0.1
		## Layer 2: Equipment drone (low 60 Hz)
		var equip: float = sin(TAU_CONST * 60.0 * t) * 0.08
		## Layer 3: Bubbling (periodic rapid pops)
		var bubble: float = 0.0
		var bp: float = fmod(t * 2.3, 1.0)
		if bp < 0.008:
			bubble = sin(TAU_CONST * 700.0 * bp) * (1.0 - bp / 0.008) * 0.03
		var bp2: float = fmod(t * 1.7 + 0.5, 1.4)
		if bp2 < 0.006:
			bubble += sin(TAU_CONST * 900.0 * bp2) * (1.0 - bp2 / 0.006) * 0.02
		## Layer 4: Data chirps (short electronic tones every ~4s)
		var chirp: float = 0.0
		var dcp: float = fmod(t, 4.2)
		if dcp < 0.03:
			chirp = sin(TAU_CONST * 1500.0 * dcp) * (1.0 - dcp / 0.03) * 0.025
		var sample: float = (hum + equip + bubble + chirp) * 0.4
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	_apply_loop_crossfade(data, int(MIX_RATE * 0.5))
	return _make_wav_loop(data)


## mycelium-hollows — Deep pulse + spore noise + growth creaks (12s)
func _generate_ambient_mycelium_hollows() -> AudioStreamWAV:
	var duration: float = 12.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var filtered_spore: float = 0.0
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		## Layer 1: Deep pulse (60 Hz with slow AM)
		var pulse_mod: float = 0.6 + sin(TAU_CONST * 0.25 * t) * 0.35
		var pulse: float = sin(TAU_CONST * 60.0 * t) * 0.3 * pulse_mod
		## Layer 2: Spore float noise
		var sp_noise: float = randf_range(-1.0, 1.0)
		filtered_spore = filtered_spore * 0.975 + sp_noise * 0.025
		var spore: float = filtered_spore * 0.05 * (0.5 + sin(TAU_CONST * 0.08 * t) * 0.4)
		## Layer 3: Growth creaks (slow pitch-bend tones)
		var creak: float = 0.0
		var cr_phase: float = fmod(t, 5.0)
		if cr_phase > 2.0 and cr_phase < 2.4:
			var cp: float = (cr_phase - 2.0) / 0.4
			var cr_freq: float = lerpf(200.0, 350.0, cp)
			creak = sin(TAU_CONST * cr_freq * t) * sin(cp * PI) * 0.03
		## Layer 4: Bio-hum (organic vibration)
		var bio: float = sin(TAU_CONST * 90.0 * t) * 0.06 * (0.7 + sin(TAU_CONST * 0.12 * t) * 0.2)
		var sample: float = (pulse + spore + creak + bio) * 0.38
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	_apply_loop_crossfade(data, int(MIX_RATE * 0.5))
	return _make_wav_loop(data)


## solarith-wastes — Heat shimmer drone + sand wind + solar harmonics (15s)
func _generate_ambient_solarith_wastes() -> AudioStreamWAV:
	var duration: float = 15.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var filtered_sand: float = 0.0
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		## Layer 1: Heat shimmer drone (55 Hz with slow phase drift)
		var shimmer_freq: float = 55.0 + sin(TAU_CONST * 0.04 * t) * 3.0
		var shimmer: float = sin(TAU_CONST * shimmer_freq * t) * 0.2
		shimmer += sin(TAU_CONST * shimmer_freq * 2.0 * t) * 0.06
		shimmer *= 0.8 + sin(TAU_CONST * 0.06 * t) * 0.15
		## Layer 2: Sand wind (harsher filtered noise, gusts)
		var sand_noise: float = randf_range(-1.0, 1.0)
		filtered_sand = filtered_sand * 0.94 + sand_noise * 0.06
		var gust: float = 0.5 + sin(TAU_CONST * 0.08 * t) * 0.4
		var sand: float = filtered_sand * 0.07 * gust
		## Layer 3: Solar harmonics (high ethereal tones, very quiet)
		var solar: float = sin(TAU_CONST * 1200.0 * t) * 0.01
		solar += sin(TAU_CONST * 1800.0 * t) * 0.006
		solar *= 0.5 + sin(TAU_CONST * 0.03 * t) * 0.4
		## Layer 4: Distant thunder (every ~8s)
		var thunder_phase: float = fmod(t, 8.5)
		var thunder: float = 0.0
		if thunder_phase > 4.0 and thunder_phase < 4.5:
			var tp: float = (thunder_phase - 4.0) / 0.5
			thunder = sin(TAU_CONST * 30.0 * thunder_phase) * sin(tp * PI) * 0.08
			thunder += randf_range(-1.0, 1.0) * sin(tp * PI) * 0.03
		var sample: float = (shimmer + sand + solar + thunder) * 0.38
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	_apply_loop_crossfade(data, int(MIX_RATE * 0.5))
	return _make_wav_loop(data)


## void-citadel — Beating drones + phase distortion + reality crack pops (15s)
func _generate_ambient_void_citadel() -> AudioStreamWAV:
	var duration: float = 15.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		## Layer 1: Beating drone (40 Hz + 43 Hz = 3 Hz beat frequency)
		var beat_mod: float = 0.7 + sin(TAU_CONST * 0.04 * t) * 0.25
		var d1: float = sin(TAU_CONST * 40.0 * t) * 0.2
		var d2: float = sin(TAU_CONST * 43.0 * t) * 0.2
		var drone: float = (d1 + d2) * beat_mod
		## Layer 2: Phase distortion (FM synthesis, slowly evolving)
		var pm_mod: float = sin(TAU_CONST * 0.07 * t) * 3.0
		var phase_dist: float = sin(TAU_CONST * 55.0 * t + pm_mod * sin(TAU_CONST * 37.0 * t)) * 0.08
		## Layer 3: Reality crack pops (sharp clicks, irregular)
		var crack: float = 0.0
		var cr1: float = fmod(t * 0.7, 1.0)
		if cr1 < 0.003:
			crack += (1.0 - cr1 / 0.003) * 0.06
		var cr2: float = fmod(t * 0.4 + 0.6, 1.7)
		if cr2 < 0.002:
			crack += (1.0 - cr2 / 0.002) * 0.04
		## Layer 4: Spectral whisper (shifting high frequency)
		var spec_freq: float = 3000.0 + sin(TAU_CONST * 0.02 * t) * 2000.0
		var spectral: float = sin(TAU_CONST * spec_freq * t) * 0.006
		var sample: float = (drone + phase_dist + crack + spectral) * 0.38
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	_apply_loop_crossfade(data, int(MIX_RATE * 0.5))
	return _make_wav_loop(data)


## corrupted-wastes — Glitched base + static bursts + FM distortion (12s)
func _generate_ambient_corrupted_wastes() -> AudioStreamWAV:
	var duration: float = 12.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Layer 1: Distorted base drone
		var base_freq: float = 50.0 + sin(TAU_CONST * 0.3 * t) * 15.0
		var base_tone: float = sin(TAU_CONST * base_freq * t) * 0.25
		base_tone = clampf(base_tone * 2.0, -0.3, 0.3)
		## Layer 2: Glitch static bursts
		var static_burst: float = 0.0
		if fmod(progress * 23.0, 1.0) < 0.08:
			static_burst = randf_range(-1.0, 1.0) * 0.15
		## Layer 3: FM distortion (unstable modulation)
		var fm_mod: float = sin(TAU_CONST * 7.3 * t) * 0.5
		var fm: float = sin(TAU_CONST * (base_freq * (1.0 + fm_mod)) * t) * 0.12
		## Layer 4: Erratic pitch shifts
		var glitch_freq: float = base_freq * (1.0 + sin(TAU_CONST * 13.7 * t) * 0.8)
		var glitch: float = sin(TAU_CONST * glitch_freq * t) * 0.08
		var mod: float = 0.7 + sin(TAU_CONST * 0.15 * t) * 0.25
		var sample: float = (base_tone + static_burst + fm + glitch) * mod * 0.35
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	_apply_loop_crossfade(data, int(MIX_RATE * 0.5))
	return _make_wav_loop(data)


## Corrupted variant — Generates a glitchy distorted ambient based on area identity
func _generate_ambient_corrupted(base_area: String) -> AudioStreamWAV:
	var duration: float = 12.0
	var sample_count: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var base_freq: float = 80.0
	match base_area:
		"gathering-grounds":
			base_freq = 220.0
		"the-abyss":
			base_freq = 40.0
	for i: int in range(sample_count):
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(sample_count)
		## Base tone with slow drift
		var tone: float = sin(TAU_CONST * base_freq * t) * 0.3
		## Glitchy FM modulation
		var glitch_freq: float = base_freq * (1.0 + sin(TAU_CONST * 7.3 * t) * 0.5)
		var glitch: float = sin(TAU_CONST * glitch_freq * t) * 0.2
		## Static bursts (irregular)
		var static_burst: float = 0.0
		if fmod(progress * 19.0, 1.0) < 0.08:
			static_burst = randf_range(-1.0, 1.0) * 0.3
		## Distort by clipping
		var raw: float = tone + glitch + static_burst
		var sample: float = clampf(raw * 1.8, -0.7, 0.7) * 0.3
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	_apply_loop_crossfade(data, int(MIX_RATE * 0.5))
	return _make_wav_loop(data)


# ══════════════════════════════════════════════════════════════════════════════
# AMBIENT EVENT GENERATION
# ══════════════════════════════════════════════════════════════════════════════

## Generate short one-shot ambient event sounds per area (2-3 per area, 200-500ms).
func _generate_ambient_events() -> void:
	_ambient_events["station-hub"] = [
		_gen_event_beep(880.0, 0.06),   ## Console beep
		_gen_event_hiss(0.25),           ## Door hiss
		_gen_event_clank(600.0, 0.08),   ## Panel clank
	]
	_ambient_events["gathering-grounds"] = [
		_gen_event_chirp(2400.0, 0.05),  ## Alien bird chirp
		_gen_event_drip(3500.0, 0.03),   ## Water drip
		_gen_event_rustle(0.3),          ## Foliage rustle
	]
	_ambient_events["spore-marshes"] = [
		_gen_event_bubble(500.0, 0.04),  ## Bubble pop
		_gen_event_chirp(3200.0, 0.04),  ## Insect chirp
		_gen_event_squelch(0.15),        ## Squelch
	]
	_ambient_events["hive-tunnels"] = [
		_gen_event_click_burst(0.1),     ## Chitin clicks
		_gen_event_scrape(0.3),          ## Scraping
		_gen_event_hum_pulse(150.0, 0.2), ## Hive pulse
	]
	_ambient_events["fungal-wastes"] = [
		_gen_event_pop(1000.0, 0.015),   ## Spore pop
		_gen_event_creak(0.35),          ## Growth creak
		_gen_event_drip(2500.0, 0.025),  ## Condensation drip
	]
	_ambient_events["stalker-reaches"] = [
		_gen_event_scrape(0.4),          ## Claw scrape
		_gen_event_web_twang(0.2),       ## Web twang
	]
	_ambient_events["the-abyss"] = [
		_gen_event_void_groan(0.5),      ## Void groan
		_gen_event_crack(0.08),          ## Reality crack
	]
	_ambient_events["asteroid-mines"] = [
		_gen_event_clank(1200.0, 0.06),  ## Pickaxe clang
		_gen_event_rumble(0.3),          ## Rock tumble
		_gen_event_hiss(0.15),           ## Steam vent
	]
	_ambient_events["bio-lab"] = [
		_gen_event_beep(1200.0, 0.04),   ## Equipment beep
		_gen_event_bubble(800.0, 0.03),  ## Lab bubbling
		_gen_event_chirp(1500.0, 0.03),  ## Data chirp
	]
	_ambient_events["mycelium-hollows"] = [
		_gen_event_pop(900.0, 0.02),     ## Spore burst
		_gen_event_creak(0.3),           ## Growth creak
	]
	_ambient_events["solarith-wastes"] = [
		_gen_event_rumble(0.4),          ## Distant thunder
		_gen_event_hiss(0.2),            ## Sand gust
	]
	_ambient_events["void-citadel"] = [
		_gen_event_crack(0.06),          ## Reality crack
		_gen_event_void_groan(0.4),      ## Void moan
	]
	_ambient_events["corrupted-wastes"] = [
		_gen_event_glitch(0.15),         ## Digital glitch
		_gen_event_crack(0.05),          ## Static crack
	]


## Short beep event
func _gen_event_beep(freq: float, dur: float) -> AudioStreamWAV:
	var sc: int = int(MIX_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sc * 2)
	for i: int in range(sc):
		var t: float = float(i) / float(MIX_RATE)
		var p: float = float(i) / float(sc)
		var env: float = sin(p * PI) * 0.3
		var s: float = sin(TAU_CONST * freq * t) * env
		data.encode_s16(i * 2, clampi(int(s * 32767.0), -32768, 32767))
	return _make_wav(data)


## Door/steam hiss event
func _gen_event_hiss(dur: float) -> AudioStreamWAV:
	var sc: int = int(MIX_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sc * 2)
	var flt: float = 0.0
	for i: int in range(sc):
		var p: float = float(i) / float(sc)
		var env: float = sin(p * PI) * 0.2
		var n: float = randf_range(-1.0, 1.0)
		flt = flt * 0.85 + n * 0.15
		data.encode_s16(i * 2, clampi(int(flt * env * 32767.0), -32768, 32767))
	return _make_wav(data)


## Metallic clank event
func _gen_event_clank(freq: float, dur: float) -> AudioStreamWAV:
	var sc: int = int(MIX_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sc * 2)
	for i: int in range(sc):
		var t: float = float(i) / float(MIX_RATE)
		var p: float = float(i) / float(sc)
		var env: float = exp(-p * 15.0) * 0.35
		var s: float = sin(TAU_CONST * freq * t) * 0.5 + sin(TAU_CONST * freq * 2.7 * t) * 0.2
		data.encode_s16(i * 2, clampi(int(s * env * 32767.0), -32768, 32767))
	return _make_wav(data)


## Bird/insect chirp event
func _gen_event_chirp(freq: float, dur: float) -> AudioStreamWAV:
	var sc: int = int(MIX_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sc * 2)
	for i: int in range(sc):
		var t: float = float(i) / float(MIX_RATE)
		var p: float = float(i) / float(sc)
		var f: float = freq * (1.0 + p * 0.3)
		var env: float = sin(p * PI) * 0.2
		data.encode_s16(i * 2, clampi(int(sin(TAU_CONST * f * t) * env * 32767.0), -32768, 32767))
	return _make_wav(data)


## Water drip event
func _gen_event_drip(freq: float, dur: float) -> AudioStreamWAV:
	var sc: int = int(MIX_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sc * 2)
	for i: int in range(sc):
		var t: float = float(i) / float(MIX_RATE)
		var p: float = float(i) / float(sc)
		var env: float = exp(-p * 20.0) * 0.25
		data.encode_s16(i * 2, clampi(int(sin(TAU_CONST * freq * t) * env * 32767.0), -32768, 32767))
	return _make_wav(data)


## Foliage rustle event
func _gen_event_rustle(dur: float) -> AudioStreamWAV:
	var sc: int = int(MIX_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sc * 2)
	var flt: float = 0.0
	for i: int in range(sc):
		var p: float = float(i) / float(sc)
		var env: float = sin(p * PI) * 0.15
		var n: float = randf_range(-1.0, 1.0)
		flt = flt * 0.92 + n * 0.08
		data.encode_s16(i * 2, clampi(int(flt * env * 32767.0), -32768, 32767))
	return _make_wav(data)


## Bubble pop event
func _gen_event_bubble(freq: float, dur: float) -> AudioStreamWAV:
	var sc: int = int(MIX_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sc * 2)
	for i: int in range(sc):
		var t: float = float(i) / float(MIX_RATE)
		var p: float = float(i) / float(sc)
		var f: float = freq * (1.0 - p * 0.3)
		var env: float = exp(-p * 12.0) * 0.2
		data.encode_s16(i * 2, clampi(int(sin(TAU_CONST * f * t) * env * 32767.0), -32768, 32767))
	return _make_wav(data)


## Squelch event
func _gen_event_squelch(dur: float) -> AudioStreamWAV:
	var sc: int = int(MIX_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sc * 2)
	var flt: float = 0.0
	for i: int in range(sc):
		var t: float = float(i) / float(MIX_RATE)
		var p: float = float(i) / float(sc)
		var env: float = exp(-p * 8.0) * 0.2
		var n: float = randf_range(-1.0, 1.0)
		flt = flt * 0.9 + n * 0.1
		var tone: float = sin(TAU_CONST * 200.0 * t) * 0.3
		data.encode_s16(i * 2, clampi(int((flt + tone) * env * 32767.0), -32768, 32767))
	return _make_wav(data)


## Click burst event
func _gen_event_click_burst(dur: float) -> AudioStreamWAV:
	var sc: int = int(MIX_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sc * 2)
	for i: int in range(sc):
		var p: float = float(i) / float(sc)
		var click: float = 0.0
		if fmod(p * 8.0, 1.0) < 0.05:
			click = randf_range(-1.0, 1.0) * 0.25
		data.encode_s16(i * 2, clampi(int(click * 32767.0), -32768, 32767))
	return _make_wav(data)


## Scraping event
func _gen_event_scrape(dur: float) -> AudioStreamWAV:
	var sc: int = int(MIX_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sc * 2)
	var flt: float = 0.0
	for i: int in range(sc):
		var t: float = float(i) / float(MIX_RATE)
		var p: float = float(i) / float(sc)
		var env: float = sin(p * PI) * 0.15
		var n: float = randf_range(-1.0, 1.0)
		flt = flt * 0.8 + n * 0.2
		var tone: float = sin(TAU_CONST * lerpf(400.0, 800.0, p) * t) * 0.1
		data.encode_s16(i * 2, clampi(int((flt * 0.5 + tone) * env * 32767.0), -32768, 32767))
	return _make_wav(data)


## Hive hum pulse event
func _gen_event_hum_pulse(freq: float, dur: float) -> AudioStreamWAV:
	var sc: int = int(MIX_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sc * 2)
	for i: int in range(sc):
		var t: float = float(i) / float(MIX_RATE)
		var p: float = float(i) / float(sc)
		var env: float = sin(p * PI) * 0.2
		var s: float = sin(TAU_CONST * freq * t) * 0.5 + sin(TAU_CONST * freq * 1.5 * t) * 0.2
		data.encode_s16(i * 2, clampi(int(s * env * 32767.0), -32768, 32767))
	return _make_wav(data)


## Spore/mushroom pop event
func _gen_event_pop(freq: float, dur: float) -> AudioStreamWAV:
	var sc: int = int(MIX_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sc * 2)
	for i: int in range(sc):
		var t: float = float(i) / float(MIX_RATE)
		var p: float = float(i) / float(sc)
		var env: float = exp(-p * 25.0) * 0.3
		data.encode_s16(i * 2, clampi(int(sin(TAU_CONST * freq * t) * env * 32767.0), -32768, 32767))
	return _make_wav(data)


## Growth creak event
func _gen_event_creak(dur: float) -> AudioStreamWAV:
	var sc: int = int(MIX_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sc * 2)
	for i: int in range(sc):
		var t: float = float(i) / float(MIX_RATE)
		var p: float = float(i) / float(sc)
		var freq: float = lerpf(180.0, 400.0, p)
		var env: float = sin(p * PI) * 0.15
		data.encode_s16(i * 2, clampi(int(sin(TAU_CONST * freq * t) * env * 32767.0), -32768, 32767))
	return _make_wav(data)


## Web twang event
func _gen_event_web_twang(dur: float) -> AudioStreamWAV:
	var sc: int = int(MIX_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sc * 2)
	for i: int in range(sc):
		var t: float = float(i) / float(MIX_RATE)
		var p: float = float(i) / float(sc)
		var freq: float = 800.0 * (1.0 - p * 0.5)
		var env: float = exp(-p * 6.0) * 0.2
		var s: float = sin(TAU_CONST * freq * t) * 0.5 + sin(TAU_CONST * freq * 2.3 * t) * 0.15
		data.encode_s16(i * 2, clampi(int(s * env * 32767.0), -32768, 32767))
	return _make_wav(data)


## Void groan event
func _gen_event_void_groan(dur: float) -> AudioStreamWAV:
	var sc: int = int(MIX_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sc * 2)
	for i: int in range(sc):
		var t: float = float(i) / float(MIX_RATE)
		var p: float = float(i) / float(sc)
		var freq: float = lerpf(60.0, 35.0, p)
		var env: float = sin(p * PI) * 0.2
		var s: float = sin(TAU_CONST * freq * t) * 0.5 + sin(TAU_CONST * freq * 1.07 * t) * 0.3
		data.encode_s16(i * 2, clampi(int(s * env * 32767.0), -32768, 32767))
	return _make_wav(data)


## Reality crack event
func _gen_event_crack(dur: float) -> AudioStreamWAV:
	var sc: int = int(MIX_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sc * 2)
	for i: int in range(sc):
		var p: float = float(i) / float(sc)
		var env: float = exp(-p * 30.0) * 0.4
		data.encode_s16(i * 2, clampi(int(randf_range(-1.0, 1.0) * env * 32767.0), -32768, 32767))
	return _make_wav(data)


## Rock rumble event
func _gen_event_rumble(dur: float) -> AudioStreamWAV:
	var sc: int = int(MIX_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sc * 2)
	var flt: float = 0.0
	for i: int in range(sc):
		var t: float = float(i) / float(MIX_RATE)
		var p: float = float(i) / float(sc)
		var env: float = sin(p * PI) * 0.2
		var n: float = randf_range(-1.0, 1.0)
		flt = flt * 0.95 + n * 0.05
		var sub: float = sin(TAU_CONST * 40.0 * t) * 0.3
		data.encode_s16(i * 2, clampi(int((flt * 0.4 + sub) * env * 32767.0), -32768, 32767))
	return _make_wav(data)


## Digital glitch event
func _gen_event_glitch(dur: float) -> AudioStreamWAV:
	var sc: int = int(MIX_RATE * dur)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sc * 2)
	for i: int in range(sc):
		var t: float = float(i) / float(MIX_RATE)
		var p: float = float(i) / float(sc)
		var env: float = sin(p * PI) * 0.25
		var freq: float = 200.0 * (1.0 + sin(TAU_CONST * 13.0 * t) * 2.0)
		var s: float = sin(TAU_CONST * freq * t)
		s = clampf(s * 3.0, -1.0, 1.0)
		var glitch_noise: float = 0.0
		if fmod(p * 7.0, 1.0) < 0.1:
			glitch_noise = randf_range(-1.0, 1.0) * 0.3
		data.encode_s16(i * 2, clampi(int((s * 0.5 + glitch_noise) * env * 32767.0), -32768, 32767))
	return _make_wav(data)


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


## Apply volume levels to audio buses. Master bus gets master_volume,
## SFX/UI buses get sfx_volume, Ambient bus gets music_volume.
## Individual players play at 0 dB (relative levels set per-stream).
func _apply_bus_volumes() -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, _linear_to_db_safe(master_volume))

	var sfx_idx: int = AudioServer.get_bus_index(BUS_SFX)
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, _linear_to_db_safe(sfx_volume))

	var ui_idx: int = AudioServer.get_bus_index(BUS_UI)
	if ui_idx >= 0:
		AudioServer.set_bus_volume_db(ui_idx, _linear_to_db_safe(sfx_volume))

	var amb_idx: int = AudioServer.get_bus_index(BUS_AMBIENT)
	if amb_idx >= 0:
		AudioServer.set_bus_volume_db(amb_idx, _linear_to_db_safe(music_volume))


## Convert linear volume (0-1) to dB, returning -80 for silence.
func _linear_to_db_safe(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return linear_to_db(linear)


## Calculate the effective SFX volume in decibels (legacy, used by play_sfx pitch).
func _get_sfx_db() -> float:
	return 0.0  ## Bus handles volume now; players play at 0 dB


## Calculate the effective ambient/music volume in decibels.
func _get_ambient_db() -> float:
	return 0.0  ## Bus handles volume now; players play at 0 dB


## Update the volume of the active ambient player (now a no-op, bus handles it).
func _update_ambient_volume() -> void:
	pass


## Apply initial volumes from GameState settings.
func _apply_initial_volumes() -> void:
	if GameState.settings.has("music_volume"):
		music_volume = float(GameState.settings["music_volume"])
	if GameState.settings.has("sfx_volume"):
		sfx_volume = float(GameState.settings["sfx_volume"])
	_apply_bus_volumes()
	# Restore global mute state
	if GameState.settings.has("muted") and bool(GameState.settings["muted"]):
		_is_muted = true
		toggle_sfx(false)
		toggle_music(false)
