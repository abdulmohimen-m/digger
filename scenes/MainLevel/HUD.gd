extends Control

const SHARD_COUNT: int = 10
const SHARD_SIZE: Vector2 = Vector2(14.0, 14.0)
const HALF_SHARD_SIZE: Vector2 = Vector2(7.0, 14.0)
const COLOR_FULL: Color  = Color(1.00, 0.82, 0.05)  # warm gold
const COLOR_ALERT: Color = Color(1.00, 0.15, 0.15)  # pulse red
const COLOR_EMPTY: Color = Color(0.18, 0.18, 0.20)  # near-black

# Array of Arrays: [[left_rect, right_rect], ...]
var _shards: Array[Array] = []
var _bomb_rects: Array[ColorRect] = []
var _combo_label: Label
var _bomb_container: HBoxContainer
var _is_low_battery: bool = false
var _pulse_timer: float = 0.0
var _current_active_color: Color = COLOR_FULL
var _vignette: ColorRect = null

@onready var _container: HBoxContainer = $BatteryContainer


func _ready() -> void:
	# Create red screen vignette overlay
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color(1.0, 0.0, 0.0, 0.0)
	_vignette.z_index = -1
	add_child(_vignette)

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


func _process(delta: float) -> void:
	if _is_low_battery:
		_pulse_timer += delta * 12.0
		var pulse: float = (sin(_pulse_timer) + 1.0) * 0.5
		_current_active_color = COLOR_FULL.lerp(COLOR_ALERT, pulse)
		_update_shard_colors()
		if _vignette:
			_vignette.color = Color(1.0, 0.0, 0.0, pulse * 0.22)
	else:
		if _vignette and _vignette.color.a > 0.0:
			_vignette.color = Color(1.0, 0.0, 0.0, 0.0)


func _connect_to_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.battery_changed.connect(_on_battery_changed)
		player.combo_changed.connect(_on_combo_changed)
		player.bombs_changed.connect(_on_bombs_changed)
		player.low_battery_warning.connect(_on_low_battery_warning)
		player.battery_depleted.connect(_on_battery_depleted)
		# Sync immediately with current battery state
		player.battery_changed.emit(player.battery, player.MAX_BATTERY)
		player.bombs_changed.emit(player.bombs, player.MAX_BOMBS)
		_on_combo_changed(player.combo_count)


var _half_shards_filled: int = 20


func _on_battery_changed(current: float, _maximum: float) -> void:
	_half_shards_filled = int(round(current * 2.0))
	_update_shard_colors()


func _update_shard_colors() -> void:
	var active_color: Color = _current_active_color if _is_low_battery else COLOR_FULL
	for i in _shards.size():
		var left_rect: ColorRect = _shards[i][0]
		var right_rect: ColorRect = _shards[i][1]
		
		left_rect.color = active_color if (2 * i) < _half_shards_filled else COLOR_EMPTY
		right_rect.color = active_color if (2 * i + 1) < _half_shards_filled else COLOR_EMPTY


func _on_low_battery_warning(is_low: bool) -> void:
	_is_low_battery = is_low
	if _is_low_battery:
		# Scale punch HUD battery container to grab immediate attention
		_container.pivot_offset = Vector2(0, _container.size.y * 0.5)
		_container.scale = Vector2(1.25, 1.25)
		var tween := create_tween()
		tween.tween_property(_container, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	else:
		_current_active_color = COLOR_FULL
		_update_shard_colors()


func _on_battery_depleted(_pos: Vector2) -> void:
	_is_low_battery = false
	_current_active_color = COLOR_ALERT
	_update_shard_colors()
	
	# Show "BATTERY EXHAUSTED" arcade banner
	var banner := Label.new()
	banner.text = "⚠️ BATTERY EXHAUSTED! ⚠️"
	banner.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	banner.add_theme_font_size_override("font_size", 16)
	
	# Center banner on screen
	banner.anchors_preset = Control.PRESET_CENTER
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.position = Vector2(30, 80)
	
	add_child(banner)
	
	# Banner entrance animation
	banner.scale = Vector2(0.2, 0.2)
	banner.pivot_offset = banner.size * 0.5
	var tween := create_tween()
	tween.tween_property(banner, "scale", Vector2(1.3, 1.3), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.1)
	
	var flash_tween := create_tween()
	flash_tween.set_loops(3)
	flash_tween.tween_property(banner, "modulate", Color(1, 1, 0), 0.15)
	flash_tween.tween_property(banner, "modulate", Color(1, 0.2, 0.2), 0.15)


func _on_bombs_changed(current: int, _maximum: int) -> void:
	for i in _bomb_rects.size():
		if i < current:
			_bomb_rects[i].color = Color(0.9, 0.1, 0.1) # Bright red
		else:
			_bomb_rects[i].color = COLOR_EMPTY


func _on_combo_changed(combo: int) -> void:
	if combo >= 1:
		var player := get_tree().get_first_node_in_group("player")
		var f_lvl: int = player.frenzy_level if (player and "frenzy_level" in player) else 0
		
		match f_lvl:
			5:
				_combo_label.text = "🌈 GOD DRILL x" + str(combo) + " 🌈"
				_combo_label.add_theme_color_override("font_color", Color("ff00ff")) # Magenta
			4:
				_combo_label.text = "💥 FRENZY LV4 x" + str(combo) + " 💥"
				_combo_label.add_theme_color_override("font_color", Color("ff8c00")) # Orange
			3:
				_combo_label.text = "🔋 FRENZY LV3 x" + str(combo) + " 🔋"
				_combo_label.add_theme_color_override("font_color", Color("00ff00")) # Green
			2:
				_combo_label.text = "⚡ FRENZY LV2 x" + str(combo) + " ⚡"
				_combo_label.add_theme_color_override("font_color", Color("ffd700")) # Gold
			1:
				_combo_label.text = "🔥 FRENZY LV1 x" + str(combo) + " 🔥"
				_combo_label.add_theme_color_override("font_color", Color("00ffff")) # Cyan
			_:
				_combo_label.text = "COMBO x" + str(combo)
				_combo_label.add_theme_color_override("font_color", Color("ffd700"))
		
		# Quick arcade scale punch
		_combo_label.scale = Vector2(1.3, 1.3)
		var tween = create_tween()
		tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.15)
	else:
		_combo_label.text = ""

