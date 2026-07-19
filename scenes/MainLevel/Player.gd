extends CharacterBody2D

signal battery_changed(current: float, maximum: float)
signal bombs_changed(current: int, maximum: int)
signal dug_tile(pos: Vector2)
signal moved_freely(pos: Vector2)
signal hit_wall(pos: Vector2)
signal collected_battery(pos: Vector2)
signal detonated_bomb(pos: Vector2)
signal placed_bomb(pos: Vector2)
signal combo_changed(combo: int)

const TILE_SIZE: int = 16
const MAX_BATTERY: float = 10.0
const MOVE_SPEED_FREE: float = 160.0 # ~0.1s per tile
const MOVE_SPEED_DIRT: float = 53.0  # ~0.3s per tile
const TILE_BATTERY: Vector2i = Vector2i(47, 9)
const BATTERY_RECHARGE_AMOUNT: float = 3.0
const TILE_BOMB: Vector2i = Vector2i(45, 9)
const MAX_BOMBS: int = 3
const BOMB_BATTERY_COST: float = 3.0

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

@onready var _dirt_layer: TileMapLayer = $"../Tilemaps/DirtLayer"
@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("player")
	# Snap to nearest tile center on startup
	position = position.snapped(Vector2(TILE_SIZE, TILE_SIZE)) + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
	_target_position = global_position
	battery_changed.emit(battery, MAX_BATTERY)
	bombs_changed.emit(bombs, MAX_BOMBS)


func _physics_process(delta: float) -> void:
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

	if Input.is_action_just_pressed("ui_accept"):
		_detonate_bomb()
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
			return
		elif atlas == TILE_BOMB:
			_dirt_layer.erase_cell(target_cell)
			_collect_bomb()
			_target_position = target_pos
			_current_move_speed = MOVE_SPEED_DIRT
			_is_moving = true
			_is_digging = true
			_increment_combo()
			return

	match dir:
		Vector2i(0, 1):   # ---- Down: dig if tile present (1.0 battery), always step in ----
			if has_tile:
				_dirt_layer.erase_cell(target_cell)
				_spend_battery(1.0)
				_current_move_speed = MOVE_SPEED_DIRT
				_is_digging = true
				_increment_combo()
				dug_tile.emit(target_pos)
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
					_current_move_speed = MOVE_SPEED_DIRT
					_is_digging = true
					_increment_combo()
					dug_tile.emit(target_pos)
				else:
					_current_move_speed = MOVE_SPEED_FREE
					_is_digging = false
					_reset_combo()
					moved_freely.emit(target_pos)
				_target_position = target_pos
				_is_moving = true
			else:
				_reset_combo()
				hit_wall.emit(target_pos)

		_:                # ---- Horizontal: blocked by map edges, dig if tile present (0.5 battery) ----
			var in_bounds: bool = target_pos.x >= MAP_MIN_X and target_pos.x <= MAP_MAX_X
			if in_bounds:
				if has_tile:
					_dirt_layer.erase_cell(target_cell)
					_spend_battery(0.5)
					_current_move_speed = MOVE_SPEED_DIRT
					_is_digging = true
					_increment_combo()
					dug_tile.emit(target_pos)
				else:
					_current_move_speed = MOVE_SPEED_FREE
					_is_digging = false
					_reset_combo()
					moved_freely.emit(target_pos)
				_target_position = target_pos
				_is_moving = true
			else:
				_reset_combo()
				hit_wall.emit(target_pos)


func _spend_battery(amount: float) -> void:
	if infinite_battery:
		return
	battery = maxf(0.0, battery - amount)
	battery_changed.emit(battery, MAX_BATTERY)


func _recharge_battery(amount: float) -> void:
	battery = minf(MAX_BATTERY, battery + amount)
	battery_changed.emit(battery, MAX_BATTERY)


func _increment_combo() -> void:
	combo_count += 1
	combo_changed.emit(combo_count)


func _reset_combo() -> void:
	if combo_count > 0:
		combo_count = 0
		combo_changed.emit(combo_count)


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
	
	var bomb_pos := global_position
	var current_cell: Vector2i = _dirt_layer.local_to_map(_dirt_layer.to_local(bomb_pos))
	
	# Create bomb sprite
	var bomb_sprite := Sprite2D.new()
	bomb_sprite.texture = _sprite.texture
	bomb_sprite.region_enabled = true
	# Atlas coordinate (45, 9) with 1px spacing: x = 45 * 17 = 765, y = 9 * 17 = 153
	bomb_sprite.region_rect = Rect2(765, 153, 16, 16)
	bomb_sprite.global_position = bomb_pos
	bomb_sprite.z_index = 5
	get_parent().add_child(bomb_sprite)
	
	bomb_sprite.scale = Vector2(0.5, 0.5)
	var scale_tween := bomb_sprite.create_tween()
	scale_tween.tween_property(bomb_sprite, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	
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

