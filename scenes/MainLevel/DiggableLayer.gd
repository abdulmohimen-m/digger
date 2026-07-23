extends TileMapLayer

@export var map_width: int = 10
@export var map_depth: int = 500
@export var seed_value: int = 0

const TILE_BATTERY = Vector2i(47, 9)
const TILE_BOMB = Vector2i(45, 9)
const TILE_UNDIGGABLE = Vector2i(39, 15)
const TILE_ROCK = Vector2i(10, 17)
const TILE_CRACKED_ROCK = Vector2i(11, 17)
const TILE_DIRT = Vector2i(32, 15)
const TILE_MINE = Vector2i(33, 15)
const TILE_WALL = Vector2i(3, 0)
const TILE_GOLD = Vector2i(0, 1)
const TILE_DIAMOND = Vector2i(1, 1)

const SOURCE_ID: int = 1


func _ready() -> void:
	generate_map()


## Procedurally generates the 10-column wide by 500-row deep level across 3 biomes.
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
		# Draw indestructible side border walls (column 0 and column map_width + 1)
		set_cell(Vector2i(0, y), SOURCE_ID, TILE_WALL)
		set_cell(Vector2i(map_width + 1, y), SOURCE_ID, TILE_WALL)

		# Absolute bottom row: complete metallic indestructible floor
		if y == map_depth - 1:
			for x in range(1, map_width + 1):
				set_cell(Vector2i(x, y), SOURCE_ID, TILE_WALL)
			continue

		# Surface spawn clearing (rows 0 to 3) for clean player onboarding
		if y < 4:
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


## Returns true if a diggable tile was found and erased at the given cell.
func try_dig(cell: Vector2i) -> bool:
	if get_cell_source_id(cell) == -1:
		return false
	erase_cell(cell)
	return true


## Returns true if the cell contains no tile (empty / already dug).
func is_empty(cell: Vector2i) -> bool:
	return get_cell_source_id(cell) == -1


