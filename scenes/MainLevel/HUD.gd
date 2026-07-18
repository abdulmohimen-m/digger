extends Control

const SHARD_COUNT: int = 10
const SHARD_SIZE: Vector2 = Vector2(14.0, 14.0)
const HALF_SHARD_SIZE: Vector2 = Vector2(7.0, 14.0)
const COLOR_FULL: Color  = Color(1.00, 0.82, 0.05)  # warm gold
const COLOR_EMPTY: Color = Color(0.18, 0.18, 0.20)  # near-black

# Array of Arrays: [[left_rect, right_rect], ...]
var _shards: Array[Array] = []

@onready var _container: HBoxContainer = $BatteryContainer


func _ready() -> void:
	_container.add_theme_constant_override("separation", 3)

	for i in SHARD_COUNT:
		var shard_parent := HBoxContainer.new()
		shard_parent.add_theme_constant_override("separation", 0)
		shard_parent.custom_minimum_size = SHARD_SIZE
		
		var left_half := ColorRect.new()
		left_half.custom_minimum_size = HALF_SHARD_SIZE
		left_half.color = COLOR_FULL
		
		var right_half := ColorRect.new()
		right_half.custom_minimum_size = HALF_SHARD_SIZE
		right_half.color = COLOR_FULL
		
		shard_parent.add_child(left_half)
		shard_parent.add_child(right_half)
		_container.add_child(shard_parent)
		
		_shards.append([left_half, right_half])

	# Wait one frame so Player._ready() has had time to run and join its group
	call_deferred("_connect_to_player")


func _connect_to_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.battery_changed.connect(_on_battery_changed)
		# Sync immediately with current battery state
		player.battery_changed.emit(player.battery, player.MAX_BATTERY)


func _on_battery_changed(current: float, _maximum: float) -> void:
	# Calculate total half-shards that should be colored (out of 20 total halves)
	var half_shards_filled: int = int(round(current * 2.0))
	
	for i in _shards.size():
		var left_rect: ColorRect = _shards[i][0]
		var right_rect: ColorRect = _shards[i][1]
		
		left_rect.color = COLOR_FULL if (2 * i) < half_shards_filled else COLOR_EMPTY
		right_rect.color = COLOR_FULL if (2 * i + 1) < half_shards_filled else COLOR_EMPTY

