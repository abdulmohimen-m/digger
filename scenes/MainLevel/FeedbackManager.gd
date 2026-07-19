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

var _camera: Camera2D

func _ready() -> void:
	# Find the player in the scene
	var player = get_tree().get_first_node_in_group("player")
	if player:
		_camera = player.get_node_or_null("Camera2D")
		player.dug_tile.connect(_on_player_dug_tile)
		player.moved_freely.connect(_on_player_moved_freely)
		player.hit_wall.connect(_on_player_hit_wall)
		player.collected_battery.connect(_on_player_collected_battery)
		player.placed_bomb.connect(_on_player_placed_bomb)
		player.detonated_bomb.connect(_on_player_detonated_bomb)
		player.hit_rock.connect(_on_player_hit_rock)
		player.low_battery_warning.connect(_on_player_low_battery_warning)
		player.battery_depleted.connect(_on_player_battery_depleted)

func _on_player_dug_tile(pos: Vector2) -> void:
	_spawn_vfx(dig_vfx, pos, Color("8b5a2b")) # Brown placeholder
	_play_sfx(dig_sfx, "Dig")

func _on_player_moved_freely(pos: Vector2) -> void:
	_spawn_vfx(move_vfx, pos, Color("ffffff", 0.5)) # Semi-transparent white
	_play_sfx(move_sfx, "Move")

func _on_player_hit_wall(pos: Vector2) -> void:
	_spawn_vfx(hit_wall_vfx, pos, Color("ff0000")) # Red placeholder
	_play_sfx(hit_wall_sfx, "Hit Wall")
	if _camera and _camera.has_method("shake"):
		_camera.shake(6.0)

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
		# Create a dynamic, blocky shard burst using CPUParticles2D
		var particles = CPUParticles2D.new()
		particles.global_position = pos
		particles.amount = 8
		particles.explosiveness = 1.0
		particles.one_shot = true
		particles.lifetime = 0.4
		particles.spread = 180.0
		particles.gravity = Vector2(0, 300.0) # Downward gravity
		particles.initial_velocity_min = 30.0
		particles.initial_velocity_max = 60.0
		particles.scale_amount_min = 2.0
		particles.scale_amount_max = 4.0
		particles.color = fallback_color
		
		add_child(particles)
		particles.emitting = true
		
		# Clean up after lifetime ends
		var timer = get_tree().create_timer(particles.lifetime + 0.1)
		timer.timeout.connect(particles.queue_free)

func _play_sfx(stream: AudioStream, fallback_name: String) -> void:
	if stream:
		var audio_player = AudioStreamPlayer.new()
		audio_player.stream = stream
		audio_player.autoplay = true
		add_child(audio_player)
		audio_player.finished.connect(audio_player.queue_free)
	else:
		print("SFX Played: ", fallback_name)


func _on_player_placed_bomb(pos: Vector2) -> void:
	_play_sfx(null, "Deep Thud (Bomb Placed)")


func _on_player_detonated_bomb(pos: Vector2) -> void:
	_play_sfx(null, "Loud Boom (Explosion)")
	if _camera and _camera.has_method("shake"):
		_camera.shake(10.0)
		
	var particles = CPUParticles2D.new()
	particles.global_position = pos
	particles.amount = 30
	particles.explosiveness = 1.0
	particles.one_shot = true
	particles.lifetime = 0.6
	particles.spread = 180.0
	particles.gravity = Vector2(0, 300.0)
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 150.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 6.0
	particles.color = Color(1.0, 0.4, 0.0) # Fiery Orange/Red
	
	add_child(particles)
	particles.emitting = true
	
	var timer = get_tree().create_timer(particles.lifetime + 0.1)
	timer.timeout.connect(particles.queue_free)


func _on_player_hit_rock(pos: Vector2) -> void:
	_play_sfx(null, "Rock Crunch")
	if _camera and _camera.has_method("shake"):
		_camera.shake(4.0)
		
	var particles = CPUParticles2D.new()
	particles.global_position = pos
	particles.amount = 12
	particles.explosiveness = 1.0
	particles.one_shot = true
	particles.lifetime = 0.5
	particles.spread = 180.0
	particles.gravity = Vector2(0, 300.0)
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 90.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.color = Color(0.33, 0.33, 0.33) # Dark Grey Stone
	
	add_child(particles)
	particles.emitting = true
	
	var timer = get_tree().create_timer(particles.lifetime + 0.1)
	timer.timeout.connect(particles.queue_free)


func _on_player_low_battery_warning(is_low: bool) -> void:
	if is_low:
		_play_sfx(null, "⚠️ Low Battery Alarm Beep ⚠️")
		# Sputtering dark smoke burst around vehicle
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var particles = CPUParticles2D.new()
			particles.global_position = player.global_position
			particles.amount = 10
			particles.explosiveness = 0.8
			particles.one_shot = true
			particles.lifetime = 0.6
			particles.spread = 360.0
			particles.gravity = Vector2(0, -60.0) # Rising smoke
			particles.initial_velocity_min = 15.0
			particles.initial_velocity_max = 35.0
			particles.scale_amount_min = 2.0
			particles.scale_amount_max = 4.0
			particles.color = Color(0.2, 0.2, 0.2, 0.7) # Dark sputtering smoke
			
			add_child(particles)
			particles.emitting = true
			var timer = get_tree().create_timer(particles.lifetime + 0.1)
			timer.timeout.connect(particles.queue_free)


func _on_player_battery_depleted(pos: Vector2) -> void:
	_play_sfx(null, "🛑 POWER DOWN ENGINE STALL 🛑")
	if _camera and _camera.has_method("shake"):
		_camera.shake(8.0)
		
	# Spawn electric spark & smoke explosion
	var smoke = CPUParticles2D.new()
	smoke.global_position = pos
	smoke.amount = 25
	smoke.explosiveness = 0.9
	smoke.one_shot = true
	smoke.lifetime = 0.9
	smoke.spread = 180.0
	smoke.gravity = Vector2(0, -80.0) # Rising dark smoke
	smoke.initial_velocity_min = 30.0
	smoke.initial_velocity_max = 70.0
	smoke.scale_amount_min = 3.0
	smoke.scale_amount_max = 6.0
	smoke.color = Color(0.15, 0.15, 0.18, 0.8) # Heavy dark smoke cloud
	add_child(smoke)
	smoke.emitting = true
	var timer1 = get_tree().create_timer(smoke.lifetime + 0.1)
	timer1.timeout.connect(smoke.queue_free)

	var sparks = CPUParticles2D.new()
	sparks.global_position = pos
	sparks.amount = 16
	sparks.explosiveness = 1.0
	sparks.one_shot = true
	sparks.lifetime = 0.4
	sparks.spread = 180.0
	sparks.gravity = Vector2(0, 200.0)
	sparks.initial_velocity_min = 60.0
	sparks.initial_velocity_max = 120.0
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.5
	sparks.color = Color(0.2, 0.9, 1.0) # Electric cyan sparks
	add_child(sparks)
	sparks.emitting = true
	var timer2 = get_tree().create_timer(sparks.lifetime + 0.1)
	timer2.timeout.connect(sparks.queue_free)



