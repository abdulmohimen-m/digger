extends TileMapLayer

@export var map_width: int = 10
@export var map_depth: int = 500
@export var seed_value: int = 0
@export var rock_wobble_time: float = 0.7
@export var rock_fall_step_delay: float = 0.35

const TILE_WALL = Vector2i(0, 0)
const TILE_CRACKED_ROCK = Vector2i(1, 0)
const TILE_ROCK = Vector2i(2, 0)
const TILE_MINE = Vector2i(3, 0)
const TILE_UNDIGGABLE = Vector2i(4, 0)
const TILE_DIRT = Vector2i(5, 0)
const TILE_BOMB = Vector2i(6, 0)
const TILE_BATTERY = Vector2i(7, 0)

const TILE_PLAIN = Vector2i(1, 1)
const TILE_DIAMOND = Vector2i(3, 1)
const TILE_GOLD = Vector2i(4, 1)
const TILE_LEFT_BORDER = Vector2i(2, 1)
const TILE_RIGHT_BORDER = Vector2i(0, 1)
const OUTER_MARGIN: int = 10

const SOURCE_ID: int = 0


signal rock_wobbling(pos: Vector2)
signal rock_shattered(pos: Vector2)
signal cross_blast_step(origin_cell: Vector2i, h_step_cells: Array[Vector2i], v_step_cells: Array[Vector2i])

var _wobbling_rocks: Dictionary = {} # cell -> timer float
var _falling_rocks: Dictionary = {}  # cell -> step timer float


func _ready() -> void:
	generate_map()


func _process(delta: float) -> void:
	if _wobbling_rocks.is_empty() and _falling_rocks.is_empty():
		return

	var player = get_tree().get_first_node_in_group("player")
	var player_cell := Vector2i(-999, -999)
	if player:
		player_cell = local_to_map(to_local(player.global_position))

	# 1. Update wobbling rocks
	var finished_wobble: Array[Vector2i] = []
	for cell in _wobbling_rocks.keys():
		_wobbling_rocks[cell] -= delta
		if _wobbling_rocks[cell] <= 0.0:
			finished_wobble.append(cell)

	for cell in finished_wobble:
		_wobbling_rocks.erase(cell)
		var cell_below := cell + Vector2i(0, 1)
		if is_empty(cell_below) or cell_below == player_cell:
			_falling_rocks[cell] = rock_fall_step_delay

	# 2. Update falling rocks
	var to_advance: Array[Vector2i] = []
	for cell in _falling_rocks.keys():
		_falling_rocks[cell] -= delta
		if _falling_rocks[cell] <= 0.0:
			to_advance.append(cell)

	for cell in to_advance:
		_falling_rocks.erase(cell)
		_step_rock_fall(cell, player, player_cell)


func check_falling_rock_above(cell: Vector2i) -> void:
	var cell_above := cell + Vector2i(0, -1)
	var atlas := get_cell_atlas_coords(cell_above)
	if atlas == TILE_ROCK or atlas == TILE_CRACKED_ROCK:
		if not _wobbling_rocks.has(cell_above) and not _falling_rocks.has(cell_above):
			_wobbling_rocks[cell_above] = rock_wobble_time
			var world_pos := map_to_local(cell_above)
			rock_wobbling.emit(world_pos)


func _step_rock_fall(cell: Vector2i, player, player_cell: Vector2i) -> void:
	var rock_type := get_cell_atlas_coords(cell)
	if rock_type != TILE_ROCK and rock_type != TILE_CRACKED_ROCK:
		return

	var cell_below := cell + Vector2i(0, 1)

	# Check if player is crushed
	if player and (cell_below == player_cell or cell == player_cell):
		set_cell(cell, SOURCE_ID, TILE_PLAIN)
		rock_shattered.emit(map_to_local(cell_below))
		if player.has_method("take_rock_crush_damage"):
			player.take_rock_crush_damage(3.0)
		check_falling_rock_above(cell)
		return

	if is_empty(cell_below):
		set_cell(cell, SOURCE_ID, TILE_PLAIN)
		set_cell(cell_below, SOURCE_ID, rock_type)
		rock_wobbling.emit(map_to_local(cell_below))
		check_falling_rock_above(cell)

		var cell_under_next := cell_below + Vector2i(0, 1)
		if is_empty(cell_under_next) or cell_under_next == player_cell:
			_falling_rocks[cell_below] = rock_fall_step_delay


## Clears a tile at cell and checks if rock above should fall.
func clear_tile(cell: Vector2i) -> void:
	set_cell(cell, SOURCE_ID, TILE_PLAIN)
	check_falling_rock_above(cell)


## Blasts in a 4-way cross pattern (+ shape) up to range_radius cells in each cardinal direction.
## Handles tile removal, ore auto-collection, cascading terrain bomb chain reactions, and destroying falling rocks.
func explode_cross_pattern(origin_cell: Vector2i, range_radius: int = 6, player_node = null) -> Array[Vector2i]:
	var affected_cells: Array[Vector2i] = []
	affected_cells.append(origin_cell)
	
	# Clear origin cell if present
	if get_cell_source_id(origin_cell) != -1:
		var atlas := get_cell_atlas_coords(origin_cell)
		if atlas != TILE_WALL:
			clear_tile(origin_cell)

	cross_blast_step.emit(origin_cell, [origin_cell], [origin_cell])

	var active_dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	for r in range(1, range_radius + 1):
		await get_tree().create_timer(0.04).timeout
		
		var step_h: Array[Vector2i] = []
		var step_v: Array[Vector2i] = []
		var stopped_dirs: Array[Vector2i] = []

		for dir in active_dirs:
			var target_cell: Vector2i = origin_cell + dir * r
			var source_id := get_cell_source_id(target_cell)
			if source_id == -1:
				affected_cells.append(target_cell)
				if dir.y == 0:
					step_h.append(target_cell)
				else:
					step_v.append(target_cell)
				continue

			var atlas := get_cell_atlas_coords(target_cell)
			if atlas == TILE_WALL:
				stopped_dirs.append(dir)
				continue

			affected_cells.append(target_cell)
			if dir.y == 0:
				step_h.append(target_cell)
			else:
				step_v.append(target_cell)

			# Destroy wobbling / falling rocks at target cell
			if _wobbling_rocks.has(target_cell):
				_wobbling_rocks.erase(target_cell)
				rock_shattered.emit(map_to_local(target_cell))
			if _falling_rocks.has(target_cell):
				_falling_rocks.erase(target_cell)
				rock_shattered.emit(map_to_local(target_cell))

			if atlas == TILE_BOMB:
				# Cascade! Convert terrain bomb tile into secondary cross explosion
				clear_tile(target_cell)
				explode_cross_pattern(target_cell, range_radius, player_node)
			elif atlas == TILE_GOLD:
				clear_tile(target_cell)
				if player_node and player_node.has_method("_collect_gold"):
					player_node._collect_gold()
			elif atlas == TILE_DIAMOND:
				clear_tile(target_cell)
				if player_node and player_node.has_method("_collect_diamond"):
					player_node._collect_diamond()
			elif atlas != TILE_PLAIN:
				clear_tile(target_cell)

		for d in stopped_dirs:
			active_dirs.erase(d)

		if step_h.size() > 0 or step_v.size() > 0:
			cross_blast_step.emit(origin_cell, step_h, step_v)

		if player_node and player_node.has_method("take_rock_crush_damage"):
			var player_cell: Vector2i = local_to_map(to_local(player_node.global_position))
			if step_h.has(player_cell) or step_v.has(player_cell):
				player_node.take_rock_crush_damage(5.0)

		if active_dirs.is_empty():
			break

	return affected_cells


## Returns true if a diggable tile was found and replaced with plain tile at the given cell.
func try_dig(cell: Vector2i) -> bool:
	if is_empty(cell):
		return false
	clear_tile(cell)
	return true


## Returns true if the cell contains no tile or is a plain background tile (cleared / already dug).
func is_empty(cell: Vector2i) -> bool:
	if get_cell_source_id(cell) == -1:
		return true
	return get_cell_atlas_coords(cell) == TILE_PLAIN
func generate_map() -> void:
	clear()
	var rng := RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()

	var rows_since_battery: int = 0
	var next_guaranteed_battery_row: int = rng.randi_range(8, 12)

	for y in range(map_depth):
		# Fill left outer area: plain background tiles (x = -11 to -2) and adjacent left border (x = -1)
		for x in range(-11, -1):
			set_cell(Vector2i(x, y), SOURCE_ID, TILE_PLAIN)
		set_cell(Vector2i(-1, y), SOURCE_ID, TILE_LEFT_BORDER)

		# Indestructible side border walls (column 0 and column map_width + 1)
		set_cell(Vector2i(0, y), SOURCE_ID, TILE_WALL)
		set_cell(Vector2i(map_width + 1, y), SOURCE_ID, TILE_WALL)

		# Fill right outer area: adjacent right border (x = map_width + 2) and plain background tiles (x = map_width + 3 to map_width + 12)
		set_cell(Vector2i(map_width + 2, y), SOURCE_ID, TILE_RIGHT_BORDER)
		for x in range(map_width + 3, map_width + 13):
			set_cell(Vector2i(x, y), SOURCE_ID, TILE_PLAIN)

		# Absolute bottom row: complete metallic indestructible floor
		if y == map_depth - 1:
			for x in range(-11, map_width + 13):
				set_cell(Vector2i(x, y), SOURCE_ID, TILE_WALL)
			continue

		# Surface spawn clearing (rows 0 to 3) with Plain Tile background visuals
		if y < 4:
			for x in range(1, map_width + 1):
				set_cell(Vector2i(x, y), SOURCE_ID, TILE_PLAIN)
			continue

		# Guaranteed battery spawn counter check
		rows_since_battery += 1
		var forced_battery_col: int = -1
		if rows_since_battery >= next_guaranteed_battery_row:
			forced_battery_col = rng.randi_range(1, map_width)
			rows_since_battery = 0
			next_guaranteed_battery_row = rng.randi_range(8, 12)

		for x in range(1, map_width + 1):
			if x == forced_battery_col:
				set_cell(Vector2i(x, y), SOURCE_ID, TILE_BATTERY)
				continue

			var roll: float = rng.randf()

			# --- BIOME 1: Normal Soil (Depth 4 to 150) ---
			if y <= 150:
				if roll < 0.04:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_MINE)
				elif roll < 0.07:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_UNDIGGABLE)
				elif roll < 0.12:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_BATTERY)
				elif roll < 0.17:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_BOMB)
				elif roll < 0.22:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_ROCK)
				elif roll < 0.30:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_GOLD)
				elif roll < 0.31:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_DIAMOND)
				else:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_DIRT)

			# --- BIOME 2: Rocky Soil (Depth 151 to 350) ---
			elif y <= 350:
				if roll < 0.06:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_MINE)
				elif roll < 0.14:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_UNDIGGABLE)
				elif roll < 0.39:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_ROCK)
				elif roll < 0.44:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_BATTERY)
				elif roll < 0.50:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_BOMB)
				elif roll < 0.60:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_GOLD)
				elif roll < 0.64:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_DIAMOND)
				else:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_DIRT)

			# --- BIOME 3: Ancient Mines (Depth 351 to 498) ---
			else:
				if roll < 0.10:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_MINE)
				elif roll < 0.25:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_UNDIGGABLE)
				elif roll < 0.50:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_ROCK)
				elif roll < 0.55:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_BATTERY)
				elif roll < 0.60:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_BOMB)
				elif roll < 0.72:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_GOLD)
				elif roll < 0.80:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_DIAMOND)
				else:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_DIRT)
