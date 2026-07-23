extends Node

# --- SILENTWOLF PLUGIN CONFIGURATION ---
const API_KEY: String = "O30o2TdARI1uHIgWgP3nX1SSX6AAOWgd4ue0cOjb"
const GAME_ID: String = "digger"
const LEADERBOARD_NAME: String = "main"

# --- LOCAL SKG FALLBACK CONFIGURATION ---
const SAVE_PATH: String = "user://local_leaderboard.cfg"
const MAX_BOARD_ENTRIES: int = 50

signal online_scores_fetched(scores: Array[Dictionary], is_online: bool)


func _ready() -> void:
	# Configure the SilentWolf plugin with credentials
	SilentWolf.configure({
		"api_key": API_KEY,
		"game_id": GAME_ID,
		"log_level": 1
	})


## Registers score locally (SKG safety) and asynchronously submits online via SilentWolf plugin.
func register_high_score(player_name: String, final_score: int, final_depth: int) -> void:
	var clean_name: String = player_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "Anonymous Miner"

	# 1. ALWAYS Save locally first for guaranteed preservation (SKG Compliance)
	save_score_locally(clean_name, final_score, final_depth)

	# 2. Submit online via SilentWolf plugin (fire and forget, with result logged)
	_post_score_online(clean_name, final_score, final_depth)


## Saves score entry directly to user://local_leaderboard.cfg.
func save_score_locally(player_name: String, final_score: int, final_depth: int) -> void:
	var config = ConfigFile.new()
	var scores_list: Array[Dictionary] = []

	if config.load(SAVE_PATH) == OK and config.has_section("Leaderboard"):
		var saved_keys = config.get_section_keys("Leaderboard")
		for entry_key in saved_keys:
			var entry_data = config.get_value("Leaderboard", entry_key)
			if entry_data is Array and entry_data.size() >= 2:
				var item_name: String = entry_data[2] if entry_data.size() >= 3 else entry_key
				scores_list.append({
					"name": item_name,
					"score": int(entry_data[0]),
					"depth": int(entry_data[1])
				})

	scores_list.append({
		"name": player_name,
		"score": final_score,
		"depth": final_depth
	})

	scores_list.sort_custom(func(a, b): return a["score"] > b["score"])

	if scores_list.size() > MAX_BOARD_ENTRIES:
		scores_list.resize(MAX_BOARD_ENTRIES)

	config.clear()
	for i in scores_list.size():
		var item: Dictionary = scores_list[i]
		var key: String = "entry_" + str(i + 1)
		config.set_value("Leaderboard", key, [item["score"], item["depth"], item["name"]])

	config.save(SAVE_PATH)
	print("SKG Leaderboard score saved locally at: ", OS.get_user_data_dir())


## Posts score online using the SilentWolf plugin.
func _post_score_online(player_name: String, final_score: int, final_depth: int) -> void:
	await SilentWolf.check_scores_ready()
	SilentWolf.Scores.save_score(player_name, final_score, LEADERBOARD_NAME, {"depth": final_depth})
	var sw_result = await SilentWolf.Scores.sw_save_score_complete
	if sw_result.get("success", false):
		print("SilentWolf: Score posted online successfully!")
	else:
		print("SilentWolf: Online score post failed. Local copy preserved. Error: ", sw_result.get("error", "unknown"))


## Fetches top scores: Tries online SilentWolf backend first, seamlessly falls back to local.
func fetch_top_scores_hybrid() -> void:
	await SilentWolf.check_scores_ready()
	SilentWolf.Scores.get_scores(50, LEADERBOARD_NAME)

	var sw_result = await SilentWolf.Scores.sw_get_scores_complete
	if sw_result.get("success", false):
		var raw_scores: Array = sw_result.get("scores", [])
		var parsed_scores: Array[Dictionary] = []
		for entry in raw_scores:
			if entry is Dictionary:
				var meta = entry.get("metadata", {})
				var depth_val: int = 0
				if meta is Dictionary:
					depth_val = int(meta.get("depth", 0))
				parsed_scores.append({
					"name": str(entry.get("player_name", "Miner")),
					"score": int(entry.get("score", 0)),
					"depth": depth_val
				})
		print("SilentWolf: Loaded ", parsed_scores.size(), " scores from online backend.")
		online_scores_fetched.emit(parsed_scores, true)
	else:
		print("SilentWolf: Online fetch failed. Using local SKG fallback. Error: ", sw_result.get("error", "unknown"))
		online_scores_fetched.emit(get_top_scores_local(), false)


## Reads scores from local user://local_leaderboard.cfg.
func get_top_scores_local() -> Array[Dictionary]:
	var config = ConfigFile.new()
	var output_array: Array[Dictionary] = []

	if config.load(SAVE_PATH) != OK:
		return []

	if config.has_section("Leaderboard"):
		var saved_keys = config.get_section_keys("Leaderboard")
		for entry_key in saved_keys:
			var data = config.get_value("Leaderboard", entry_key)
			if data is Array and data.size() >= 2:
				var item_name: String = data[2] if data.size() >= 3 else "Miner"
				output_array.append({
					"name": item_name,
					"score": int(data[0]),
					"depth": int(data[1])
				})

	output_array.sort_custom(func(a, b): return a["score"] > b["score"])
	return output_array
