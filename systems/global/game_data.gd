## game_data.gd
## A Singleton that manages persistent player data, like currency and unlocks.
extends Node

# The file path for our save data. user:// is a special Godot path
# that points to a safe, user-specific location on the computer.
const SAVE_PATH = "user://game_data.save"

# Signals
signal unlocked_characters_changed
signal unlocked_packs_changed
signal souls_changed(new_total: int)
signal permanent_stats_changed

# --- Data To Save ---
# We use a dictionary to hold all our data. This makes saving/loading easy.
var starter_data = {
	"total_souls": 0,
	# The resource path of the currently selected character for the next run.
	"selected_character_path": "res://actors/player/characters/edgerunner/edgerunner_character.tres",
	# A list of resource paths for all characters the player has unlocked.
	"unlocked_character_paths": ["res://actors/player/characters/edgerunner/edgerunner_character.tres"],
	# A list of resource paths for all unlocked upgrade packs.
	"unlocked_pack_paths": ["res://systems/upgrades/packs/core_pack.tres"],
	"permanent_stats": {
		"move_speed": 0.0,
		"damage_increase": 0.0,
		"firerate": 0.0,
		"critical_hit_rate": 0.0,
		"critical_hit_damage": 0.0,
		"armor": 0,
		"max_health": 0,
		"luck": 0.0,
		"area_size": 0.0,
		"xp_multiplier": 0.0,
	}
}
var data = starter_data.duplicate()

## DEV SWITCH ("for now", July 2026): every character and deck is unlocked at boot. Runs every start
## and unions with the save, so new content auto-unlocks and existing saves aren't wiped. Note that
## saving persists the unions -- flipping this back off later won't re-lock anything already saved.
const DEV_UNLOCK_ALL := true

func _ready():
	load_data()
	if DEV_UNLOCK_ALL:
		_dev_unlock_all()

## Unions the unlock lists with everything in the master lists (quietly -- no signals; this runs
## before any UI exists).
func _dev_unlock_all() -> void:
	var characters = load("res://systems/global/lists/master_character_list.tres")
	for c in characters.characters:
		if not c.resource_path in data["unlocked_character_paths"]:
			data["unlocked_character_paths"].append(c.resource_path)
	var decks = load("res://systems/global/lists/master_pack_list.tres")
	for deck in decks.decks:
		if not deck.resource_path in data["unlocked_pack_paths"]:
			data["unlocked_pack_paths"].append(deck.resource_path)

# --- Public API ---
func add_souls(amount: int):
	data["total_souls"] += amount
	Logs.add_message(["Souls collected! Total: ", data["total_souls"]])
	souls_changed.emit(data["total_souls"])

func spend_souls(amount: int) -> bool:
	if data["total_souls"] >= amount:
		data["total_souls"] -= amount
		souls_changed.emit(data["total_souls"])
		return true
	return false

func get_souls() -> int:
	return data["total_souls"]

## Upgrades a permanent stat by the given amount.
func upgrade_permanent_stat(stat_key: String, amount: float):
	if not data["permanent_stats"].has(stat_key):
		data["permanent_stats"][stat_key] = 0.0
	data["permanent_stats"][stat_key] += amount
	permanent_stats_changed.emit()
	Logs.add_message(["Permanent stat upgraded: ", stat_key, " +", amount])

## Gets the current value of a permanent stat.
func get_permanent_stat(stat_key: String) -> float:
	return data["permanent_stats"].get(stat_key, 0.0)

## Gets the current level of a permanent stat upgrade (for MetaUpgrade system).
func get_permanent_stat_level(stat_key: String, value_per_level: float) -> int:
	var current_value = get_permanent_stat(stat_key)
	if value_per_level <= 0:
		return 0
	return int(current_value / value_per_level)

## Sets the character to be used for the next run.
## @param character_data_path: String - The resource path of the PlayerStats .tres file.
func set_selected_character(character_data_path: String):
	if character_data_path in data["unlocked_character_paths"]:
		data["selected_character_path"] = character_data_path
		Logs.add_message(["Selected character: ", character_data_path])
	else:
		printerr("Attempted to select a character that is not unlocked: ", character_data_path)

## Adds a new character to the list of unlocked characters.
## @param character_data_path: String - The resource path to unlock.
func unlock_character(character_data_path: String):
	if not character_data_path in data["unlocked_character_paths"]:
		data["unlocked_character_paths"].append(character_data_path)
		Logs.add_message(["Unlocked new character: ", character_data_path])
		# Emit signal that character was unlocked.
		unlocked_characters_changed.emit()
		
func unlock_pack(pack_path: String):
	if not pack_path in data["unlocked_pack_paths"]:
		data["unlocked_pack_paths"].append(pack_path)
		Logs.add_message(["Unlocked new pack: ", pack_path])
		unlocked_packs_changed.emit()

# --- Save/Load Logic ---
func save_data():
	# Open the file for writing.
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		# Convert the data dictionary to a JSON string.
		var json_string = JSON.stringify(data, "\t")
		# Write the string to the file.
		file.store_string(json_string)
		Logs.add_message("Game data saved successfully.")
	else:
		printerr("Failed to open save file for writing.")

func load_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			# Read the entire file as text.
			var json_string = file.get_as_text()
			# Parse the JSON string back into a Godot variant (our dictionary).
			var parse_result = JSON.parse_string(json_string)
			if parse_result:
				data = parse_result
				Logs.add_message("Game data loaded successfully.")
			else:
				printerr("Failed to parse save file JSON.")
		else:
			printerr("Failed to open save file for reading.")
	else:
		Logs.add_message("No save file found. Using default data.")
		
## Deletes the save file from the disk.
func clear_save_file():
	var dir = DirAccess.open("user://")
	# Reset active game data
	data = starter_data.duplicate()
	## TODO: Generalize signal to all components
	unlocked_characters_changed.emit()
	# Clear save file
	if dir.file_exists(SAVE_PATH):
		var err = dir.remove(SAVE_PATH.replace("user://", "")) # DirAccess.remove needs a relative path
		if err == OK:
			Logs.add_message("Save file deleted successfully.")
		else:
			printerr("Error deleting save file. Code: ", err)
	else:
		Logs.add_message("No save file to delete.")
