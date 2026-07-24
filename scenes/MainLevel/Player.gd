extends CharacterBody2D

signal battery_changed(current: float, maximum: float)
signal bombs_changed(current: int, maximum: int)
signal gold_changed(current: int)
signal diamond_changed(current: int)
signal dug_tile(pos: Vector2)
signal moved_freely(pos: Vector2)
signal hit_wall(pos: Vector2)
signal collected_battery(pos: Vector2)
signal collected_gold(pos: Vector2)
signal collected_diamond(pos: Vector2)
signal detonated_bomb(pos: Vector2)
signal placed_bomb(pos: Vector2)
signal hit_rock(pos: Vector2)
signal hit_mine(pos: Vector2)
signal combo_changed(combo: int)
signal frenzy_level_changed(level: int)
signal low_battery_warning(is_low: bool)
signal battery_depleted(pos: Vector2)
signal depth_changed(current_depth: int, biome_name: String)
signal combo_timer_updated(ratio: float)
signal rock_crushed_player(pos: Vector2)

const TILE_SIZE: int = 16
const MAX_BATTERY: float = 10.0
const MOVE_SPEED_FREE: float = 160.0 # ~0.1s per tile
const MOVE_SPEED_DIRT: float = 53.0  # ~0.3s per tile
const MOVE_SPEED_FRENZY_L1: float = 85.0 # Slight speed boost for L1
const MOVE_SPEED_FRENZY: float = 120.0 # High speed super drill for L2-L4
const TILE_WALL: Vector2i = Vector2i(0, 0)
const TILE_CRACKED_ROCK: Vector2i = Vector2i(1, 0)
const TILE_ROCK: Vector2i = Vector2i(2, 0)
const TILE_MINE: Vector2i = Vector2i(3, 0)
const TILE_UNDIGGABLE: Vector2i = Vector2i(4, 0)
const TILE_DIRT: Vector2i = Vector2i(5, 0)
const TILE_BOMB: Vector2i = Vector2i(6, 0)
const TILE_BATTERY: Vector2i = Vector2i(7, 0)

const TILE_PLAIN: Vector2i = Vector2i(1, 1)
const TILE_DIAMOND: Vector2i = Vector2i(3, 1)
const TILE_GOLD: Vector2i = Vector2i(4, 1)
const TILE_BOMB_ONLY: Vector2i = Vector2i(5, 1)
const SOURCE_ID: int = 0
const BATTERY_RECHARGE_AMOUNT: float = 3.0
const MINE_BATTERY_DAMAGE: float = 4.0
const MAX_BOMBS: int = 3
const BOMB_BATTERY_COST: float = 3.0
const ROCK_DRILL_DELAY: float = 0.4
const LOW_BATTERY_THRESHOLD: float = 3.0
const COMBO_DECAY_TIME: float = 1.5

# Map horizontal bounds (tile columns 1-10 are playable)
const MAP_MIN_X: float = 1.0 * TILE_SIZE + TILE_SIZE * 0.5   # center of col 1
const MAP_MAX_X: float = 10.0 * TILE_SIZE + TILE_SIZE * 0.5  # center of col 10

@export var infinite_battery: bool = false

var battery: float = MAX_BATTERY
var bombs: int = MAX_BOMBS
var combo_count: int = 0
var _combo_decay_timer: float = 0.0
var _is_combo_timer_active: bool = false
var _active_placed_bombs: Array[Dictionary] = []
var _is_moving: bool = false
var _last_emitted_moving: bool = false
var _target_position: Vector2
var _current_move_speed: float = MOVE_SPEED_FREE
var _last_emitted_speed: float = -1.0
var _is_digging: bool = false
var _is_busy: bool = false
var _is_low_battery: bool = false
var _is_depleted: bool = false
var _low_bat_label: Label = null
var frenzy_level: int = 0
var current_depth: int = -1
var wealth: int = 0
var gold_count: int = 0
var diamond_count: int = 0
var is_frenzy: bool:
	get: return frenzy_level >= 1

@onready var _dirt_layer: TileMapLayer = $"../Tilemaps/DirtLayer"
@onready var _sprite: Sprite2D = $Sprite2D


func get_total_score() -> int:
	var depth_score: int = max(0, current_depth) * 10
	return depth_score + (gold_count * 100) + (diamond_count * 300)


func get_biome_name(depth: int) -> String:
	if depth < 4:
		return "Surface"
	elif depth <= 150:
		return "Layer 1: Normal Soil"
	elif depth <= 350:
		return "Layer 2: Rocky Soil"
	else:
		return "Layer 3: Ancient Mines"


func _update_depth_tracker() -> void:
	var new_depth: int = max(0, int(floor(_target_position.y / float(TILE_SIZE))))
	if new_depth != current_depth:
		current_depth = new_depth
		depth_changed.emit(current_depth, get_biome_name(current_depth))


func _ready() -> void:
	add_to_group("player")
	# Snap to nearest tile center on startup
	position = position.snapped(Vector2(TILE_SIZE, TILE_SIZE)) + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
	_target_position = global_position
	battery_changed.emit(battery, MAX_BATTERY)
	bombs_changed.emit(bombs, MAX_BOMBS)
	gold_changed.emit(gold_count)
	diamond_changed.emit(diamond_count)
	_update_depth_tracker()
	_connect_to_event_bus()
	
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
		if _last_emitted_moving:
			_last_emitted_moving = false
			if EventBus:
				EventBus.vehicle_movement_updated.emit(false, 0.0)
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
			_update_depth_tracker()

	if not _is_moving and not _is_busy:
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
				_start_combo_decay()
		else:
			_try_move(dir)

	if _is_moving != _last_emitted_moving or (_is_moving and _current_move_speed != _last_emitted_speed):
		_last_emitted_moving = _is_moving
		_last_emitted_speed = _current_move_speed
		if EventBus:
			EventBus.vehicle_movement_updated.emit(_is_moving, _current_move_speed)


func _clear_tile(cell: Vector2i) -> void:
	if _dirt_layer.has_method("clear_tile"):
		_dirt_layer.clear_tile(cell)
	else:
		_dirt_layer.set_cell(cell, SOURCE_ID, TILE_PLAIN)


func _try_move(dir: Vector2i) -> void:
	var current_pos := _target_position
	var target_pos := current_pos + Vector2(dir.x * TILE_SIZE, dir.y * TILE_SIZE)
	var target_cell: Vector2i = _dirt_layer.local_to_map(_dirt_layer.to_local(target_pos))
	var source_id: int = _dirt_layer.get_cell_source_id(target_cell)
	var atlas: Vector2i = _dirt_layer.get_cell_atlas_coords(target_cell) if source_id != -1 else Vector2i(-1, -1)
	var has_tile: bool = source_id != -1 and atlas != TILE_PLAIN

	# Intercept collectibles
	if has_tile:
		if atlas == TILE_BATTERY:
			_clear_tile(target_cell)
			_recharge_battery(BATTERY_RECHARGE_AMOUNT)
			wealth += 50
			_target_position = target_pos
			_current_move_speed = MOVE_SPEED_DIRT
			_is_moving = true
			_is_digging = true
			_increment_combo()
			collected_battery.emit(target_pos)
			_play_impact_lunge(dir)
			return
		elif atlas == TILE_BOMB:
			_clear_tile(target_cell)
			_collect_bomb()
			wealth += 100
			_target_position = target_pos
			_current_move_speed = MOVE_SPEED_DIRT
			_is_moving = true
			_is_digging = true
			_increment_combo()
			collected_gold.emit(target_pos)
			_play_impact_lunge(dir)
			return
		elif atlas == TILE_GOLD:
			_clear_tile(target_cell)
			_collect_gold()
			_target_position = target_pos
			_current_move_speed = MOVE_SPEED_DIRT
			_is_moving = true
			_is_digging = true
			_increment_combo()
			collected_gold.emit(target_pos)
			_play_impact_lunge(dir)
			return
		elif atlas == TILE_DIAMOND:
			_clear_tile(target_cell)
			_collect_diamond()
			_target_position = target_pos
			_current_move_speed = MOVE_SPEED_DIRT
			_is_moving = true
			_is_digging = true
			_increment_combo()
			collected_diamond.emit(target_pos)
			_play_impact_lunge(dir)
			return
		elif atlas == TILE_MINE:
			_clear_tile(target_cell)
			if is_frenzy:
				_current_move_speed = _get_frenzy_speed()
				_is_digging = true
				_increment_combo()
				dug_tile.emit(target_pos)
			else:
				_spend_battery(MINE_BATTERY_DAMAGE)
				_reset_combo()
				hit_mine.emit(target_pos)
				_current_move_speed = MOVE_SPEED_DIRT
				_is_digging = true
			_target_position = target_pos
			_is_moving = true
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
					_clear_tile(target_cell)
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
					_dirt_layer.set_cell(target_cell, SOURCE_ID, next_tile)
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
				_clear_tile(target_cell)
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
				_start_combo_decay()
				moved_freely.emit(target_pos)
			_target_position = target_pos
			_is_moving = true

		Vector2i(0, -1):  # ---- Up: dig if tile present (0.5 battery), step in ----
			if target_pos.y >= TILE_SIZE * 0.5:
				if has_tile:
					_clear_tile(target_cell)
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
					_start_combo_decay()
					moved_freely.emit(target_pos)
				_target_position = target_pos
				_is_moving = true
			else:
				_trigger_wall_hit(target_pos, dir)

		_:                # ---- Horizontal: blocked by map edges, dig if tile present (0.5 battery) ----
			var in_bounds: bool = target_pos.x >= MAP_MIN_X and target_pos.x <= MAP_MAX_X
			if in_bounds:
				if has_tile:
					_clear_tile(target_cell)
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
					_start_combo_decay()
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
	if _is_combo_timer_active and combo_count > 0:
		_combo_decay_timer -= delta
		var ratio: float = clampf(_combo_decay_timer / COMBO_DECAY_TIME, 0.0, 1.0)
		combo_timer_updated.emit(ratio)
		if _combo_decay_timer <= 0.0:
			_reset_combo()

	if _active_placed_bombs.size() > 0:
		var to_detonate: Array[Dictionary] = []
		for bomb in _active_placed_bombs:
			bomb["timer"] -= delta
			if bomb["timer"] <= 0.0:
				to_detonate.append(bomb)
		for bomb in to_detonate:
			_explode_single_bomb(bomb)

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


func _start_combo_decay() -> void:
	if combo_count > 0 and not _is_combo_timer_active:
		_is_combo_timer_active = true
		_combo_decay_timer = COMBO_DECAY_TIME
		combo_timer_updated.emit(1.0)


func _increment_combo() -> void:
	combo_count += 1
	_is_combo_timer_active = true
	_combo_decay_timer = COMBO_DECAY_TIME
	combo_timer_updated.emit(1.0)

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
	_combo_decay_timer = 0.0
	_is_combo_timer_active = false
	combo_timer_updated.emit(0.0)
	if combo_count > 0:
		combo_count = 0
		if frenzy_level > 0:
			frenzy_level = 0
			frenzy_level_changed.emit(0)
		combo_changed.emit(combo_count)


func take_rock_crush_damage(amount: float = 3.0) -> void:
	if _is_depleted:
		return
	_spend_battery(amount)
	_reset_combo()
	rock_crushed_player.emit(global_position)
	_play_crush_animation()


func _play_crush_animation() -> void:
	var tween := create_tween()
	# Phase 1: Rapid squash into extreme pancake shape (2.0x width, 0.2x height) + crimson flash + ground anchor Y-offset (+6px)
	tween.tween_property(_sprite, "scale", Vector2(2.0, 0.2), 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_sprite, "position", Vector2(0, 6.0), 0.04)
	tween.parallel().tween_property(_sprite, "modulate", Color(2.5, 0.2, 0.2), 0.04)
	
	# Phase 2: Hold pancake shape for 0.20s so visual squish is crystal clear
	tween.tween_interval(0.20)
	
	# Phase 3: Recoil back to normal scale, position, and color over 0.25s using spring easing
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_sprite, "position", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_sprite, "modulate", Color.WHITE, 0.25)


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
			_clear_tile(perp1)
		if _dirt_layer.get_cell_atlas_coords(perp2) == TILE_DIRT:
			_clear_tile(perp2)


func _collect_bomb() -> void:
	if bombs < MAX_BOMBS:
		bombs += 1
		bombs_changed.emit(bombs, MAX_BOMBS)


func _collect_gold() -> void:
	gold_count += 1
	gold_changed.emit(gold_count)


func _collect_diamond() -> void:
	diamond_count += 1
	diamond_changed.emit(diamond_count)


func _detonate_bomb() -> void:
	# If a bomb is already active on the field -> REMOTE DETONATION!
	if _active_placed_bombs.size() > 0:
		_remote_detonate_all_bombs()
		return

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
	bomb_sprite.region_rect = Rect2(85, 17, 16, 16)
	bomb_sprite.global_position = bomb_pos
	bomb_sprite.z_index = 5
	get_parent().add_child(bomb_sprite)
	
	bomb_sprite.scale = Vector2(0.1, 0.1)
	var scale_tween := bomb_sprite.create_tween()
	scale_tween.tween_property(bomb_sprite, "scale", Vector2(1.5, 1.5), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(bomb_sprite, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	placed_bomb.emit(bomb_pos)
	
	# Blinking animation
	var blink_tween := bomb_sprite.create_tween()
	blink_tween.set_loops(8)
	blink_tween.tween_property(bomb_sprite, "modulate", Color(1, 0, 0), 0.125)
	blink_tween.tween_property(bomb_sprite, "modulate", Color(1, 1, 1), 0.125)
	
	var bomb_data := {
		"cell": current_cell,
		"pos": bomb_pos,
		"sprite": bomb_sprite,
		"timer": 2.0
	}
	_active_placed_bombs.append(bomb_data)


func _remote_detonate_all_bombs() -> void:
	var bombs_copy := _active_placed_bombs.duplicate()
	_active_placed_bombs.clear()
	for bomb in bombs_copy:
		_explode_single_bomb(bomb)


func _explode_single_bomb(bomb_data: Dictionary) -> void:
	if _active_placed_bombs.has(bomb_data):
		_active_placed_bombs.erase(bomb_data)

	var bomb_sprite = bomb_data.get("sprite", null)
	if is_instance_valid(bomb_sprite):
		bomb_sprite.queue_free()

	var origin_cell: Vector2i = bomb_data["cell"]
	var bomb_pos: Vector2 = bomb_data["pos"]

	detonated_bomb.emit(bomb_pos)
	
	# Execute Step-by-Step 4-Way Cross-Blast Wave (+ Pattern - 0.04s per step)
	await _dirt_layer.explode_cross_pattern(origin_cell, 6, self)

func _connect_to_event_bus() -> void:
	if not EventBus:
		return
	dug_tile.connect(func(pos): EventBus.dug_tile.emit(pos, Color("8b5a2b")))
	moved_freely.connect(func(pos): EventBus.moved_freely.emit(pos))
	hit_wall.connect(func(pos): EventBus.hit_wall.emit(pos))
	hit_rock.connect(func(pos): EventBus.hit_rock.emit(pos))
	hit_mine.connect(func(pos): EventBus.hit_mine.emit(pos))
	collected_battery.connect(func(pos): EventBus.collected_battery.emit(pos))
	collected_gold.connect(func(pos): EventBus.collected_gold.emit(pos))
	collected_diamond.connect(func(pos): EventBus.collected_diamond.emit(pos))
	placed_bomb.connect(func(pos): EventBus.placed_bomb.emit(pos))
	detonated_bomb.connect(func(pos): EventBus.detonated_bomb.emit(pos))
	low_battery_warning.connect(func(is_low): EventBus.low_battery_warning.emit(is_low))
	battery_depleted.connect(func(pos): EventBus.battery_depleted.emit(pos))
	frenzy_level_changed.connect(func(level): EventBus.frenzy_tier_changed.emit(level))

