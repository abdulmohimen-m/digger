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
var _gold_label: Label
var _diamond_label: Label
var _layer_label: Label
var _bomb_container: HBoxContainer
var _is_low_battery: bool = false
var _pulse_timer: float = 0.0
var _current_active_color: Color = COLOR_FULL
var _vignette: ColorRect = null
var _last_biome_name: String = ""

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

	# Initialize Gold & Diamond counter labels
	_gold_label = Label.new()
	_gold_label.position = Vector2(10, 48)
	_gold_label.text = "🟡 GOLD: 0"
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	_gold_label.add_theme_font_size_override("font_size", 11)
	add_child(_gold_label)

	_diamond_label = Label.new()
	_diamond_label.position = Vector2(10, 64)
	_diamond_label.text = "💎 DIAMOND: 0"
	_diamond_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	_diamond_label.add_theme_font_size_override("font_size", 11)
	add_child(_diamond_label)

	# Initialize combo label dynamically
	_combo_label = Label.new()
	_combo_label.position = Vector2(10, 82)
	_combo_label.text = ""
	_combo_label.add_theme_color_override("font_color", Color("ffd700"))
	_combo_label.add_theme_font_size_override("font_size", 14)
	add_child(_combo_label)

	# Initialize layer & depth tracker label (top-right anchored)
	_layer_label = Label.new()
	_layer_label.anchors_preset = Control.PRESET_TOP_RIGHT
	_layer_label.anchor_left = 1.0
	_layer_label.anchor_right = 1.0
	_layer_label.offset_left = -250
	_layer_label.offset_top = 10
	_layer_label.offset_right = -10
	_layer_label.offset_bottom = 35
	_layer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_layer_label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	_layer_label.add_theme_font_size_override("font_size", 12)
	add_child(_layer_label)

	# Wait one frame so Player._ready() has had time to run and join its group
	call_deferred("_connect_to_player")


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
		if player.has_signal("gold_changed"):
			player.gold_changed.connect(_on_gold_changed)
		if player.has_signal("diamond_changed"):
			player.diamond_changed.connect(_on_diamond_changed)
		if player.has_signal("depth_changed"):
			player.depth_changed.connect(_on_depth_changed)
		# Sync immediately with current player state
		player.battery_changed.emit(player.battery, player.MAX_BATTERY)
		player.bombs_changed.emit(player.bombs, player.MAX_BOMBS)
		if "gold_count" in player:
			_on_gold_changed(player.gold_count)
		if "diamond_count" in player:
			_on_diamond_changed(player.diamond_count)
		_on_combo_changed(player.combo_count)
		if "current_depth" in player and player.has_method("get_biome_name"):
			_on_depth_changed(player.current_depth, player.get_biome_name(player.current_depth))


func _on_gold_changed(gold_count: int) -> void:
	if _gold_label:
		_gold_label.text = "🟡 GOLD: " + str(gold_count)
		_gold_label.pivot_offset = _gold_label.size * 0.5
		_gold_label.scale = Vector2(1.25, 1.25)
		var tween := create_tween()
		tween.tween_property(_gold_label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)


func _on_diamond_changed(diamond_count: int) -> void:
	if _diamond_label:
		_diamond_label.text = "💎 DIAMOND: " + str(diamond_count)
		_diamond_label.pivot_offset = _diamond_label.size * 0.5
		_diamond_label.scale = Vector2(1.25, 1.25)
		var tween := create_tween()
		tween.tween_property(_diamond_label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)


func _on_depth_changed(depth: int, biome_name: String) -> void:
	if not _layer_label:
		return
	_layer_label.text = "📍 DEPTH: " + str(depth) + "m | " + biome_name
	
	if biome_name != _last_biome_name:
		_last_biome_name = biome_name
		# Visual scale punch transition on entering a new biome layer
		_layer_label.pivot_offset = Vector2(_layer_label.size.x, _layer_label.size.y * 0.5)
		_layer_label.scale = Vector2(1.35, 1.35)
		var tween := create_tween()
		tween.tween_property(_layer_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)


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

	# Trigger Game Over Leaderboard overlay after breakdown animation completes
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(banner):
		banner.queue_free()
	_show_game_over_overlay()


var _game_over_panel: Control = null
var _scores_vbox: VBoxContainer = null
var _board_title_lbl: Label = null


func _show_game_over_overlay() -> void:
	if _game_over_panel:
		return

	var player := get_tree().get_first_node_in_group("player")
	var final_depth: int = player.current_depth if (player and "current_depth" in player) else 0
	var final_gold: int = player.gold_count if (player and "gold_count" in player) else 0
	var final_diamonds: int = player.diamond_count if (player and "diamond_count" in player) else 0
	var final_score: int = player.get_total_score() if (player and player.has_method("get_total_score")) else (final_depth * 10 + final_gold * 100 + final_diamonds * 300)

	_game_over_panel = PanelContainer.new()
	_game_over_panel.anchors_preset = Control.PRESET_CENTER
	_game_over_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_game_over_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_game_over_panel.custom_minimum_size = Vector2(340, 240)
	_game_over_panel.position = Vector2(
		(get_viewport_rect().size.x - 340) * 0.5,
		(get_viewport_rect().size.y - 240) * 0.5
	)

	# Style panel box
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(1.0, 0.82, 0.05) # Gold border
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.content_margin_left = 16
	style_box.content_margin_top = 12
	style_box.content_margin_right = 16
	style_box.content_margin_bottom = 12
	_game_over_panel.add_theme_stylebox_override("panel", style_box)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	_game_over_panel.add_child(main_vbox)

	# Title
	var title_lbl := Label.new()
	title_lbl.text = "🏆 SHATTER-DRILL RUN END 🏆"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.05))
	title_lbl.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(title_lbl)

	# Run Stats
	var stats_lbl := Label.new()
	stats_lbl.text = "Depth: " + str(final_depth) + "m  |  Gold: " + str(final_gold) + "  |  Diamond: " + str(final_diamonds) + "  |  SCORE: " + str(final_score)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8)) # Cyan
	stats_lbl.add_theme_font_size_override("font_size", 11)
	main_vbox.add_child(stats_lbl)

	# Name Input & Submit HBox
	var input_hbox := HBoxContainer.new()
	input_hbox.add_theme_constant_override("separation", 6)
	main_vbox.add_child(input_hbox)

	var name_input := LineEdit.new()
	name_input.placeholder_text = "Enter Miner Name..."
	name_input.text = "Anonymous Miner"
	name_input.custom_minimum_size = Vector2(180, 24)
	name_input.add_theme_font_size_override("font_size", 11)
	input_hbox.add_child(name_input)

	var submit_btn := Button.new()
	submit_btn.text = "Submit Score"
	submit_btn.custom_minimum_size = Vector2(100, 24)
	submit_btn.add_theme_font_size_override("font_size", 11)
	input_hbox.add_child(submit_btn)

	# Leaderboard Board Title
	_board_title_lbl = Label.new()
	_board_title_lbl.text = "--- LEADERBOARD (CONNECTING...) ---"
	_board_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_title_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_board_title_lbl.add_theme_font_size_override("font_size", 10)
	main_vbox.add_child(_board_title_lbl)

	# High Scores Scroll / Container
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 90)
	main_vbox.add_child(scroll)

	_scores_vbox = VBoxContainer.new()
	_scores_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_scores_vbox)

	_refresh_leaderboard_display()

	# Connect submit button
	submit_btn.pressed.connect(func():
		var player_name: String = name_input.text
		if Leaderboard:
			Leaderboard.register_high_score(player_name, final_score, final_depth)
		submit_btn.disabled = true
		submit_btn.text = "SAVED! ✔"
		name_input.editable = false
		await get_tree().create_timer(0.5).timeout
		_refresh_leaderboard_display()
	)

	# Restart / Play Again Button
	var restart_btn := Button.new()
	restart_btn.text = "🔄 PLAY AGAIN"
	restart_btn.custom_minimum_size = Vector2(140, 26)
	restart_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart_btn.add_theme_font_size_override("font_size", 12)
	restart_btn.pressed.connect(func():
		get_tree().reload_current_scene()
	)
	main_vbox.add_child(restart_btn)

	add_child(_game_over_panel)

	# Animate panel pop-in
	_game_over_panel.scale = Vector2(0.2, 0.2)
	_game_over_panel.pivot_offset = _game_over_panel.custom_minimum_size * 0.5
	var tween := create_tween()
	tween.tween_property(_game_over_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_leaderboard_display() -> void:
	if not _scores_vbox:
		return

	# Show temporary loading state
	for child in _scores_vbox.get_children():
		child.queue_free()

	var loading_lbl := Label.new()
	loading_lbl.text = "Fetching Leaderboard..."
	loading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	loading_lbl.add_theme_font_size_override("font_size", 10)
	_scores_vbox.add_child(loading_lbl)

	if Leaderboard:
		if not Leaderboard.online_scores_fetched.is_connected(_on_online_scores_received):
			Leaderboard.online_scores_fetched.connect(_on_online_scores_received)
		Leaderboard.fetch_top_scores_hybrid()


func _on_online_scores_received(top_scores: Array[Dictionary], is_online: bool) -> void:
	if not _scores_vbox:
		return

	for child in _scores_vbox.get_children():
		child.queue_free()

	if _board_title_lbl:
		if is_online:
			_board_title_lbl.text = "--- GLOBAL LEADERBOARD (ONLINE) ---"
			_board_title_lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 0.4)) # Emerald Green
		else:
			_board_title_lbl.text = "--- LOCAL SKG LEADERBOARD (OFFLINE) ---"
			_board_title_lbl.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2)) # Orange

	if top_scores.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No high scores recorded yet. Be the first!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		empty_lbl.add_theme_font_size_override("font_size", 10)
		_scores_vbox.add_child(empty_lbl)
		return

	for i in top_scores.size():
		var entry: Dictionary = top_scores[i]
		var entry_lbl := Label.new()
		var rank_str: String = "#" + str(i + 1) + " "
		var score_text: String = rank_str + str(entry.get("name", "Miner")) + " - " + str(entry.get("score", 0)) + " pts (" + str(entry.get("depth", 0)) + "m)"
		entry_lbl.text = score_text
		entry_lbl.add_theme_font_size_override("font_size", 10)

		# Gold for #1, Silver for #2, Bronze for #3
		if i == 0:
			entry_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
		elif i == 1:
			entry_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		elif i == 2:
			entry_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))
		else:
			entry_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

		_scores_vbox.add_child(entry_lbl)


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

