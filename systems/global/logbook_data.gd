## logbook_data.gd -- discovery tracking behind the Logbook screen. Autoload "LogbookData".
## Records live inside GameData.data["logbook"] (they ride the existing save file):
##   enemy_kills:   {display_name: int}   -- every enemy death, bosses included
##   bosses_seen:   {display_name: true}  -- the HP-bar moment (boss_spawned), kill or no kill
##   bosses_killed: {display_name: int}
##   cards_taken:   {upgrade_id: int}     -- every card actually applied, granted included
## Keyed by display_name / id, NOT resource_path: the spawner duplicates stats resources at spawn
## (size scaling), and duplicate() clears resource_path -- names survive duplication.
extends Node

## Boss kills persist on the spot (they are rare and precious). Verifiers and dev harnesses flip
## this off so simulated kills never touch the real save file.
var autosave_on_boss_kill := true

func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.boss_killed.connect(_on_boss_killed)
	Events.leviathan_killed.connect(_on_boss_killed)
	Events.secret_boss_killed.connect(_on_boss_killed)

## The logbook dictionary inside GameData, lazily built so pre-logbook saves keep working.
func _book() -> Dictionary:
	var data: Dictionary = GameData.data
	if not data.has("logbook"):
		data["logbook"] = {}
	var book: Dictionary = data["logbook"]
	for key in ["enemy_kills", "bosses_seen", "bosses_killed", "cards_taken"]:
		if not book.has(key):
			book[key] = {}
	return book

# --- Recording ---

func _on_enemy_killed(enemy: Node) -> void:
	if enemy == null or not "stats" in enemy or enemy.stats == null:
		return
	record_enemy_kill(enemy.stats.display_name)

func record_enemy_kill(display_name: String) -> void:
	if display_name == "":
		return
	var kills: Dictionary = _book()["enemy_kills"]
	kills[display_name] = int(kills.get(display_name, 0)) + 1

func _on_boss_spawned(_boss, stats) -> void:
	if stats == null:
		return
	_book()["bosses_seen"][stats.display_name] = true

func _on_boss_killed(stats) -> void:
	if stats == null:
		return
	var killed: Dictionary = _book()["bosses_killed"]
	killed[stats.display_name] = int(killed.get(stats.display_name, 0)) + 1
	_book()["bosses_seen"][stats.display_name] = true
	if autosave_on_boss_kill:
		GameData.save_data()

func record_card_taken(id: String) -> void:
	if id == "":
		return
	var taken: Dictionary = _book()["cards_taken"]
	taken[id] = int(taken.get(id, 0)) + 1

# --- Queries (what the Logbook screen reads) ---

func kills(display_name: String) -> int:
	return int(_book()["enemy_kills"].get(display_name, 0))

func enemy_discovered(display_name: String) -> bool:
	return kills(display_name) > 0

func boss_seen(display_name: String) -> bool:
	return bool(_book()["bosses_seen"].get(display_name, false)) or boss_defeats(display_name) > 0

func boss_defeats(display_name: String) -> int:
	return int(_book()["bosses_killed"].get(display_name, 0))

func card_count(id: String) -> int:
	return int(_book()["cards_taken"].get(id, 0))
