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
		player.collected_gold.connect(_on_player_collected_gold)
		player.collected_diamond.connect(_on_player_collected_diamond)
		player.placed_bomb.connect(_on_player_placed_bomb)
		player.detonated_bomb.connect(_on_player_detonated_bomb)
		player.hit_rock.connect(_on_player_hit_rock)
		player.hit_mine.connect(_on_player_hit_mine)
		player.low_battery_warning.connect(_on_player_low_battery_warning)
		player.battery_depleted.connect(_on_player_battery_depleted)
		if player.has_signal("rock_crushed_player"):
			player.rock_crushed_player.connect(_on_rock_crushed_player)

	var dirt_layer = get_parent().get_node_or_null("Tilemaps/DirtLayer")
	if dirt_layer:
		if dirt_layer.has_signal("rock_wobbling"):
			dirt_layer.rock_wobbling.connect(_on_rock_wobbling)
		if dirt_layer.has_signal("rock_shattered"):
			dirt_layer.rock_shattered.connect(_on_rock_shattered)

func _on_rock_wobbling(pos: Vector2) -> void:
	_spawn_vfx(null, pos, Color("a8a8a8"))
	if _camera and _camera.has_method("shake"):
		_camera.shake(2.0)

func _on_rock_shattered(pos: Vector2) -> void:
	_spawn_vfx(null, pos, Color("555555"))
	if SoundManager:
		SoundManager.play_random_rock_dig_sfx()
	if _camera and _camera.has_method("shake"):
		_camera.shake(8.0)

func _on_rock_crushed_player(pos: Vector2) -> void:
	_spawn_vfx(null, pos, Color(1.0, 0.2, 0.2))
	_spawn_floating_text(pos, "🪨 CRUSHED! -3 BATTERY", Color(1.0, 0.2, 0.2))
	if SoundManager:
		SoundManager.play_random_rock_dig_sfx()
	if _camera and _camera.has_method("shake"):
		_camera.shake(10.0)

func _on_player_dug_tile(pos: Vector2) -> void:
	_spawn_vfx(dig_vfx, pos, Color("8b5a2b")) # Brown placeholder
	_play_sfx(dig_sfx, "Dig")
	
	var player = get_tree().get_first_node_in_group("player")
	if player and "_is_low_battery" in player and player._is_low_battery:
		_spawn_sputter_sparks(pos)

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

func _on_player_collected_gold(pos: Vector2) -> void:
	_spawn_vfx(null, pos, Color(1.0, 0.84, 0.0))
	_spawn_floating_text(pos, "+100", Color(1.0, 0.84, 0.0))
	_play_sfx(null, "✨ GOLD CHIME ✨")

func _on_player_collected_diamond(pos: Vector2) -> void:
	_spawn_vfx(null, pos, Color(0.0, 0.9, 1.0))
	_spawn_floating_text(pos, "+300", Color(0.0, 0.9, 1.0))
	_play_sfx(null, "💎 DIAMOND SPARKLE CHIME 💎")

func _spawn_floating_text(pos: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.global_position = pos + Vector2(-12, -8)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 10)
	add_child(label)
	
	var tween := create_tween()
	tween.parallel().tween_property(label, "global_position", pos + Vector2(-12, -24), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(label.queue_free)

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
	if stream and SoundManager:
		SoundManager.play_sfx(stream)


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


func _on_player_hit_mine(pos: Vector2) -> void:
	_play_sfx(null, "💥 MINE EXPLOSION BOOM 💥")
	if _camera and _camera.has_method("shake"):
		_camera.shake(12.0)
		
	var particles = CPUParticles2D.new()
	particles.global_position = pos
	particles.amount = 24
	particles.explosiveness = 1.0
	particles.one_shot = true
	particles.lifetime = 0.5
	particles.spread = 180.0
	particles.gravity = Vector2(0, 250.0)
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 120.0
	particles.scale_amount_min = 2.5
	particles.scale_amount_max = 5.5
	particles.color = Color(1.0, 0.3, 0.1) # Fiery Red-Orange Mine Explosion
	
	add_child(particles)
	particles.emitting = true
	
	var timer = get_tree().create_timer(particles.lifetime + 0.1)
	timer.timeout.connect(particles.queue_free)


func _spawn_sputter_sparks(pos: Vector2) -> void:
	_play_sfx(null, "⚡ Engine Sputter Spark SFX ⚡")
	var smoke = CPUParticles2D.new()
	smoke.global_position = pos
	smoke.amount = 8
	smoke.explosiveness = 1.0
	smoke.one_shot = true
	smoke.lifetime = 0.4
	smoke.spread = 180.0
	smoke.gravity = Vector2(0, -40.0)
	smoke.initial_velocity_min = 10.0
	smoke.initial_velocity_max = 25.0
	smoke.scale_amount_min = 2.0
	smoke.scale_amount_max = 4.0
	smoke.color = Color(0.2, 0.2, 0.2, 0.8) # Dark sputtering smoke puff
	add_child(smoke)
	smoke.emitting = true
	var timer1 = get_tree().create_timer(smoke.lifetime + 0.1)
	timer1.timeout.connect(smoke.queue_free)

	var sparks = CPUParticles2D.new()
	sparks.global_position = pos
	sparks.amount = 6
	sparks.explosiveness = 1.0
	sparks.one_shot = true
	sparks.lifetime = 0.25
	sparks.spread = 360.0
	sparks.gravity = Vector2(0, 150.0)
	sparks.initial_velocity_min = 30.0
	sparks.initial_velocity_max = 70.0
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.0
	sparks.color = Color(1.0, 0.85, 0.2) # Electric yellow sparks
	add_child(sparks)
	sparks.emitting = true
	var timer2 = get_tree().create_timer(sparks.lifetime + 0.1)
	timer2.timeout.connect(sparks.queue_free)


func _on_player_low_battery_warning(is_low: bool) -> void:
	if is_low:
		_play_sfx(null, "⚠️ Low Battery Alarm Beep ⚠️")
		# Sputtering dark smoke burst around vehicle
		var player = get_tree().get_first_node_in_group("player")
		if player:
			_spawn_sputter_sparks(player.global_position)


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



