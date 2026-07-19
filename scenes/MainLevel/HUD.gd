extends Control

const SHARD_COUNT: int = 10
const SHARD_SIZE: Vector2 = Vector2(14.0, 14.0)
const HALF_SHARD_SIZE: Vector2 = Vector2(7.0, 14.0)
const COLOR_FULL: Color  = Color(1.00, 0.82, 0.05)  # warm gold
const COLOR_EMPTY: Color = Color(0.18, 0.18, 0.20)  # near-black

# Array of Arrays: [[left_rect, right_rect], ...]
var _shards: Array[Array] = []
var _bomb_rects: Array[ColorRect] = []
var _combo_label: Label
var _bomb_container: HBoxContainer

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

	# Setup Bomb Container
	_bomb_container = HBoxContainer.new()
	_bomb_container.position = Vector2(10, 30)
	_bomb_container.add_theme_constant_override("separation", 5)
	for i in 3:
		var rect := ColorRect.new()
		rect.custom_minimum_size = Vector2(14, 14)
		rect.color = Color(0.9, 0.1, 0.1) # Bright red for bombs
		_bomb_container.add_child(rect)
		_bomb_rects.append(rect)
	add_child(_bomb_container)

	# Wait one frame so Player._ready() has had time to run and join its group
	call_deferred("_connect_to_player")

	# Initialize combo label dynamically
	_combo_label = Label.new()
	_combo_label.position = Vector2(10, 50)
	_combo_label.text = ""
	_combo_label.add_theme_color_override("font_color", Color("ffd700"))
	_combo_label.add_theme_font_size_override("font_size", 14)
	add_child(_combo_label)


func _connect_to_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.battery_changed.connect(_on_battery_changed)
		player.combo_changed.connect(_on_combo_changed)
		player.bombs_changed.connect(_on_bombs_changed)
		# Sync immediately with current battery state
		player.battery_changed.emit(player.battery, player.MAX_BATTERY)
		player.bombs_changed.emit(player.bombs, player.MAX_BOMBS)
		_on_combo_changed(player.combo_count)


func _on_battery_changed(current: float, _maximum: float) -> void:
	# Calculate total half-shards that should be colored (out of 20 total halves)
	var half_shards_filled: int = int(round(current * 2.0))
	
	for i in _shards.size():
		var left_rect: ColorRect = _shards[i][0]
		var right_rect: ColorRect = _shards[i][1]
		
		left_rect.color = COLOR_FULL if (2 * i) < half_shards_filled else COLOR_EMPTY
		right_rect.color = COLOR_FULL if (2 * i + 1) < half_shards_filled else COLOR_EMPTY


func _on_bombs_changed(current: int, _maximum: int) -> void:
	for i in _bomb_rects.size():
		if i < current:
			_bomb_rects[i].color = Color(0.9, 0.1, 0.1) # Bright red
		else:
			_bomb_rects[i].color = COLOR_EMPTY


func _on_combo_changed(combo: int) -> void:
	if combo >= 1:
		var player := get_tree().get_first_node_in_group("player")
		if player and player.get("is_frenzy"):
			_combo_label.text = "🔥 FRENZY x" + str(combo) + " 🔥"
			_combo_label.add_theme_color_override("font_color", Color("00ffff"))
		else:
			_combo_label.text = "COMBO x" + str(combo)
			_combo_label.add_theme_color_override("font_color", Color("ffd700"))
		
		# Quick arcade scale punch
		_combo_label.scale = Vector2(1.3, 1.3)
		var tween = create_tween()
		tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.15)
	else:
		_combo_label.text = ""

