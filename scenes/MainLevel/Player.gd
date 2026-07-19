extends CharacterBody2D

signal battery_changed(current: float, maximum: float)
signal dug_tile(pos: Vector2)
signal moved_freely(pos: Vector2)
signal hit_wall(pos: Vector2)
signal collected_battery(pos: Vector2)
const TILE_SIZE: int = 16
const MAX_BATTERY: float = 10.0
const MOVE_SPEED_FREE: float = 160.0 # ~0.1s per tile
const MOVE_SPEED_DIRT: float = 53.0  # ~0.3s per tile
const TILE_BATTERY: Vector2i = Vector2i(47, 9)
const BATTERY_RECHARGE_AMOUNT: float = 3.0

# Map horizontal bounds (tile columns 1-10 are playable)
const MAP_MIN_X: float = 1.0 * TILE_SIZE + TILE_SIZE * 0.5   # center of col 1
const MAP_MAX_X: float = 10.0 * TILE_SIZE + TILE_SIZE * 0.5  # center of col 10

@export var infinite_battery: bool = false

var battery: float = MAX_BATTERY
var _is_moving: bool = false
var _target_position: Vector2
var _current_move_speed: float = MOVE_SPEED_FREE

@onready var _dirt_layer: TileMapLayer = $"../Tilemaps/DirtLayer"


func _ready() -> void:
	add_to_group("player")
	# Snap to nearest tile center on startup
	position = position.snapped(Vector2(TILE_SIZE, TILE_SIZE)) + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
	_target_position = global_position
	battery_changed.emit(battery, MAX_BATTERY)


func _physics_process(delta: float) -> void:
	if _is_moving:
		global_position = global_position.move_toward(_target_position, _current_move_speed * delta)
		if global_position == _target_position:
			_is_moving = false
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
		return

	_try_move(dir)


func _try_move(dir: Vector2i) -> void:
	var current_pos := _target_position
	var target_pos := current_pos + Vector2(dir.x * TILE_SIZE, dir.y * TILE_SIZE)
	var target_cell: Vector2i = _dirt_layer.local_to_map(_dirt_layer.to_local(target_pos))
	var source_id: int = _dirt_layer.get_cell_source_id(target_cell)
	var has_tile: bool = source_id != -1

	# Intercept battery recharge tiles
	if has_tile:
		var atlas: Vector2i = _dirt_layer.get_cell_atlas_coords(target_cell)
		if atlas == TILE_BATTERY:
			_dirt_layer.erase_cell(target_cell)
			_recharge_battery(BATTERY_RECHARGE_AMOUNT)
			_target_position = target_pos
			_current_move_speed = MOVE_SPEED_DIRT
			_is_moving = true
			collected_battery.emit(target_pos)
			return

	match dir:
		Vector2i(0, 1):   # ---- Down: dig if tile present (1.0 battery), always step in ----
			if has_tile:
				_dirt_layer.erase_cell(target_cell)
				_spend_battery(1.0)
				_current_move_speed = MOVE_SPEED_DIRT
				dug_tile.emit(target_pos)
			else:
				_current_move_speed = MOVE_SPEED_FREE
				moved_freely.emit(target_pos)
			_target_position = target_pos
			_is_moving = true

		Vector2i(0, -1):  # ---- Up: dig if tile present (0.5 battery), step in ----
			if target_pos.y >= TILE_SIZE * 0.5:
				if has_tile:
					_dirt_layer.erase_cell(target_cell)
					_spend_battery(0.5)
					_current_move_speed = MOVE_SPEED_DIRT
					dug_tile.emit(target_pos)
				else:
					_current_move_speed = MOVE_SPEED_FREE
					moved_freely.emit(target_pos)
				_target_position = target_pos
				_is_moving = true
			else:
				hit_wall.emit(target_pos)

		_:                # ---- Horizontal: blocked by map edges, dig if tile present (0.5 battery) ----
			var in_bounds: bool = target_pos.x >= MAP_MIN_X and target_pos.x <= MAP_MAX_X
			if in_bounds:
				if has_tile:
					_dirt_layer.erase_cell(target_cell)
					_spend_battery(0.5)
					_current_move_speed = MOVE_SPEED_DIRT
					dug_tile.emit(target_pos)
				else:
					_current_move_speed = MOVE_SPEED_FREE
					moved_freely.emit(target_pos)
				_target_position = target_pos
				_is_moving = true
			else:
				hit_wall.emit(target_pos)


func _spend_battery(amount: float) -> void:
	if infinite_battery:
		return
	battery = maxf(0.0, battery - amount)
	battery_changed.emit(battery, MAX_BATTERY)


func _recharge_battery(amount: float) -> void:
	battery = minf(MAX_BATTERY, battery + amount)
	battery_changed.emit(battery, MAX_BATTERY)
