extends Node2D

@export_group("Visual Effects (VFX)")
@export var dig_vfx: PackedScene
@export var move_vfx: PackedScene
@export var hit_wall_vfx: PackedScene
@export var battery_vfx: PackedScene

@export_group("Sound Effects (SFX)")
@export var dig_sfx: AudioStream
@export var move_sfx: AudioStream
@export var hit_wall_sfx: AudioStream
@export var battery_sfx: AudioStream

func _ready() -> void:
	# Find the player in the scene
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.dug_tile.connect(_on_player_dug_tile)
		player.moved_freely.connect(_on_player_moved_freely)
		player.hit_wall.connect(_on_player_hit_wall)
		player.collected_battery.connect(_on_player_collected_battery)

func _on_player_dug_tile(pos: Vector2) -> void:
	_spawn_vfx(dig_vfx, pos, Color("8b5a2b")) # Brown placeholder
	_play_sfx(dig_sfx, "Dig")

func _on_player_moved_freely(pos: Vector2) -> void:
	_spawn_vfx(move_vfx, pos, Color("ffffff", 0.5)) # Semi-transparent white
	_play_sfx(move_sfx, "Move")

func _on_player_hit_wall(pos: Vector2) -> void:
	_spawn_vfx(hit_wall_vfx, pos, Color("ff0000")) # Red placeholder
	_play_sfx(hit_wall_sfx, "Hit Wall")

func _on_player_collected_battery(pos: Vector2) -> void:
	_spawn_vfx(battery_vfx, pos, Color("ffd700")) # Gold placeholder
	_play_sfx(battery_sfx, "Battery Collected")

func _spawn_vfx(scene: PackedScene, pos: Vector2, fallback_color: Color) -> void:
	if scene:
		var vfx_instance = scene.instantiate()
		if vfx_instance is Node2D or vfx_instance is Control:
			vfx_instance.global_position = pos
		add_child(vfx_instance)
	else:
		# Fallback placeholder logic
		var rect = ColorRect.new()
		rect.color = fallback_color
		rect.size = Vector2(16, 16)
		rect.position = pos - Vector2(8, 8) # Center it
		add_child(rect)
		
		var tween = create_tween()
		tween.tween_property(rect, "modulate:a", 0.0, 0.2)
		tween.tween_callback(rect.queue_free)

func _play_sfx(stream: AudioStream, fallback_name: String) -> void:
	if stream:
		var audio_player = AudioStreamPlayer.new()
		audio_player.stream = stream
		audio_player.autoplay = true
		add_child(audio_player)
		audio_player.finished.connect(audio_player.queue_free)
	else:
		print("SFX Played: ", fallback_name)
