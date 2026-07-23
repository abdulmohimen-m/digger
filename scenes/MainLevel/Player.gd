extends CharacterBody2D

signal battery_changed(current: float, maximum: float)
signal bombs_changed(current: int, maximum: int)
signal dug_tile(pos: Vector2)
signal moved_freely(pos: Vector2)
signal hit_wall(pos: Vector2)
signal collected_battery(pos: Vector2)
signal detonated_bomb(pos: Vector2)
signal placed_bomb(pos: Vector2)
signal hit_rock(pos: Vector2)
signal combo_changed(combo: int)
signal frenzy_level_changed(level: int)
signal low_battery_warning(is_low: bool)
signal battery_depleted(pos: Vector2)

const TILE_SIZE: int = 16
const MAX_BATTERY: float = 10.0
const MOVE_SPEED_FREE: float = 160.0 # ~0.1s per tile
const MOVE_SPEED_DIRT: float = 53.0  # ~0.3s per tile
const MOVE_SPEED_FRENZY_L1: float = 85.0 # Slight speed boost for L1
const MOVE_SPEED_FRENZY: float = 120.0 # High speed super drill for L2-L4
const TILE_BATTERY: Vector2i = Vector2i(47, 9)
const BATTERY_RECHARGE_AMOUNT: float = 3.0
const TILE_BOMB: Vector2i = Vector2i(45, 9)
const TILE_UNDIGGABLE: Vector2i = Vector2i(39, 15)
const TILE_WALL: Vector2i = Vector2i(3, 0)
const TILE_ROCK: Vector2i = Vector2i(10, 17)
const TILE_CRACKED_ROCK: Vector2i = Vector2i(11, 17)
const TILE_DIRT: Vector2i = Vector2i(32, 15)
const MAX_BOMBS: int = 3
const BOMB_BATTERY_COST: float = 3.0
const ROCK_DRILL_DELAY: float = 0.4
const LOW_BATTERY_THRESHOLD: float = 3.0

# Map horizontal bounds (tile columns 1-10 are playable)
const MAP_MIN_X: float = 1.0 * TILE_SIZE + TILE_SIZE * 0.5   # center of col 1
const MAP_MAX_X: float = 10.0 * TILE_SIZE + TILE_SIZE * 0.5  # center of col 10

@export var infinite_battery: bool = false

var battery: float = MAX_BATTERY
var bombs: int = MAX_BOMBS
var combo_count: int = 0
var _is_moving: bool = false
var _target_position: Vector2
var _current_move_speed: float = MOVE_SPEED_FREE
var _is_digging: bool = false
var _is_busy: bool = false
var _is_low_battery: bool = false
var _is_depleted: bool = false
var _low_bat_label: Label = null
var frenzy_level: int = 0
var is_frenzy: bool:
	get: return frenzy_level >= 1

@onready var _dirt_layer: TileMapLayer = $"../Tilemaps/DirtLayer"
@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("player")
	# Snap to nearest tile center on startup
	position = position.snapped(Vector2(TILE_SIZE, TILE_SIZE)) + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
	_target_position = global_position
	battery_changed.emit(battery, MAX_BATTERY)
	bombs_changed.emit(bombs, MAX_BOMBS)
	
	# Setup floating LOW BAT warning icon above vehicle
	_low_bat_label = Label.new()
	_low_bat_label.text = "⚠️ LOW BAT"
	_low_bat_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	_low_bat_label.add_theme_font_size_override("font_size", 9)
	_low_bat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_low_bat_label.position = Vector2(-24, -18)
	_low_bat_label.custom_minimum_size = Vector2(48, 12)
	_low_bat_label.visible = false
	add_child(_low_bat_label)


func _physics_process(delta: float) -> void:
	# Frozen if battery is out
	if battery <= 0.0:
		return

	if Input.is_action_just_pressed("ui_accept"):
		_detonate_bomb()

	if _is_moving or _is_busy:
		if _is_moving:
			global_position = global_position.move_toward(_target_position, _current_move_speed * delta)
		if _is_digging:
			_sprite.position = Vector2(
				randf_range(-1.5, 1.5),
				randf_range(-1.5, 1.5)
			)
		if global_position == _target_position:
			_is_moving = false
			_is_digging = false
			_sprite.position = Vector2.ZERO
		return

	# Frozen if battery is out and we are not currently moving
	if battery <= 0.0:
		return

	var dir := Vector2i.ZERO
	if Input.is_action_pressed("ui_right"):
		dir = Vector2i(1, 0)
	elif Input.is_action_pressed("ui_left"):
		dir = Vector2i(-1, 0)
	elif Input.is_action_pressed("ui_down"):
		dir = Vector2i(0, 1)
	elif Input.is_action_pressed("ui_up"):
		dir = Vector2i(0, -1)

	if dir == Vector2i.ZERO:
		if combo_count > 0:
			_reset_combo()
		return

	_try_move(dir)


func _try_move(dir: Vector2i) -> void:
	var current_pos := _target_position
	var target_pos := current_pos + Vector2(dir.x * TILE_SIZE, dir.y * TILE_SIZE)
	var target_cell: Vector2i = _dirt_layer.local_to_map(_dirt_layer.to_local(target_pos))
	var source_id: int = _dirt_layer.get_cell_source_id(target_cell)
	var has_tile: bool = source_id != -1

	# Intercept collectibles
	if has_tile:
		var atlas: Vector2i = _dirt_layer.get_cell_atlas_coords(target_cell)
		if atlas == TILE_BATTERY:
			_dirt_layer.erase_cell(target_cell)
			_recharge_battery(BATTERY_RECHARGE_AMOUNT)
			_target_position = target_pos
			_current_move_speed = MOVE_SPEED_DIRT
			_is_moving = true
			_is_digging = true
			_increment_combo()
			collected_battery.emit(target_pos)
			_play_impact_lunge(dir)
			return
		elif atlas == TILE_BOMB:
			_dirt_layer.erase_cell(target_cell)
			_collect_bomb()
			_target_position = target_pos
			_current_move_speed = MOVE_SPEED_DIRT
			_is_moving = true
			_is_digging = true
			_increment_combo()
			_play_impact_lunge(dir)
			return
		elif atlas == TILE_UNDIGGABLE or atlas == TILE_WALL:
			_trigger_wall_hit(target_pos, dir)
			return
		elif atlas == TILE_ROCK or atlas == TILE_CRACKED_ROCK:
			var in_bounds: bool = true
			if dir == Vector2i(0, -1):
				in_bounds = target_pos.y >= TILE_SIZE * 0.5
			elif dir.x != 0:
				in_bounds = target_pos.x >= MAP_MIN_X and target_pos.x <= MAP_MAX_X
			
			if in_bounds:
				if frenzy_level >= 5:
					_dirt_layer.erase_cell(target_cell)
					_spend_battery(1.0)
					_target_position = target_pos
					_current_move_speed = _get_frenzy_speed()
					_is_moving = true
					_is_digging = true
					_increment_combo()
					_on_tile_dug_effects(target_cell, dir)
					hit_rock.emit(target_pos)
					_play_impact_lunge(dir)
				else:
					_is_busy = true
					var next_tile: Vector2i = TILE_CRACKED_ROCK if atlas == TILE_ROCK else TILE_DIRT
					_dirt_layer.set_cell(target_cell, 1, next_tile)
					var cost: float = 1.0 if dir == Vector2i(0, 1) else 0.5
					_spend_battery(cost)
					_increment_combo()
					hit_rock.emit(target_pos)
					_play_impact_lunge(dir)
					
					await get_tree().create_timer(0.3).timeout
					_is_busy = false
			else:
				_trigger_wall_hit(target_pos, dir)
			return

	match dir:
		Vector2i(0, 1):   # ---- Down: dig if tile present (1.0 battery), always step in ----
			if has_tile:
				_dirt_layer.erase_cell(target_cell)
				_spend_battery(1.0)
				_current_move_speed = _get_frenzy_speed()
				_is_digging = true
				_increment_combo()
				_on_tile_dug_effects(target_cell, dir)
				dug_tile.emit(target_pos)
				_play_impact_lunge(dir)
			else:
				_current_move_speed = MOVE_SPEED_FREE
				_is_digging = false
				_reset_combo()
				moved_freely.emit(target_pos)
			_target_position = target_pos
			_is_moving = true

		Vector2i(0, -1):  # ---- Up: dig if tile present (0.5 battery), step in ----
			if target_pos.y >= TILE_SIZE * 0.5:
				if has_tile:
					_dirt_layer.erase_cell(target_cell)
					_spend_battery(0.5)
					_current_move_speed = _get_frenzy_speed()
					_is_digging = true
					_increment_combo()
					_on_tile_dug_effects(target_cell, dir)
					dug_tile.emit(target_pos)
					_play_impact_lunge(dir)
				else:
					_current_move_speed = MOVE_SPEED_FREE
					_is_digging = false
					_reset_combo()
					moved_freely.emit(target_pos)
				_target_position = target_pos
				_is_moving = true
			else:
				_trigger_wall_hit(target_pos, dir)

		_:                # ---- Horizontal: blocked by map edges, dig if tile present (0.5 battery) ----
			var in_bounds: bool = target_pos.x >= MAP_MIN_X and target_pos.x <= MAP_MAX_X
			if in_bounds:
				if has_tile:
					_dirt_layer.erase_cell(target_cell)
					_spend_battery(0.5)
					_current_move_speed = _get_frenzy_speed()
					_is_digging = true
					_increment_combo()
					_on_tile_dug_effects(target_cell, dir)
					dug_tile.emit(target_pos)
					_play_impact_lunge(dir)
				else:
					_current_move_speed = MOVE_SPEED_FREE
					_is_digging = false
					_reset_combo()
					moved_freely.emit(target_pos)
				_target_position = target_pos
				_is_moving = true
			else:
				_trigger_wall_hit(target_pos, dir)


func _trigger_wall_hit(target_pos: Vector2, dir: Vector2i) -> void:
	_is_busy = true
	_reset_combo()
	_play_impact_lunge(dir)
	hit_wall.emit(target_pos)
	await get_tree().create_timer(0.3).timeout
	_is_busy = false


func _play_impact_lunge(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	
	var tween := create_tween()
	var lunge_offset := Vector2(dir.x * 4.0, dir.y * 4.0)
	var squash_scale := Vector2(1.25, 0.75) if dir.x != 0 else Vector2(0.75, 1.25)
	
	tween.tween_property(_sprite, "position", lunge_offset, 0.05)
	tween.parallel().tween_property(_sprite, "scale", squash_scale, 0.05)
	
	tween.tween_property(_sprite, "position", Vector2.ZERO, 0.12).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_sprite, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)


func _spend_battery(amount: float) -> void:
	if infinite_battery or is_frenzy or _is_depleted:
		return
	battery = maxf(0.0, battery - amount)
	battery_changed.emit(battery, MAX_BATTERY)
	_check_battery_state()


func _recharge_battery(amount: float) -> void:
	if _is_depleted:
		return
	battery = minf(MAX_BATTERY, battery + amount)
	battery_changed.emit(battery, MAX_BATTERY)
	_check_battery_state()


func _process(delta: float) -> void:
	if _is_low_battery and _low_bat_label and _low_bat_label.visible:
		var pulse: float = (sin(Time.get_ticks_msec() * 0.012) + 1.0) * 0.5
		_low_bat_label.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.2, 0.2), pulse)
		var scale_factor: float = 0.9 + pulse * 0.25
		_low_bat_label.scale = Vector2(scale_factor, scale_factor)
		_low_bat_label.pivot_offset = _low_bat_label.size * 0.5


func _check_battery_state() -> void:
	var is_low: bool = battery <= LOW_BATTERY_THRESHOLD and battery > 0.0
	if is_low != _is_low_battery:
		_is_low_battery = is_low
		if _low_bat_label:
			_low_bat_label.visible = _is_low_battery
		low_battery_warning.emit(_is_low_battery)
		
	if battery <= 0.0 and not _is_depleted:
		_trigger_battery_depletion()


func _trigger_battery_depletion() -> void:
	_is_depleted = true
	_is_busy = true
	if _low_bat_label:
		_low_bat_label.visible = false
	if _is_low_battery:
		_is_low_battery = false
		low_battery_warning.emit(false)
		
	battery_depleted.emit(global_position)
	
	# Breakdown Animation (1.0s total): Stutter shake + Dim sprite to unpowered gray
	var tween := create_tween()
	tween.set_loops(4)
	tween.tween_property(_sprite, "position", Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)), 0.06)
	tween.tween_property(_sprite, "position", Vector2.ZERO, 0.06)
	
	var scale_tween := create_tween()
	scale_tween.tween_property(_sprite, "scale", Vector2(1.3, 0.7), 0.1)
	scale_tween.tween_property(_sprite, "scale", Vector2(0.8, 1.2), 0.1)
	scale_tween.tween_property(_sprite, "scale", Vector2.ONE, 0.1)
	
	var color_tween := create_tween()
	color_tween.tween_property(_sprite, "modulate", Color(0.25, 0.25, 0.30), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await get_tree().create_timer(1.0).timeout
	_is_busy = false


func _increment_combo() -> void:
	combo_count += 1
	var new_level: int = 0
	if combo_count >= 50:
		new_level = 5
	elif combo_count >= 40:
		new_level = 4
	elif combo_count >= 30:
		new_level = 3
	elif combo_count >= 20:
		new_level = 2
	elif combo_count >= 10:
		new_level = 1
		
	if new_level != frenzy_level:
		frenzy_level = new_level
		if frenzy_level == 5:
			_recharge_battery(MAX_BATTERY)
			bombs = MAX_BOMBS
			bombs_changed.emit(bombs, MAX_BOMBS)
		frenzy_level_changed.emit(frenzy_level)
		
	combo_changed.emit(combo_count)


func _reset_combo() -> void:
	if combo_count > 0:
		combo_count = 0
		if frenzy_level > 0:
			frenzy_level = 0
			frenzy_level_changed.emit(0)
		combo_changed.emit(combo_count)


func _get_frenzy_speed() -> float:
	if frenzy_level >= 5:
		return MOVE_SPEED_FREE
	elif frenzy_level >= 2:
		return MOVE_SPEED_FRENZY
	elif frenzy_level >= 1:
		return MOVE_SPEED_FRENZY_L1
	return MOVE_SPEED_DIRT


func _on_tile_dug_effects(cell: Vector2i, dir: Vector2i) -> void:
	if frenzy_level >= 3:
		_recharge_battery(0.5)
		
	if frenzy_level >= 4 and dir != Vector2i.ZERO:
		var perp1 := cell + Vector2i(-dir.y, dir.x)
		var perp2 := cell + Vector2i(dir.y, -dir.x)
		if _dirt_layer.get_cell_atlas_coords(perp1) == TILE_DIRT:
			_dirt_layer.erase_cell(perp1)
		if _dirt_layer.get_cell_atlas_coords(perp2) == TILE_DIRT:
			_dirt_layer.erase_cell(perp2)


func _collect_bomb() -> void:
	if bombs < MAX_BOMBS:
		bombs += 1
		bombs_changed.emit(bombs, MAX_BOMBS)


func _detonate_bomb() -> void:
	if bombs <= 0 or battery < BOMB_BATTERY_COST:
		return
		
	bombs -= 1
	bombs_changed.emit(bombs, MAX_BOMBS)
	_spend_battery(BOMB_BATTERY_COST)
	
	var current_cell: Vector2i = _dirt_layer.local_to_map(_dirt_layer.to_local(global_position))
	var bomb_pos: Vector2 = _dirt_layer.to_global(_dirt_layer.map_to_local(current_cell))
	
	# Create bomb sprite
	var bomb_sprite := Sprite2D.new()
	bomb_sprite.texture = _sprite.texture
	bomb_sprite.region_enabled = true
	# Atlas coordinate (45, 9) with 1px spacing: x = 45 * 17 = 765, y = 9 * 17 = 153
	bomb_sprite.region_rect = Rect2(765, 153, 16, 16)
	bomb_sprite.global_position = bomb_pos
	bomb_sprite.z_index = 5
	get_parent().add_child(bomb_sprite)
	
	bomb_sprite.scale = Vector2(0.1, 0.1)
	var scale_tween := bomb_sprite.create_tween()
	scale_tween.tween_property(bomb_sprite, "scale", Vector2(1.5, 1.5), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(bomb_sprite, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	placed_bomb.emit(bomb_pos)
	
	# Blinking animation
	var tween := bomb_sprite.create_tween()
	tween.set_loops(4)
	tween.tween_property(bomb_sprite, "modulate", Color(1, 0, 0), 0.25)
	tween.tween_property(bomb_sprite, "modulate", Color(1, 1, 1), 0.25)
	
	# Wait for 2 seconds
	await get_tree().create_timer(2.0).timeout
	
	if is_instance_valid(bomb_sprite):
		bomb_sprite.queue_free()
	
	# Clear 3x3 area
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var target_cell: Vector2i = current_cell + Vector2i(dx, dy)
			if _dirt_layer.get_cell_source_id(target_cell) != -1:
				var atlas: Vector2i = _dirt_layer.get_cell_atlas_coords(target_cell)
				if atlas != Vector2i(3, 0):
					_dirt_layer.erase_cell(target_cell)
					
	# Check if player is caught in the blast (Chebyshev distance in grid cells)
	var player_cell := _dirt_layer.local_to_map(_dirt_layer.to_local(global_position))
	var cell_diff := player_cell - current_cell
	if abs(cell_diff.x) <= 1 and abs(cell_diff.y) <= 1:
		_spend_battery(5.0)
					
	detonated_bomb.emit(bomb_pos)

