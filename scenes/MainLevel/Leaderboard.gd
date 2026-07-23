extends Node

const SAVE_PATH = "user://local_leaderboard.cfg"
const MAX_BOARD_ENTRIES = 10


## Saves a new score entry and reorganizes the board locally in ConfigFile format.
func register_high_score(player_name: String, final_score: int, final_depth: int) -> void:
	var config = ConfigFile.new()
	var scores_list: Array[Dictionary] = []

	# Load historical high scores if the configuration file already exists
	if config.load(SAVE_PATH) == OK:
		if config.has_section("Leaderboard"):
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

	# Append the fresh run data
	var clean_name: String = player_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "Anonymous Miner"

	scores_list.append({
		"name": clean_name,
		"score": final_score,
		"depth": final_depth
	})

	# Sort the array in descending order based on score metric
	scores_list.sort_custom(func(a, b): return a["score"] > b["score"])

	# Constrain the listing to top slots
	if scores_list.size() > MAX_BOARD_ENTRIES:
		scores_list.resize(MAX_BOARD_ENTRIES)

	# Overwrite the configuration file securely
	config.clear()
	for i in scores_list.size():
		var item: Dictionary = scores_list[i]
		var key: String = "entry_" + str(i + 1)
		config.set_value("Leaderboard", key, [item["score"], item["depth"], item["name"]])

	config.save(SAVE_PATH)
	print("SKG Leaderboard score saved cleanly at: ", OS.get_user_data_dir())


## Reads configuration data from disk to populate the User Interface.
func get_top_scores() -> Array[Dictionary]:
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
