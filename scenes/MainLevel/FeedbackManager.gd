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
var _tex_fire_h: AtlasTexture
var _tex_fire_v: AtlasTexture

func _ready() -> void:
	var tile_sheet: Texture2D = preload("res://assets/GameSpecificTiles.png")
	_tex_fire_h = AtlasTexture.new()
	_tex_fire_h.atlas = tile_sheet
	_tex_fire_h.region = Rect2(119, 34, 16, 16) # Tile (7, 2) Horizontal Fire Pillar

	_tex_fire_v = AtlasTexture.new()
	_tex_fire_v.atlas = tile_sheet
	_tex_fire_v.region = Rect2(119, 51, 16, 16) # Tile (7, 3) Vertical Fire Pillar

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
		if dirt_layer.has_signal("rock_settled"):
			dirt_layer.rock_settled.connect(_on_rock_settled)
		if dirt_layer.has_signal("cross_blast_step"):
			dirt_layer.cross_blast_step.connect(_on_cross_blast_step)

func _on_rock_wobbling(pos: Vector2) -> void:
	_spawn_vfx(null, pos, Color("a8a8a8"))
	if SoundManager:
		SoundManager.play_random_dig_sfx()
	if _camera and _camera.has_method("shake"):
		_camera.shake(2.0)

func _on_rock_settled(pos: Vector2) -> void:
	_spawn_vfx(null, pos, Color("777777"))
	if SoundManager:
		SoundManager.play_random_rock_dig_sfx()
	if _camera and _camera.has_method("shake"):
		_camera.shake(5.0)

func _on_rock_shattered(pos: Vector2) -> void:
	_spawn_vfx(null, pos, Color("555555"))
	if SoundManager:
		SoundManager.play_random_rock_dig_sfx()
	if _camera and _camera.has_method("shake"):
		_camera.shake(8.0)

func _on_rock_crushed_player(pos: Vector2) -> void:
	# 1. 20 Dark Stone Fragments Burst
	var stone_particles = CPUParticles2D.new()
	stone_particles.global_position = pos
	stone_particles.amount = 20
	stone_particles.explosiveness = 1.0
	stone_particles.one_shot = true
	stone_particles.lifetime = 0.5
	stone_particles.spread = 180.0
	stone_particles.gravity = Vector2(0, 400.0)
	stone_particles.initial_velocity_min = 60.0
	stone_particles.initial_velocity_max = 140.0
	stone_particles.scale_amount_min = 3.0
	stone_particles.scale_amount_max = 6.0
	stone_particles.color = Color(0.3, 0.3, 0.35)
	add_child(stone_particles)
	stone_particles.emitting = true
	var timer1 := get_tree().create_timer(0.6)
	timer1.timeout.connect(stone_particles.queue_free)

	# 2. 10 Dust Cloud Particles Burst
	var dust_particles = CPUParticles2D.new()
	dust_particles.global_position = pos
	dust_particles.amount = 10
	dust_particles.explosiveness = 0.9
	dust_particles.one_shot = true
	dust_particles.lifetime = 0.4
	dust_particles.spread = 180.0
	dust_particles.gravity = Vector2(0, -50.0)
	dust_particles.initial_velocity_min = 20.0
	dust_particles.initial_velocity_max = 60.0
	dust_particles.scale_amount_min = 4.0
	dust_particles.scale_amount_max = 8.0
	dust_particles.color = Color(0.7, 0.6, 0.5, 0.6)
	add_child(dust_particles)
	dust_particles.emitting = true
	var timer2 := get_tree().create_timer(0.5)
	timer2.timeout.connect(dust_particles.queue_free)

	# 3. 14.0px Heavy Camera Shake & Audio
	if SoundManager:
		SoundManager.play_random_rock_dig_sfx()
	if _camera and _camera.has_method("shake"):
		_camera.shake(14.0)

	# 4. Bold Arcade Floating Text Popup ("💥 CRUSHED! -3.0⚡")
	_spawn_floating_text(pos, "💥 CRUSHED! -3.0⚡", Color(1.0, 0.25, 0.25))

	# 5. Red Full-Screen Impact Flash Overlay
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 20
	var flash_rect := ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1.0, 0.0, 0.0, 0.55)
	canvas_layer.add_child(flash_rect)
	add_child(canvas_layer)

	var tween := create_tween()
	tween.tween_property(flash_rect, "color", Color(1.0, 0.0, 0.0, 0.0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(canvas_layer.queue_free)


func _on_cross_blast_step(origin_cell: Vector2i, h_step_cells: Array, v_step_cells: Array) -> void:
	var dirt_layer = get_parent().get_node_or_null("Tilemaps/DirtLayer")
	if not dirt_layer:
		return

	if _camera and _camera.has_method("shake"):
		_camera.shake(4.0)

	var spawn_fire_tile = func(cell: Vector2i, texture: AtlasTexture):
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.global_position = dirt_layer.to_global(dirt_layer.map_to_local(cell))
		sprite.z_index = 6
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)

		sprite.scale = Vector2(0.2, 0.2)
		var tween := sprite.create_tween()
		tween.parallel().tween_property(sprite, "scale", Vector2(1.35, 1.35), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(sprite, "modulate", Color(1.8, 1.3, 0.8, 1.0), 0.07)

		tween.tween_property(sprite, "scale", Vector2.ONE, 0.08)
		tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.25)
		tween.tween_callback(sprite.queue_free)

	# Spawn Horizontal Fire Pillars (7, 2) on Left/Right cells for this ring step
	for cell in h_step_cells:
		spawn_fire_tile.call(cell, _tex_fire_h)

	# Spawn Vertical Fire Pillars (7, 3) on Up/Down cells for this ring step
	for cell in v_step_cells:
		spawn_fire_tile.call(cell, _tex_fire_v)

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
	if _camera and _camera.has_method("shake"):
		_camera.shake(12.0)

	# 1. Central Fiery Burst
	var center_particles = CPUParticles2D.new()
	center_particles.global_position = pos
	center_particles.amount = 24
	center_particles.explosiveness = 1.0
	center_particles.one_shot = true
	center_particles.lifetime = 0.5
	center_particles.spread = 180.0
	center_particles.gravity = Vector2(0, 100.0)
	center_particles.initial_velocity_min = 60.0
	center_particles.initial_velocity_max = 120.0
	center_particles.scale_amount_min = 3.0
	center_particles.scale_amount_max = 6.0
	center_particles.color = Color(1.0, 0.4, 0.0)
	add_child(center_particles)
	center_particles.emitting = true
	var timer1 := get_tree().create_timer(0.6)
	timer1.timeout.connect(center_particles.queue_free)

	# 2. 4-Way Cardinal Cross Blast Streams (+ Pattern - 6 Tiles Range)
	var angles := [0.0, 90.0, 180.0, 270.0]
	for angle in angles:
		var p = CPUParticles2D.new()
		p.global_position = pos
		p.amount = 18
		p.explosiveness = 0.95
		p.one_shot = true
		p.lifetime = 0.5
		p.direction = Vector2.RIGHT.rotated(deg_to_rad(angle))
		p.spread = 8.0 # Narrow beam along cardinal direction
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = 180.0
		p.initial_velocity_max = 280.0
		p.scale_amount_min = 2.0
		p.scale_amount_max = 5.0
		p.color = Color(1.0, 0.8, 0.1) # Bright Golden Fire Wave
		add_child(p)
		p.emitting = true
		var timer2 := get_tree().create_timer(0.6)
		timer2.timeout.connect(p.queue_free)


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



