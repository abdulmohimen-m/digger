extends Node

# --- Sound Manager Autoload Singleton ---
# Handles global SFX voice pooling, dynamic pitch variation, Audio Bus routing,
# settings persistence (user://settings.cfg), and event bus feedback listeners.

const SETTINGS_PATH := "user://settings.cfg"
const SFX_POOL_SIZE := 16

# Audio Streams Array & Map
var _dig_streams: Array[AudioStream] = []
var _last_dig_index: int = -1
var _rock_dig_streams: Array[AudioStream] = []
var _last_rock_dig_index: int = -1
var _procedural_sfx: Dictionary = {}

# Dedicated Stream Assets
var _collect_coin_stream: AudioStream
var _collect_diamond_stream: AudioStream
var _battery_charge_stream: AudioStream
var _frenzy_transition_stream: AudioStream
var _metal_hit_stream: AudioStream
var _game_over_stream: AudioStream
var _explosion_stream: AudioStream
var _bomb_drop_stream: AudioStream
var _drill_loop_stream: AudioStream

# Audio Players Pool & Dual BGM Crossfader
var _sfx_players: Array[AudioStreamPlayer] = []
var _bgm_normal_stream: AudioStream
var _bgm_frenzy_stream: AudioStream
var _bgm_normal_player: AudioStreamPlayer
var _bgm_frenzy_player: AudioStreamPlayer
var _bgm_player: AudioStreamPlayer
var _bgm_crossfade_tween: Tween
var _bgm_normal_playback_position: float = 0.0
var _is_in_frenzy_bgm: bool = false
var _drill_loop_player: AudioStreamPlayer
var _drill_loop_tween: Tween
var _is_drill_loop_active: bool = false
var _bgm_lowpass_active: bool = false

# Master Volume Cache (linear 0.0 to 1.0)
var volume_master: float = 1.0
var volume_music: float = 0.8
var volume_sfx: float = 1.0
var volume_ui: float = 1.0

func _ready() -> void:
	_init_audio_pool()
	_load_audio_assets()
	_generate_procedural_fallbacks()
	_load_settings()
	_connect_event_bus()
	_start_default_bgm()

# --- Audio Pool Setup ---
func _init_audio_pool() -> void:
	# Create pooled AudioStreamPlayer nodes for SFX
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_sfx_players.append(player)
	
	# Dedicated BGM players for dual crossfading
	_bgm_normal_player = AudioStreamPlayer.new()
	_bgm_normal_player.bus = &"Music"
	add_child(_bgm_normal_player)
	_bgm_player = _bgm_normal_player

	_bgm_frenzy_player = AudioStreamPlayer.new()
	_bgm_frenzy_player.bus = &"Music"
	add_child(_bgm_frenzy_player)

	# Dedicated Drill Loop player
	_drill_loop_player = AudioStreamPlayer.new()
	_drill_loop_player.bus = &"SFX"
	add_child(_drill_loop_player)

# --- Asset Loading & Procedural Fallbacks ---
func _load_audio_assets() -> void:
	# Load Digging sound variations (Digging1.ogg to Digging7.ogg)
	for i in range(1, 8):
		var path := "res://assets/sfx/Digging%d.ogg" % i
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			var stream := load(path) as AudioStream
			if stream:
				_dig_streams.append(stream)

	# Load DigRock sound variations (DigRock1.ogg & DigRock2.ogg)
	for i in range(1, 3):
		var path := "res://assets/sfx/DigRock%d.ogg" % i
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			var stream := load(path) as AudioStream
			if stream:
				_rock_dig_streams.append(stream)

	# Load newly added SFX assets
	if ResourceLoader.exists("res://assets/sfx/CollectCoin.ogg") or FileAccess.file_exists("res://assets/sfx/CollectCoin.ogg"):
		_collect_coin_stream = load("res://assets/sfx/CollectCoin.ogg")
	if ResourceLoader.exists("res://assets/sfx/CollectDiamond.ogg") or FileAccess.file_exists("res://assets/sfx/CollectDiamond.ogg"):
		_collect_diamond_stream = load("res://assets/sfx/CollectDiamond.ogg")
	if ResourceLoader.exists("res://assets/sfx/BatteryCharge.ogg") or FileAccess.file_exists("res://assets/sfx/BatteryCharge.ogg"):
		_battery_charge_stream = load("res://assets/sfx/BatteryCharge.ogg")
	if ResourceLoader.exists("res://assets/sfx/FrenzyTransition.ogg") or FileAccess.file_exists("res://assets/sfx/FrenzyTransition.ogg"):
		_frenzy_transition_stream = load("res://assets/sfx/FrenzyTransition.ogg")
	if ResourceLoader.exists("res://assets/sfx/MetalHit.ogg") or FileAccess.file_exists("res://assets/sfx/MetalHit.ogg"):
		_metal_hit_stream = load("res://assets/sfx/MetalHit.ogg")
	if ResourceLoader.exists("res://assets/sfx/GameOver.ogg") or FileAccess.file_exists("res://assets/sfx/GameOver.ogg"):
		_game_over_stream = load("res://assets/sfx/GameOver.ogg")
	if ResourceLoader.exists("res://assets/sfx/Explosion.ogg") or FileAccess.file_exists("res://assets/sfx/Explosion.ogg"):
		_explosion_stream = load("res://assets/sfx/Explosion.ogg")
	if ResourceLoader.exists("res://assets/sfx/BombDrop.ogg") or FileAccess.file_exists("res://assets/sfx/BombDrop.ogg"):
		_bomb_drop_stream = load("res://assets/sfx/BombDrop.ogg")
	if ResourceLoader.exists("res://assets/sfx/DrilLoop.ogg") or FileAccess.file_exists("res://assets/sfx/DrilLoop.ogg"):
		_drill_loop_stream = load("res://assets/sfx/DrilLoop.ogg")
		if _drill_loop_stream is AudioStreamOggVorbis:
			_drill_loop_stream.loop = true
		_drill_loop_player.stream = _drill_loop_stream

	# Load BGM track assets
	var norm_bgm_path := "res://assets/music/maksymmalko-game-minecraft-gaming-background-music-402451.mp3"
	if ResourceLoader.exists(norm_bgm_path) or FileAccess.file_exists(norm_bgm_path):
		_bgm_normal_stream = load(norm_bgm_path)
		if _bgm_normal_stream is AudioStreamMP3:
			_bgm_normal_stream.loop = true

	var frenzy_bgm_path := "res://assets/music/freesound_community-high-energy-loop-69158.mp3"
	if ResourceLoader.exists(frenzy_bgm_path) or FileAccess.file_exists(frenzy_bgm_path):
		_bgm_frenzy_stream = load(frenzy_bgm_path)
		if _bgm_frenzy_stream is AudioStreamMP3:
			_bgm_frenzy_stream.loop = true

func _generate_procedural_fallbacks() -> void:
	# Generates clean retro arcade WAV samples in memory for fallback SFX
	_procedural_sfx["dig"] = _generate_tone_wav(160, 0.08, 0.4, true)
	_procedural_sfx["move"] = _generate_tone_wav(300, 0.04, 0.15, true)
	_procedural_sfx["hit_wall"] = _generate_tone_wav(120, 0.1, 0.6, true)
	_procedural_sfx["hit_rock"] = _generate_tone_wav(90, 0.15, 0.7, true)
	_procedural_sfx["hit_mine"] = _generate_tone_wav(65, 0.4, 0.9, true)
	_procedural_sfx["battery"] = _generate_tone_wav(520, 0.18, 0.5, false)
	_procedural_sfx["gold"] = _generate_tone_wav(880, 0.2, 0.5, false)
	_procedural_sfx["diamond"] = _generate_tone_wav(1320, 0.25, 0.5, false)
	_procedural_sfx["placed_bomb"] = _generate_tone_wav(220, 0.1, 0.4, true)
	_procedural_sfx["detonated_bomb"] = _generate_tone_wav(70, 0.45, 0.8, true)
	_procedural_sfx["low_battery"] = _generate_tone_wav(440, 0.15, 0.4, false)
	_procedural_sfx["battery_depleted"] = _generate_tone_wav(110, 0.6, 0.7, true)
	_procedural_sfx["ui_click"] = _generate_tone_wav(600, 0.04, 0.3, false)
	_procedural_sfx["ui_hover"] = _generate_tone_wav(400, 0.02, 0.15, false)
	_procedural_sfx["frenzy"] = _generate_tone_wav(750, 0.3, 0.6, false)

func _generate_tone_wav(freq: float, duration: float, volume: float, noise: bool) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples)
	
	for i in range(num_samples):
		var t := float(i) / sample_rate
		var envelope := 1.0 - (float(i) / num_samples) # Linear decay
		var wave: float = 0.0
		
		if noise:
			wave = (randf() * 2.0 - 1.0) * 0.6 + sin(2.0 * PI * freq * t) * 0.4
		else:
			wave = sin(2.0 * PI * freq * t)
			
		var val := int(clamp(wave * envelope * volume * 127.0, -128.0, 127.0))
		data[i] = (val + 256) % 256
		
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav

# --- Event Bus Integration ---
func _connect_event_bus() -> void:
	if not EventBus:
		return
	EventBus.dug_tile.connect(_on_dug_tile)
	EventBus.moved_freely.connect(_on_moved_freely)
	EventBus.hit_wall.connect(_on_hit_wall)
	EventBus.hit_rock.connect(_on_hit_rock)
	EventBus.hit_mine.connect(_on_hit_mine)
	EventBus.collected_battery.connect(_on_collected_battery)
	EventBus.collected_gold.connect(_on_collected_gold)
	EventBus.collected_diamond.connect(_on_collected_diamond)
	EventBus.placed_bomb.connect(_on_placed_bomb)
	EventBus.detonated_bomb.connect(_on_detonated_bomb)
	EventBus.low_battery_warning.connect(_on_low_battery_warning)
	EventBus.battery_depleted.connect(_on_battery_depleted)
	EventBus.frenzy_tier_changed.connect(_on_frenzy_tier_changed)
	EventBus.vehicle_movement_updated.connect(_on_vehicle_movement_updated)
	EventBus.ui_button_clicked.connect(_on_ui_button_clicked)
	EventBus.ui_button_hovered.connect(_on_ui_button_hovered)

# --- SFX Voice Dispatcher & Pitch Variation ---
func play_sfx(stream: AudioStream, pitch_scale: float = 1.0, bus_override: StringName = &"SFX") -> void:
	if not stream:
		return
	var player := _get_available_player()
	if player:
		player.bus = bus_override
		player.stream = stream
		player.pitch_scale = pitch_scale
		player.play()

func play_sfx_key(key: String, pitch_jitter: float = 0.08, bus_override: StringName = &"SFX") -> void:
	var stream: AudioStream = _procedural_sfx.get(key, null)
	if stream:
		var pitch := 1.0 + randf_range(-pitch_jitter, pitch_jitter)
		play_sfx(stream, pitch, bus_override)

func play_random_dig_sfx(bus_override: StringName = &"SFX") -> void:
	if _dig_streams.size() > 0:
		var index := randi() % _dig_streams.size()
		if _dig_streams.size() > 1 and index == _last_dig_index:
			index = (index + 1) % _dig_streams.size()
		_last_dig_index = index
		var stream = _dig_streams[index]
		var pitch = 1.0 + randf_range(-0.05, 0.05)
		play_sfx(stream, pitch, bus_override)
	else:
		play_sfx_key("dig", 0.05, bus_override)

func play_random_rock_dig_sfx() -> void:
	if _rock_dig_streams.size() > 0:
		var index := randi() % _rock_dig_streams.size()
		if _rock_dig_streams.size() > 1 and index == _last_rock_dig_index:
			index = (index + 1) % _rock_dig_streams.size()
		_last_rock_dig_index = index
		var stream = _rock_dig_streams[index]
		var pitch = 1.0 + randf_range(-0.06, 0.06)
		play_sfx(stream, pitch)
	else:
		play_sfx_key("hit_rock", 0.08)

func _get_available_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	# Fallback to reusing oldest player
	return _sfx_players[0]

# --- Signal Handlers ---
func _on_dug_tile(_pos: Vector2, _color: Color) -> void:
	play_random_dig_sfx()

func _on_moved_freely(_pos: Vector2) -> void:
	# Continuous engine loop (DrilLoop.ogg) handles free movement audio without extra step ticks
	pass

func _on_hit_wall(_pos: Vector2) -> void:
	if _metal_hit_stream:
		var pitch := 1.0 + randf_range(-0.05, 0.05)
		play_sfx(_metal_hit_stream, pitch)
	else:
		play_sfx_key("hit_wall", 0.05)

func _on_hit_rock(_pos: Vector2) -> void:
	play_random_rock_dig_sfx()

func _on_hit_mine(_pos: Vector2) -> void:
	if _explosion_stream:
		var pitch := 1.1 + randf_range(-0.05, 0.05)
		play_sfx(_explosion_stream, pitch)
	else:
		play_sfx_key("hit_mine", 0.1)

func _on_collected_battery(_pos: Vector2) -> void:
	play_random_dig_sfx()
	if _battery_charge_stream:
		var pitch := 1.0 + randf_range(-0.04, 0.04)
		play_sfx(_battery_charge_stream, pitch)
	else:
		play_sfx_key("battery", 0.04)

func _on_collected_gold(_pos: Vector2) -> void:
	play_random_dig_sfx()
	if _collect_coin_stream:
		var pitch := 1.0 + randf_range(-0.04, 0.04)
		play_sfx(_collect_coin_stream, pitch)
	else:
		play_sfx_key("gold", 0.04)

func _on_collected_diamond(_pos: Vector2) -> void:
	play_random_dig_sfx()
	if _collect_diamond_stream:
		var pitch := 1.0 + randf_range(-0.04, 0.04)
		play_sfx(_collect_diamond_stream, pitch)
	else:
		play_sfx_key("diamond", 0.04)

func _on_placed_bomb(_pos: Vector2) -> void:
	if _bomb_drop_stream:
		var pitch := 1.0 + randf_range(-0.04, 0.04)
		play_sfx(_bomb_drop_stream, pitch)
	else:
		play_sfx_key("placed_bomb", 0.05)

func _on_detonated_bomb(_pos: Vector2) -> void:
	if _explosion_stream:
		var pitch := 0.9 + randf_range(-0.05, 0.05)
		play_sfx(_explosion_stream, pitch)
	else:
		play_sfx_key("detonated_bomb", 0.08)

func _on_low_battery_warning(is_low: bool) -> void:
	_set_music_lowpass_filter(is_low)
	if is_low:
		play_sfx_key("low_battery", 0.0)

func _on_battery_depleted(_pos: Vector2) -> void:
	_set_music_lowpass_filter(false)
	_is_drill_loop_active = false
	if _drill_loop_player and _drill_loop_player.playing:
		_drill_loop_player.stop()

	# Smoothly fade out background music on game over
	if _bgm_crossfade_tween and _bgm_crossfade_tween.is_valid():
		_bgm_crossfade_tween.kill()
	_bgm_crossfade_tween = create_tween()
	if _bgm_normal_player:
		_bgm_crossfade_tween.parallel().tween_property(_bgm_normal_player, "volume_db", -80.0, 1.0)
	if _bgm_frenzy_player:
		_bgm_crossfade_tween.parallel().tween_property(_bgm_frenzy_player, "volume_db", -80.0, 1.0)
	_bgm_crossfade_tween.tween_callback(func():
		if _bgm_normal_player: _bgm_normal_player.stop()
		if _bgm_frenzy_player: _bgm_frenzy_player.stop()
	)

	if _game_over_stream:
		play_sfx(_game_over_stream, 1.0)
	else:
		play_sfx_key("battery_depleted", 0.0)

func _on_vehicle_movement_updated(is_moving: bool, current_speed: float) -> void:
	if not _drill_loop_stream:
		return
		
	if _drill_loop_tween and _drill_loop_tween.is_valid():
		_drill_loop_tween.kill()
		
	_drill_loop_tween = create_tween()
	
	if is_moving:
		_is_drill_loop_active = true
		# Plain tile & slow dirt digging use 1.6 pitch. Frenzy speeds scale higher up to 2.4
		var target_pitch: float = 1.6
		if current_speed > 53.0 and current_speed < 160.0:
			target_pitch = remap(current_speed, 53.0, 150.0, 1.8, 2.4)
		_drill_loop_tween.parallel().tween_property(_drill_loop_player, "pitch_scale", target_pitch, 0.08)
		
		if not _drill_loop_player.playing:
			_drill_loop_player.volume_db = -80.0
			_drill_loop_player.play()
			
		_drill_loop_tween.parallel().tween_property(_drill_loop_player, "volume_db", linear_to_db(volume_sfx), 0.08)
	else:
		_is_drill_loop_active = false
		_drill_loop_tween.tween_property(_drill_loop_player, "volume_db", -80.0, 0.08)
		_drill_loop_tween.tween_callback(func():
			if not _is_drill_loop_active:
				_drill_loop_player.stop()
		)

func _on_frenzy_tier_changed(tier: int) -> void:
	if tier > 0:
		var pitch := 1.0 + ((tier - 1) * 0.1) # 1.0x for Tier 1 up to 1.4x for Tier 5
		if _frenzy_transition_stream:
			play_sfx(_frenzy_transition_stream, pitch)
		else:
			var stream: AudioStream = _procedural_sfx.get("frenzy", null)
			if stream:
				play_sfx(stream, pitch)

		# Crossfade to high-energy Frenzy music on tier >= 1
		if not _is_in_frenzy_bgm:
			_crossfade_bgm(true)
	else:
		# Return to normal BGM when Frenzy ends
		if _is_in_frenzy_bgm:
			_crossfade_bgm(false)

func _on_ui_button_clicked() -> void:
	play_random_dig_sfx(&"UI")

func _on_ui_button_hovered() -> void:
	play_sfx_key("ui_hover", 0.02, &"UI")

# --- Music & Dynamic Crossfader ---
func _start_default_bgm() -> void:
	if _bgm_normal_stream and _bgm_normal_player:
		_bgm_normal_player.stream = _bgm_normal_stream
		_bgm_normal_player.volume_db = linear_to_db(volume_music)
		if not _bgm_normal_player.playing:
			_bgm_normal_player.play()
	if _bgm_frenzy_stream and _bgm_frenzy_player:
		_bgm_frenzy_player.stream = _bgm_frenzy_stream
		_bgm_frenzy_player.volume_db = -80.0

func _crossfade_bgm(to_frenzy: bool, duration: float = 1.0) -> void:
	_is_in_frenzy_bgm = to_frenzy

	if _bgm_crossfade_tween and _bgm_crossfade_tween.is_valid():
		_bgm_crossfade_tween.kill()

	_bgm_crossfade_tween = create_tween()
	var target_vol_db := linear_to_db(volume_music)

	if to_frenzy:
		# Save normal track playback position before pausing
		if _bgm_normal_player and _bgm_normal_player.playing:
			_bgm_normal_playback_position = _bgm_normal_player.get_playback_position()

		# Fade out Normal BGM
		if _bgm_normal_player:
			_bgm_crossfade_tween.parallel().tween_property(_bgm_normal_player, "volume_db", -80.0, duration)

		# Fade in Frenzy BGM
		if _bgm_frenzy_player and _bgm_frenzy_player.stream:
			if not _bgm_frenzy_player.playing:
				_bgm_frenzy_player.volume_db = -80.0
				_bgm_frenzy_player.play()
			_bgm_crossfade_tween.parallel().tween_property(_bgm_frenzy_player, "volume_db", target_vol_db, duration)

		_bgm_crossfade_tween.tween_callback(func():
			if _is_in_frenzy_bgm and _bgm_normal_player:
				_bgm_normal_player.stream_paused = true
		)
	else:
		# Resume Normal BGM from saved position
		if _bgm_normal_player and _bgm_normal_player.stream:
			if _bgm_normal_player.stream_paused:
				_bgm_normal_player.stream_paused = false
			elif not _bgm_normal_player.playing:
				_bgm_normal_player.volume_db = -80.0
				_bgm_normal_player.play(_bgm_normal_playback_position)
			_bgm_crossfade_tween.parallel().tween_property(_bgm_normal_player, "volume_db", target_vol_db, duration)

		# Fade out Frenzy BGM
		if _bgm_frenzy_player:
			_bgm_crossfade_tween.parallel().tween_property(_bgm_frenzy_player, "volume_db", -80.0, duration)

		_bgm_crossfade_tween.tween_callback(func():
			if not _is_in_frenzy_bgm and _bgm_frenzy_player and _bgm_frenzy_player.playing:
				_bgm_frenzy_player.stop()
		)

func _set_music_lowpass_filter(enabled: bool) -> void:
	_bgm_lowpass_active = enabled
	var music_bus_idx := AudioServer.get_bus_index(&"Music")
	if music_bus_idx != -1 and AudioServer.get_bus_effect_count(music_bus_idx) > 0:
		AudioServer.set_bus_effect_enabled(music_bus_idx, 0, enabled)

func play_bgm(stream: AudioStream, crossfade_duration: float = 1.0) -> void:
	if not stream:
		return
	if _bgm_normal_player and _bgm_normal_player.playing and _bgm_normal_player.stream == stream:
		return

	if crossfade_duration > 0.0 and _bgm_normal_player and _bgm_normal_player.playing:
		var tween := create_tween()
		tween.tween_property(_bgm_normal_player, "volume_db", -80.0, crossfade_duration * 0.5)
		tween.tween_callback(func():
			_bgm_normal_player.stream = stream
			_bgm_normal_player.volume_db = linear_to_db(volume_music)
			_bgm_normal_player.play()
		)
	else:
		if _bgm_normal_player:
			_bgm_normal_player.stream = stream
			_bgm_normal_player.volume_db = linear_to_db(volume_music)
			_bgm_normal_player.play()

# --- Audio Buses & Persistence (SKG Preservation) ---
func set_bus_volume(bus_name: StringName, linear_val: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		linear_val = clamp(linear_val, 0.0, 1.0)
		var db := linear_to_db(linear_val) if linear_val > 0.0001 else -80.0
		AudioServer.set_bus_volume_db(bus_idx, db)
		AudioServer.set_bus_mute(bus_idx, linear_val <= 0.0001)
		
		match bus_name:
			&"Master": volume_master = linear_val
			&"Music": volume_music = linear_val
			&"SFX": volume_sfx = linear_val
			&"UI": volume_ui = linear_val
			
		save_settings()

func get_bus_volume(bus_name: StringName) -> float:
	match bus_name:
		&"Master": return volume_master
		&"Music": return volume_music
		&"SFX": return volume_sfx
		&"UI": return volume_ui
	return 1.0

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("Audio", "master", volume_master)
	config.set_value("Audio", "music", volume_music)
	config.set_value("Audio", "sfx", volume_sfx)
	config.set_value("Audio", "ui", volume_ui)
	config.save(SETTINGS_PATH)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		volume_master = config.get_value("Audio", "master", 1.0)
		volume_music = config.get_value("Audio", "music", 0.8)
		volume_sfx = config.get_value("Audio", "sfx", 1.0)
		volume_ui = config.get_value("Audio", "ui", 1.0)
		
	set_bus_volume(&"Master", volume_master)
	set_bus_volume(&"Music", volume_music)
	set_bus_volume(&"SFX", volume_sfx)
	set_bus_volume(&"UI", volume_ui)
