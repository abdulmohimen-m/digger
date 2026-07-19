extends TileMapLayer

const TILE_BATTERY = Vector2i(47, 9)
const TILE_BOMB = Vector2i(45, 9)
const TILE_UNDIGGABLE = Vector2i(39, 15)
const TILE_ROCK = Vector2i(10, 17)
const TILE_CRACKED_ROCK = Vector2i(11, 17)
const TILE_DIRT = Vector2i(32, 15)

func _ready() -> void:
	# Place a few battery recharge, bomb, undiggable, and rocky tiles inside the starting dirt block for testing
	set_cell(Vector2i(3, 5), 1, TILE_BATTERY)
	set_cell(Vector2i(7, 6), 1, TILE_BOMB)
	set_cell(Vector2i(5, 8), 1, TILE_BATTERY)
	set_cell(Vector2i(8, 7), 1, TILE_BOMB)
	set_cell(Vector2i(4, 5), 1, TILE_UNDIGGABLE)
	set_cell(Vector2i(6, 7), 1, TILE_UNDIGGABLE)
	set_cell(Vector2i(3, 6), 1, TILE_ROCK)
	set_cell(Vector2i(5, 7), 1, TILE_ROCK)

## Returns true if a diggable tile was found and erased at the given cell.
func try_dig(cell: Vector2i) -> bool:
	if get_cell_source_id(cell) == -1:
		return false
	erase_cell(cell)
	return true

## Returns true if the cell contains no tile (empty / already dug).
func is_empty(cell: Vector2i) -> bool:
	return get_cell_source_id(cell) == -1

