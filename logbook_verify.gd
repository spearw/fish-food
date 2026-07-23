## logbook_verify.gd -- proves the Logbook end to end:
##   1) the master bestiary list matches world.tscn's ACTUAL EncounterDirector wiring, both ways
##      (nothing spawnable can miss the book; the book carries nothing that cannot spawn)
##   2) every roster entry has a real name and an extractable portrait
##   3) discovery records flow and survive stats DUPLICATES (the spawner's size-scaling path)
##   4) the screen itself renders the right tiles in the right states, details included
## Run: Godot --headless --path . res://logbook_verify.tscn
extends Node

const PanelScript := preload("res://ui/main_menu/logbook_panel.gd")

func _ready() -> void:
	# --- 1) Master list vs world wiring ---
	var book: BestiaryList = load("res://systems/global/lists/master_bestiary_list.tres")
	var state: SceneState = load("res://world/world.tscn").get_state()
	var wired_sets: Array = []
	var wired_heralds: Array = []
	var wired_leviathans: Array = []
	var wired_secret = null
	for i in state.get_node_count():
		if str(state.get_node_name(i)) != "EncounterDirector":
			continue
		for p in state.get_node_property_count(i):
			match state.get_node_property_name(i, p):
				"encounter_sets": wired_sets = state.get_node_property_value(i, p)
				"herald_candidates": wired_heralds = state.get_node_property_value(i, p)
				"leviathan_candidates": wired_leviathans = state.get_node_property_value(i, p)
				"secret_boss_stats": wired_secret = state.get_node_property_value(i, p)
	var wired_swarm: Array = []
	for encounter_set in wired_sets:
		for enemy in encounter_set.enemies:
			if not enemy.display_name in wired_swarm:
				wired_swarm.append(enemy.display_name)
	wired_swarm.sort()
	var swarm: Array = book.swarm_entries()
	var swarm_names: Array = swarm.map(func(e): return e["stats"].display_name)
	swarm_names.sort()
	var wiring_ok: bool = swarm_names == wired_swarm \
		and _names(book.heralds) == _names(wired_heralds) \
		and _names(book.leviathans) == _names(wired_leviathans) \
		and wired_secret != null and book.secret != null \
		and wired_secret.display_name == book.secret.display_name
	print("LOGBOOK wiring: swarm=%d heralds=%d leviathans=%d secret=%s ok=%s" % [
		swarm.size(), book.heralds.size(), book.leviathans.size(),
		str(book.secret != null), str(wiring_ok)])

	# --- 2) Roster hygiene: real names, extractable portraits ---
	var roster: Array = []
	for entry in swarm:
		roster.append(entry["stats"])
	roster.append_array(book.heralds)
	roster.append_array(book.leviathans)
	roster.append(book.secret)
	var hygiene_ok := true
	for stats in roster:
		if stats.display_name in ["", "Entity"] or PanelScript._portrait(stats) == null:
			hygiene_ok = false
			print("LOGBOOK hygiene FAIL on: ", stats.resource_path)
	print("LOGBOOK hygiene: entries=%d ok=%s" % [roster.size(), str(hygiene_ok)])

	# --- 3) Records: deltas only (the dev machine's real save may already hold data), no saving ---
	LogbookData.autosave_on_boss_kill = false
	var k0: int = LogbookData.kills("Pike")
	LogbookData.record_enemy_kill("Pike")
	var kills_ok: bool = LogbookData.kills("Pike") == k0 + 1 and LogbookData.enemy_discovered("Pike")
	var herald: EnemyStats = book.heralds[0]
	LogbookData._on_boss_spawned(null, herald)
	var seen_ok: bool = LogbookData.boss_seen(herald.display_name)
	var d0: int = LogbookData.boss_defeats(herald.display_name)
	LogbookData._on_boss_killed(herald)
	# The spawner hands out size-scaled DUPLICATES (resource_path cleared) -- name keying must hold.
	LogbookData._on_boss_killed(herald.duplicate())
	var defeat_ok: bool = LogbookData.boss_defeats(herald.display_name) == d0 + 2
	var c0: int = LogbookData.card_count("lethal_dose_unlock")
	LogbookData.record_card_taken("lethal_dose_unlock")
	var card_ok: bool = LogbookData.card_count("lethal_dose_unlock") == c0 + 1
	print("LOGBOOK records: kills=%s seen=%s defeats=%s cards=%s" % [
		str(kills_ok), str(seen_ok), str(defeat_ok), str(card_ok)])

	# --- 4) The screen ---
	var panel: Control = load("res://ui/main_menu/logbook_panel.tscn").instantiate()
	add_child(panel)
	panel.open()
	var b_entries: Array = panel._entries["bestiary"]
	var tiles_ok: bool = b_entries.size() == swarm.size() + book.heralds.size() + book.leviathans.size() + 1
	# Tile text is state-driven: hidden entries lead with "?", revealed ones with their name --
	# true on ANY save file, however much it has already discovered.
	var states_ok := true
	var pike_ok := false
	var herald_known := false
	var pike_index := -1
	for i in b_entries.size():
		var entry: Dictionary = b_entries[i]
		var text: String = entry["tile"].text
		if entry["state"] == PanelScript.HIDDEN:
			if not text.begins_with("?"):
				states_ok = false
		elif not text.begins_with(entry["stats"].display_name):
			states_ok = false
		if entry["stats"].display_name == "Pike":
			pike_index = i
			pike_ok = entry["state"] == PanelScript.KNOWN
		if entry["stats"].display_name == herald.display_name:
			herald_known = entry["state"] == PanelScript.KNOWN
	panel._set_reading("bestiary", pike_index)
	var detail_ok: bool = panel._detail.text.contains("Pike") and panel._detail.text.contains("killed")
	print("LOGBOOK bestiary: tiles=%d ok=%s states=%s pike=%s herald=%s detail=%s" % [
		b_entries.size(), str(tiles_ok), str(states_ok), str(pike_ok), str(herald_known), str(detail_ok)])

	panel._select_tab("cards")
	var expected_cards := 0
	for deck in panel._decks:
		for upgrade in deck.upgrades:
			if upgrade != null:
				expected_cards += 1
	var c_entries: Array = panel._entries["cards"]
	var cards_ok: bool = c_entries.size() == expected_cards and expected_cards > 0
	var lethal_ok := false
	for i in c_entries.size():
		if c_entries[i]["upgrade"].id == "lethal_dose_unlock":
			panel._set_reading("cards", i)
			lethal_ok = panel._detail.text.contains("Lethal Dose") \
				and panel._detail.text.contains("die instantly") \
				and panel._detail.text.contains("Taken x")
	var progress_ok: bool = panel._progress_label.text.contains("Bestiary")
	print("LOGBOOK cards: tiles=%d/%d ok=%s lethal=%s progress='%s'" % [
		c_entries.size(), expected_cards, str(cards_ok), str(lethal_ok), panel._progress_label.text])

	var pass_all: bool = wiring_ok and hygiene_ok and kills_ok and seen_ok and defeat_ok \
		and card_ok and tiles_ok and states_ok and pike_ok and herald_known and detail_ok \
		and cards_ok and lethal_ok and progress_ok
	print("LOGBOOK RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()

func _names(list: Array) -> Array:
	var out: Array = []
	for stats in list:
		out.append(stats.display_name)
	out.sort()
	return out
