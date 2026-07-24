extends Control

const SHARD_COUNT: int = 10
const SHARD_SIZE: Vector2 = Vector2(14.0, 14.0)
const HALF_SHARD_SIZE: Vector2 = Vector2(7.0, 14.0)
const COLOR_FULL: Color  = Color(1.00, 0.82, 0.05)  # warm gold
const COLOR_ALERT: Color = Color(1.00, 0.15, 0.15)  # pulse red
const COLOR_EMPTY: Color = Color(0.18, 0.18, 0.20)  # near-black

const MULTICULTURAL_MINER_NAMES: Array[String] = [
	"Hafir", "Kopacz", "Bergmann", "Madenci", "Khanak",
	"Minero", "Minatore", "Kaevur", "Gornik", "Tunneller",
	"Excavator", "Prospector", "DeepDriller", "OreSeeker", "BedrockBuster",
	"GoldDigger", "DiamondHunter", "IronClad", "Pikeman", "CoreBreaker",
	"RockCutter", "DirtGobbler", "StoneStriker", "QuarryMaster", "ShaftSinker",
	"TunnelMole", "EarthBorer", "GroundCrusher", "GeoDriller", "CaveExplorer",
	"VeinHunter", "DrillRig", "SeamSeeker", "ShovelKnight", "PickaxePete",
	"CragCrusher", "LodeRunner", "MuckRaker", "SlagSifter", "NuggetNabor",
	"ShatterDrill", "Subterranean", "Mineshaft", "Mineur", "Koupa",
	"Minaio", "PitBoss", "ChiselMaster", "StrataSmasher", "GrottoGrinder"
]


static func generate_random_miner_name() -> String:
	var base_name: String = MULTICULTURAL_MINER_NAMES[randi() % MULTICULTURAL_MINER_NAMES.size()]
	var random_num: int = randi_range(1000, 9999)
	return base_name + str(random_num)

var _tex_battery_empty: AtlasTexture
var _tex_battery_half: AtlasTexture
var _tex_battery_full: AtlasTexture
var _tex_bomb_hud: AtlasTexture
var _tex_diamond_hud: AtlasTexture
var _tex_gold_hud: AtlasTexture

var _battery_texture_rects: Array[TextureRect] = []
var _bomb_texture_rects: Array[TextureRect] = []
var _gold_container: HBoxContainer
var _diamond_container: HBoxContainer
var _combo_label: Label
var _gold_label: Label
var _diamond_label: Label
var _layer_label: Label
var _bomb_container: HBoxContainer
var _is_low_battery: bool = false
var _pulse_timer: float = 0.0
var _current_active_color: Color = Color.WHITE
var _vignette: ColorRect = null
var _last_biome_name: String = ""
var _last_submitted_player_name: String = ""
var _scroll_container: ScrollContainer = null

@onready var _container: HBoxContainer = $BatteryContainer


func _ready() -> void:
	# Create red screen vignette overlay
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color(1.0, 0.0, 0.0, 0.0)
	_vignette.z_index = -1
	add_child(_vignette)

	# Initialize AtlasTextures from GameSpecificTiles.png
	var tile_sheet: Texture2D = preload("res://assets/GameSpecificTiles.png")
	
	_tex_battery_empty = AtlasTexture.new()
	_tex_battery_empty.atlas = tile_sheet
	_tex_battery_empty.region = Rect2(68, 85, 16, 16) # Tile (4, 5)

	_tex_battery_half = AtlasTexture.new()
	_tex_battery_half.atlas = tile_sheet
	_tex_battery_half.region = Rect2(85, 85, 16, 16) # Tile (5, 5)

	_tex_battery_full = AtlasTexture.new()
	_tex_battery_full.atlas = tile_sheet
	_tex_battery_full.region = Rect2(102, 85, 16, 16) # Tile (6, 5)

	_tex_bomb_hud = AtlasTexture.new()
	_tex_bomb_hud.atlas = tile_sheet
	_tex_bomb_hud.region = Rect2(85, 17, 16, 16) # Tile (5, 1)

	_tex_diamond_hud = AtlasTexture.new()
	_tex_diamond_hud.atlas = tile_sheet
	_tex_diamond_hud.region = Rect2(102, 17, 16, 16) # Tile (6, 1)

	_tex_gold_hud = AtlasTexture.new()
	_tex_gold_hud.atlas = tile_sheet
	_tex_gold_hud.region = Rect2(119, 17, 16, 16) # Tile (7, 1)

	_container.add_theme_constant_override("separation", 2)

	for i in SHARD_COUNT:
		var tex_rect := TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(16, 16)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.texture = _tex_battery_full
		_container.add_child(tex_rect)
		_battery_texture_rects.append(tex_rect)

	# Setup Bomb Container
	_bomb_container = HBoxContainer.new()
	_bomb_container.position = Vector2(10, 30)
	_bomb_container.add_theme_constant_override("separation", 3)
	for i in 3:
		var tex_rect := TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(16, 16)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.texture = _tex_bomb_hud
		_bomb_container.add_child(tex_rect)
		_bomb_texture_rects.append(tex_rect)
	add_child(_bomb_container)

	# Initialize Gold & Diamond counter HBoxContainers with Atlas icons
	_gold_container = HBoxContainer.new()
	_gold_container.position = Vector2(10, 50)
	_gold_container.add_theme_constant_override("separation", 4)
	
	var gold_icon := TextureRect.new()
	gold_icon.custom_minimum_size = Vector2(14, 14)
	gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gold_icon.texture = _tex_gold_hud
	_gold_container.add_child(gold_icon)
	
	_gold_label = Label.new()
	_gold_label.text = "GOLD: 0"
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	_gold_label.add_theme_font_size_override("font_size", 11)
	_gold_container.add_child(_gold_label)
	add_child(_gold_container)

	_diamond_container = HBoxContainer.new()
	_diamond_container.position = Vector2(10, 68)
	_diamond_container.add_theme_constant_override("separation", 4)

	var diamond_icon := TextureRect.new()
	diamond_icon.custom_minimum_size = Vector2(14, 14)
	diamond_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	diamond_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	diamond_icon.texture = _tex_diamond_hud
	_diamond_container.add_child(diamond_icon)

	_diamond_label = Label.new()
	_diamond_label.text = "DIAMOND: 0"
	_diamond_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	_diamond_label.add_theme_font_size_override("font_size", 11)
	_diamond_container.add_child(_diamond_label)
	add_child(_diamond_container)

	# Initialize combo label dynamically
	_combo_label = Label.new()
	_combo_label.position = Vector2(10, 88)
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
		_current_active_color = Color.WHITE.lerp(COLOR_ALERT, pulse)
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
		_gold_label.text = "GOLD: " + str(gold_count)
	if _gold_container:
		_gold_container.pivot_offset = Vector2(0, _gold_container.size.y * 0.5)
		_gold_container.scale = Vector2(1.25, 1.25)
		var tween := create_tween()
		tween.tween_property(_gold_container, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)


func _on_diamond_changed(diamond_count: int) -> void:
	if _diamond_label:
		_diamond_label.text = "DIAMOND: " + str(diamond_count)
	if _diamond_container:
		_diamond_container.pivot_offset = Vector2(0, _diamond_container.size.y * 0.5)
		_diamond_container.scale = Vector2(1.25, 1.25)
		var tween := create_tween()
		tween.tween_property(_diamond_container, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)


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
	for i in _battery_texture_rects.size():
		var cell_val: float = current - float(i)
		var tex_rect: TextureRect = _battery_texture_rects[i]
		if cell_val >= 0.75:
			tex_rect.texture = _tex_battery_full
		elif cell_val >= 0.25:
			tex_rect.texture = _tex_battery_half
		else:
			tex_rect.texture = _tex_battery_empty
	_update_shard_colors()


func _update_shard_colors() -> void:
	var active_color: Color = _current_active_color if _is_low_battery else Color.WHITE
	for tex_rect in _battery_texture_rects:
		tex_rect.modulate = active_color


func _on_bombs_changed(count: int, _max_bombs: int = 3) -> void:
	for i in _bomb_texture_rects.size():
		var rect: TextureRect = _bomb_texture_rects[i]
		if i < count:
			rect.modulate = Color.WHITE
		else:
			rect.modulate = Color(0.25, 0.25, 0.3, 0.4)


func _on_low_battery_warning(is_low: bool) -> void:
	_is_low_battery = is_low
	if _is_low_battery:
		# Scale punch HUD battery container to grab immediate attention
		_container.pivot_offset = Vector2(0, _container.size.y * 0.5)
		_container.scale = Vector2(1.25, 1.25)
		var tween := create_tween()
		tween.tween_property(_container, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	else:
		_current_active_color = Color.WHITE
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
	name_input.text = generate_random_miner_name()
	name_input.custom_minimum_size = Vector2(180, 24)
	name_input.add_theme_font_size_override("font_size", 11)
	input_hbox.add_child(name_input)

	var submit_btn := Button.new()
	submit_btn.text = "Submit Score"
	submit_btn.custom_minimum_size = Vector2(100, 24)
	submit_btn.add_theme_font_size_override("font_size", 11)
	input_hbox.add_child(submit_btn)
	_wire_ui_sounds(submit_btn)

	# Leaderboard Board Title
	_board_title_lbl = Label.new()
	_board_title_lbl.text = "--- LEADERBOARD (CONNECTING...) ---"
	_board_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_title_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_board_title_lbl.add_theme_font_size_override("font_size", 10)
	main_vbox.add_child(_board_title_lbl)

	# High Scores Scroll / Container
	_scroll_container = ScrollContainer.new()
	_scroll_container.custom_minimum_size = Vector2(300, 90)
	main_vbox.add_child(_scroll_container)

	_scores_vbox = VBoxContainer.new()
	_scores_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(_scores_vbox)

	_refresh_leaderboard_display()

	# Connect submit button
	submit_btn.pressed.connect(func():
		var player_name: String = name_input.text.strip_edges()
		if player_name.is_empty():
			player_name = generate_random_miner_name()
		_last_submitted_player_name = player_name
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
	_wire_ui_sounds(restart_btn)
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

	# Find index of current player's submitted score
	var player_index: int = -1
	if not _last_submitted_player_name.is_empty():
		for i in top_scores.size():
			if str(top_scores[i].get("name", "")) == _last_submitted_player_name:
				player_index = i
				break

	# Determine rendering indices:
	# If player_index <= 9 or player_index == -1: render full list up to 10+
	# If player_index > 9: render Top 3 + "..." + (player_index - 1, player_index, player_index + 1)
	var indices_to_render: Array[int] = []
	var show_ellipsis_before_context: bool = false

	if player_index > 9:
		indices_to_render.append(0)
		indices_to_render.append(1)
		indices_to_render.append(2)
		show_ellipsis_before_context = true
		
		for idx in range(player_index - 1, min(player_index + 2, top_scores.size())):
			if not indices_to_render.has(idx):
				indices_to_render.append(idx)
	else:
		for i in top_scores.size():
			indices_to_render.append(i)

	var highlighted_panel: PanelContainer = null

	for i in indices_to_render.size():
		var idx: int = indices_to_render[i]
		
		if show_ellipsis_before_context and i == 3:
			var ellipsis_lbl := Label.new()
			ellipsis_lbl.text = "   . . .   . . .   . . ."
			ellipsis_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ellipsis_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			ellipsis_lbl.add_theme_font_size_override("font_size", 9)
			_scores_vbox.add_child(ellipsis_lbl)

		var entry: Dictionary = top_scores[idx]
		var is_player: bool = (idx == player_index) or (not _last_submitted_player_name.is_empty() and str(entry.get("name", "")) == _last_submitted_player_name)

		if is_player:
			var panel := PanelContainer.new()
			var p_style := StyleBoxFlat.new()
			p_style.bg_color = Color(0.0, 0.35, 0.45, 0.85) # Deep cyan background
			p_style.border_width_left = 1
			p_style.border_width_top = 1
			p_style.border_width_right = 1
			p_style.border_width_bottom = 1
			p_style.border_color = Color(0.0, 1.0, 0.9) # Bright glowing cyan border
			p_style.corner_radius_top_left = 4
			p_style.corner_radius_top_right = 4
			p_style.corner_radius_bottom_left = 4
			p_style.corner_radius_bottom_right = 4
			p_style.content_margin_left = 6
			p_style.content_margin_top = 2
			p_style.content_margin_right = 6
			p_style.content_margin_bottom = 2
			panel.add_theme_stylebox_override("panel", p_style)

			var entry_lbl := Label.new()
			var score_text: String = "👉 #" + str(idx + 1) + " " + str(entry.get("name", "Miner")) + " - " + str(entry.get("score", 0)) + " pts (" + str(entry.get("depth", 0)) + "m)  (YOU) 👈"
			entry_lbl.text = score_text
			entry_lbl.add_theme_font_size_override("font_size", 10)
			entry_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2)) # Bright Gold/Yellow
			panel.add_child(entry_lbl)

			_scores_vbox.add_child(panel)
			highlighted_panel = panel

			# Soft pulsing glow animation on player's box border
			var pulse_tween := create_tween()
			pulse_tween.set_loops(4)
			pulse_tween.tween_property(panel, "modulate", Color(1.3, 1.3, 1.3), 0.3)
			pulse_tween.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0), 0.3)
		else:
			var entry_lbl := Label.new()
			var rank_str: String = "#" + str(idx + 1) + " "
			var score_text: String = rank_str + str(entry.get("name", "Miner")) + " - " + str(entry.get("score", 0)) + " pts (" + str(entry.get("depth", 0)) + "m)"
			entry_lbl.text = score_text
			entry_lbl.add_theme_font_size_override("font_size", 10)

			# Gold for #1, Silver for #2, Bronze for #3
			if idx == 0:
				entry_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
			elif idx == 1:
				entry_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
			elif idx == 2:
				entry_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))
			else:
				entry_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

			_scores_vbox.add_child(entry_lbl)

	# Auto-scroll to center player entry inside ScrollContainer
	if highlighted_panel and _scroll_container:
		call_deferred("_scroll_to_highlighted_panel", highlighted_panel)


func _scroll_to_highlighted_panel(panel: PanelContainer) -> void:
	if not is_instance_valid(panel) or not is_instance_valid(_scroll_container):
		return
	var panel_y: float = panel.position.y
	var scroll_target: int = max(0, int(panel_y - (_scroll_container.size.y * 0.5) + (panel.size.y * 0.5)))
	var scroll_tween := create_tween()
	scroll_tween.tween_property(_scroll_container, "scroll_vertical", scroll_target, 0.4).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)


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

func _wire_ui_sounds(button: Button) -> void:
	if not button:
		return
	button.mouse_entered.connect(func(): if EventBus: EventBus.ui_button_hovered.emit())
	button.pressed.connect(func(): if EventBus: EventBus.ui_button_clicked.emit())
