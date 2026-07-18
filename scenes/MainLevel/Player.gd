extends CharacterBody2D

signal battery_changed(current: float, maximum: float)

const TILE_SIZE: int = 16
const MAX_BATTERY: float = 10.0
const MOVE_COOLDOWN: float = 0.15  # seconds between grid steps
const TILE_BATTERY: Vector2i = Vector2i(47, 9)
const BATTERY_RECHARGE_AMOUNT: float = 3.0

# Map horizontal bounds (tile columns 1-10 are playable)
const MAP_MIN_X: float = 1.0 * TILE_SIZE + TILE_SIZE * 0.5   # center of col 1
const MAP_MAX_X: float = 10.0 * TILE_SIZE + TILE_SIZE * 0.5  # center of col 10

var battery: float = MAX_BATTERY
var _move_timer: float = 0.0

@onready var _dirt_layer: TileMapLayer = $"../Tilemaps/DirtLayer"


func _ready() -> void:
	add_to_group("player")
	# Snap to nearest tile center on startup
	position = position.snapped(Vector2(TILE_SIZE, TILE_SIZE)) + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
	battery_changed.emit(battery, MAX_BATTERY)


func _process(delta: float) -> void:
	if battery <= 0.0:
		return

	_move_timer = maxf(0.0, _move_timer - delta)
	if _move_timer > 0.0:
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
	_move_timer = MOVE_COOLDOWN


func _try_move(dir: Vector2i) -> void:
	var target_pos := global_position + Vector2(dir.x * TILE_SIZE, dir.y * TILE_SIZE)
	var target_cell: Vector2i = _dirt_layer.local_to_map(_dirt_layer.to_local(target_pos))
	var source_id: int = _dirt_layer.get_cell_source_id(target_cell)
	var has_tile: bool = source_id != -1

	# Intercept battery recharge tiles before regular movement rules
	if has_tile:
		var atlas: Vector2i = _dirt_layer.get_cell_atlas_coords(target_cell)
		if atlas == TILE_BATTERY:
			_dirt_layer.erase_cell(target_cell)
			_recharge_battery(BATTERY_RECHARGE_AMOUNT)
			global_position = target_pos
			return

	match dir:
		Vector2i(0, 1):   # ---- Down: dig if tile present (1.0 battery), always step in ----
			if has_tile:
				_dirt_layer.erase_cell(target_cell)
				_spend_battery(1.0)
			global_position = target_pos

		Vector2i(0, -1):  # ---- Up: dig if tile present (0.5 battery), step in ----
			if target_pos.y >= TILE_SIZE * 0.5:
				if has_tile:
					_dirt_layer.erase_cell(target_cell)
					_spend_battery(0.5)
				global_position = target_pos

		_:                # ---- Horizontal: blocked by map edges, dig if tile present (0.5 battery) ----
			var in_bounds: bool = target_pos.x >= MAP_MIN_X and target_pos.x <= MAP_MAX_X
			if in_bounds:
				if has_tile:
					_dirt_layer.erase_cell(target_cell)
					_spend_battery(0.5)
				global_position = target_pos


func _spend_battery(amount: float) -> void:
	battery = maxf(0.0, battery - amount)
	battery_changed.emit(battery, MAX_BATTERY)


func _recharge_battery(amount: float) -> void:
	battery = minf(MAX_BATTERY, battery + amount)
	battery_changed.emit(battery, MAX_BATTERY)
