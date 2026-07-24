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
const TILE_MAGMA = Vector2i(7, 4)
const TILE_LEFT_BORDER = Vector2i(2, 1)
const TILE_RIGHT_BORDER = Vector2i(0, 1)
const OUTER_MARGIN: int = 10

const SOURCE_ID: int = 0


signal rock_wobbling(pos: Vector2)
signal rock_shattered(pos: Vector2)
signal rock_settled(pos: Vector2)
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
		else:
			rock_settled.emit(map_to_local(cell_below))


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

	if EventBus:
		EventBus.detonated_bomb.emit(to_global(map_to_local(origin_cell)))

	var init_h: Array[Vector2i] = [origin_cell]
	var init_v: Array[Vector2i] = [origin_cell]
	cross_blast_step.emit(origin_cell, init_h, init_v)

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
	
	var rows_since_stratum: int = 0
	var next_stratum_row: int = rng.randi_range(15, 25)

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

		# Oasis Vault Generation Check (Transitions at Depths 73, 148, 223, 298, 373)
		var oasis_number = -1
		if y >= 73 and y <= 76: oasis_number = 1
		elif y >= 148 and y <= 151: oasis_number = 2
		elif y >= 223 and y <= 226: oasis_number = 3
		elif y >= 298 and y <= 301: oasis_number = 4
		elif y >= 373 and y <= 376: oasis_number = 5

		if oasis_number != -1:
			var row_in_oasis = (y - 73) % 75
			
			if row_in_oasis == 0 or row_in_oasis == 3: # Ceiling or Floor
				var gap1 = rng.randi_range(1, map_width)
				var gap2 = rng.randi_range(1, map_width)
				for x in range(1, map_width + 1):
					if x == gap1 or x == gap2:
						set_cell(Vector2i(x, y), SOURCE_ID, TILE_DIRT)
					else:
						set_cell(Vector2i(x, y), SOURCE_ID, TILE_UNDIGGABLE)
			
			elif row_in_oasis == 1: # Supplies Row
				var num_batteries = ceil(oasis_number / 2.0)
				var num_bombs = ceil(oasis_number / 2.0)
				var items_to_place = []
				for i in range(num_batteries): items_to_place.append(TILE_BATTERY)
				for i in range(num_bombs): items_to_place.append(TILE_BOMB)
				
				while items_to_place.size() < map_width:
					items_to_place.append(TILE_PLAIN)
				
				# Basic shuffle
				for i in range(items_to_place.size() - 1, 0, -1):
					var j = rng.randi_range(0, i)
					var temp = items_to_place[i]
					items_to_place[i] = items_to_place[j]
					items_to_place[j] = temp
				
				for x in range(1, map_width + 1):
					set_cell(Vector2i(x, y), SOURCE_ID, items_to_place[x - 1])
			
			elif row_in_oasis == 2: # Treasure Row
				var vein_tile = TILE_GOLD if oasis_number <= 2 else TILE_DIAMOND
				var length = 3 + oasis_number
				if length > map_width - 2: length = map_width - 2
				var start_x = rng.randi_range(1, map_width - length + 1)
				for x in range(1, map_width + 1):
					if x >= start_x and x < start_x + length:
						set_cell(Vector2i(x, y), SOURCE_ID, vein_tile)
					else:
						set_cell(Vector2i(x, y), SOURCE_ID, TILE_PLAIN)
			continue # End of Oasis row generation

		# Determine Current Biome
		var current_biome = 1
		if y > 376: current_biome = 6
		elif y > 301: current_biome = 5
		elif y > 226: current_biome = 4
		elif y > 151: current_biome = 3
		elif y > 76: current_biome = 2

		# Bedrock Strata Logic
		rows_since_stratum += 1
		var is_stratum_row: bool = false
		var gap1: int = -1
		var gap2: int = -1
		
		var stratum_min = 15
		var stratum_max = 25
		if current_biome == 6:
			stratum_min = 8
			stratum_max = 12
			
		# Allow strata only if Biome >= 3
		if current_biome >= 3 and rows_since_stratum >= next_stratum_row:
			is_stratum_row = true
			rows_since_stratum = 0
			next_stratum_row = rng.randi_range(stratum_min, stratum_max)
			
			gap1 = rng.randi_range(1, map_width)
			if rng.randf() < 0.4: # 40% chance for a second gap
				gap2 = rng.randi_range(1, map_width)

		# Guaranteed battery spawn counter check
		rows_since_battery += 1
		var forced_battery_col: int = -1
		if rows_since_battery >= next_guaranteed_battery_row:
			rows_since_battery = 0
			next_guaranteed_battery_row = rng.randi_range(8, 12)
			
			if is_stratum_row:
				forced_battery_col = gap1 # Force into gap so it isn't overwritten by bedrock
			else:
				forced_battery_col = rng.randi_range(1, map_width)

		# Procedural Vein generation
		var is_vein_row: bool = false
		var vein_start: int = -1
		var vein_end: int = -1
		var vein_tile: Vector2i = TILE_GOLD
		
		if not is_stratum_row and rng.randf() < 0.15: # 15% chance per row
			is_vein_row = true
			var length = rng.randi_range(3, 5)
			vein_start = rng.randi_range(1, map_width - length + 1)
			vein_end = vein_start + length - 1
			
			if current_biome <= 2:
				vein_tile = TILE_GOLD if rng.randf() < 0.90 else TILE_DIAMOND
			elif current_biome <= 4:
				vein_tile = TILE_GOLD if rng.randf() < 0.65 else TILE_DIAMOND
			else:
				vein_tile = TILE_GOLD if rng.randf() < 0.45 else TILE_DIAMOND

		var is_pre_stratum_row = (rows_since_stratum == next_stratum_row - 1)

		for x in range(1, map_width + 1):
			if is_stratum_row:
				if x == gap1 or x == gap2:
					if x == forced_battery_col:
						set_cell(Vector2i(x, y), SOURCE_ID, TILE_BATTERY)
					else:
						set_cell(Vector2i(x, y), SOURCE_ID, TILE_DIRT)
				else:
					set_cell(Vector2i(x, y), SOURCE_ID, TILE_UNDIGGABLE)
				continue
				
			if x == forced_battery_col:
				set_cell(Vector2i(x, y), SOURCE_ID, TILE_BATTERY)
				continue
				
			if is_vein_row and x >= vein_start and x <= vein_end:
				set_cell(Vector2i(x, y), SOURCE_ID, vein_tile)
				continue

			var roll: float = rng.randf()
			var chance_mine = 0.0
			var chance_undiggable = 0.0
			var chance_battery = 0.0
			var chance_bomb = 0.0
			var chance_rock = 0.0
			var chance_gold = 0.0
			var chance_diamond = 0.0
			var chance_magma = 0.0

			if current_biome == 1:
				# Biome 1: Surface
				chance_battery = 0.06
				chance_gold = 0.01
			elif current_biome == 2:
				# Biome 2: Rocky Soil
				chance_rock = 0.20
				chance_battery = 0.05
				chance_gold = 0.02
			elif current_biome == 3:
				# Biome 3: The Blockade
				chance_undiggable = 0.05 if not is_pre_stratum_row else 0.0
				chance_rock = 0.25
				chance_battery = 0.05
				chance_bomb = 0.06
				chance_gold = 0.02
				chance_diamond = 0.005
			elif current_biome == 4:
				# Biome 4: Ancient Mines
				chance_mine = 0.06
				chance_undiggable = 0.08 if not is_pre_stratum_row else 0.0
				chance_rock = 0.25
				chance_battery = 0.05
				chance_bomb = 0.06
				chance_gold = 0.02
				chance_diamond = 0.01
			elif current_biome == 5:
				# Biome 5: Volcanic Layer
				chance_magma = 0.08
				chance_mine = 0.08
				chance_undiggable = 0.10 if not is_pre_stratum_row else 0.0
				chance_rock = 0.25
				chance_battery = 0.05
				chance_bomb = 0.05
				chance_gold = 0.02
				chance_diamond = 0.02
			elif current_biome == 6:
				# Biome 6: The Abyss
				chance_magma = 0.12
				chance_mine = 0.12
				chance_undiggable = 0.15 if not is_pre_stratum_row else 0.0
				chance_rock = 0.25
				chance_battery = 0.05
				chance_bomb = 0.05
				chance_gold = 0.03
				chance_diamond = 0.02

			var c1 = chance_mine
			var c2 = c1 + chance_undiggable
			var c3 = c2 + chance_battery
			var c4 = c3 + chance_bomb
			var c5 = c4 + chance_rock
			var c6 = c5 + chance_gold
			var c7 = c6 + chance_diamond
			var c8 = c7 + chance_magma

			if roll < c1:
				set_cell(Vector2i(x, y), SOURCE_ID, TILE_MINE)
			elif roll < c2:
				set_cell(Vector2i(x, y), SOURCE_ID, TILE_UNDIGGABLE)
			elif roll < c3:
				set_cell(Vector2i(x, y), SOURCE_ID, TILE_BATTERY)
			elif roll < c4:
				set_cell(Vector2i(x, y), SOURCE_ID, TILE_BOMB)
			elif roll < c5:
				set_cell(Vector2i(x, y), SOURCE_ID, TILE_ROCK)
			elif roll < c6:
				set_cell(Vector2i(x, y), SOURCE_ID, TILE_GOLD)
			elif roll < c7:
				set_cell(Vector2i(x, y), SOURCE_ID, TILE_DIAMOND)
			elif roll < c8:
				set_cell(Vector2i(x, y), SOURCE_ID, TILE_MAGMA)
			else:
				set_cell(Vector2i(x, y), SOURCE_ID, TILE_DIRT)
