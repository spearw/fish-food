extends Node
## Headless check of the character<->deck link and the two-themed-deck rule. Run with --headless.
##   1. The character's primary deck is granted free, and the cap never clips it.
##   2. The player's picks fill only the slots the primary leaves open; extras are dropped.
##   3. An "open" character (no primary) picks both themed decks.
##   4. Neither the core deck nor a duplicate of the primary can waste a themed slot.
##   5. Character-exclusive cards enter the pool, credited to the primary deck's draft count.
##   6. Content: a linked character's cards live in no deck -- that's what makes them exclusive.

const CORE := "res://systems/upgrades/packs/core_pack.tres"
const FIRE := "res://systems/upgrades/packs/fire_pack.tres"
const LIGHTNING := "res://systems/upgrades/packs/lightning_pack.tres"
const MELEE := "res://systems/upgrades/packs/melee_pack.tres"

## Compose a run's decks for a given character + picks.
func _decks(character: PlayerStats, picks: Array[String]) -> Array[String]:
	CurrentRun.selected_character = character
	CurrentRun.selected_pack_paths = picks
	return CurrentRun.get_active_deck_paths()

func _ready() -> void:
	var pass_all := true

	var mage := PlayerStats.new()
	mage.display_name = "Test Mage"
	mage.primary_deck = load(FIRE)
	var open_char := PlayerStats.new()  # no linked deck -- chooses both themed decks

	# 1. Primary is granted even with no picks; 2. picks fill the one remaining slot.
	var granted_ok: bool = _decks(mage, []) == [CORE, FIRE]
	var secondary_ok: bool = _decks(mage, [LIGHTNING]) == [CORE, FIRE, LIGHTNING]

	# 3. The cap drops the extra pick -- and keeps the primary, which is the character's identity.
	var capped := _decks(mage, [LIGHTNING, MELEE])
	var cap_ok: bool = capped == [CORE, FIRE, LIGHTNING]

	# 4. An open character picks both; a third is still dropped.
	var open_ok: bool = _decks(open_char, [FIRE, LIGHTNING]) == [CORE, FIRE, LIGHTNING] \
		and _decks(open_char, [FIRE, LIGHTNING, MELEE]) == [CORE, FIRE, LIGHTNING]

	# 5. Re-picking the primary, or the always-granted core, can't burn a themed slot.
	var dedupe_ok: bool = _decks(mage, [FIRE, LIGHTNING]) == [CORE, FIRE, LIGHTNING] \
		and _decks(mage, [CORE, LIGHTNING]) == [CORE, FIRE, LIGHTNING]

	# 6. Slot math the deck picker relies on.
	var slots_ok: bool = CurrentRun.get_secondary_deck_slots_for(mage) == 1 \
		and CurrentRun.get_secondary_deck_slots_for(open_char) == 2 \
		and CurrentRun.get_secondary_deck_slots_for(null) == 2

	print("DECKLINK granted=%s secondary=%s cap=%s open=%s dedupe=%s slots=%s" % [
		str(granted_ok), str(secondary_ok), str(cap_ok), str(open_ok), str(dedupe_ok), str(slots_ok)])
	pass_all = pass_all and granted_ok and secondary_ok and cap_ok and open_ok and dedupe_ok and slots_ok

	# --- Exclusive cards reach the pool and count as primary-deck investment ---
	var exclusive := Upgrade.new()
	exclusive.id = "test_exclusive_evolution"
	exclusive.type = Upgrade.UpgradeType.TRANSFORMATION
	exclusive.rarity = Upgrade.Rarity.RARE
	exclusive.target_class_name = "TestExclusiveWeapon"
	mage.exclusive_upgrades = [exclusive]

	CurrentRun.selected_character = mage
	CurrentRun.selected_pack_paths = []
	# UpgradeManager is a scene node, not an autoload; adding it fires _ready -> builds the pool.
	var um = load("res://systems/upgrades/upgrade_manager.gd").new()
	add_child(um)
	var exclusive_ok: bool = exclusive in um.active_upgrade_pool \
		and um._upgrade_deck_ids.get(exclusive, "") == "fire"
	pass_all = pass_all and exclusive_ok
	print("DECKLINK exclusive_in_pool=%s credited_to=%s pool=%d" % [
		str(exclusive in um.active_upgrade_pool), str(um._upgrade_deck_ids.get(exclusive, "")),
		um.active_upgrade_pool.size()])

	# --- Content: no linked character's cards may appear in any deck ---
	var deck_of_card := {}
	var deck_list = load("res://systems/global/lists/master_pack_list.tres")
	for deck in deck_list.decks:
		for card in deck.upgrades:
			deck_of_card[card] = deck.id

	var leaked: Array[String] = []
	var linked := 0
	var char_list = load("res://systems/global/lists/master_character_list.tres")
	for c in char_list.characters:
		if not c.primary_deck:
			continue
		linked += 1
		for card in (c.starting_upgrades + c.exclusive_upgrades):
			if card and deck_of_card.has(card):
				leaked.append("%s's %s is in deck '%s'" % [c.display_name, card.id, deck_of_card[card]])

	var content_ok: bool = leaked.is_empty()
	pass_all = pass_all and content_ok
	print("DECKLINK content: linked_characters=%d leaked=%s" % [linked, str(leaked)])

	# --- The pre-run picker: a linked character's primary shows as granted, the core deck isn't
	#     offered as a choice, and only the leftover slot is selectable ---
	var panel = load("res://ui/main_menu/character_select_panel.tscn").instantiate()
	add_child(panel)
	panel._select_character_by_data(load("res://actors/player/characters/magic_man/magic_man_character.tres"))
	# The panel already populated once for the default character in its _ready. queue_free() is
	# deferred, so wait a frame or those stale buttons are still children and get counted here.
	await get_tree().process_frame
	var granted_buttons := 0
	var choosable := 0
	var core_offered := false
	for b in panel.pack_grid.get_children():
		if b.deck_data.resource_path == CurrentRun.CORE_DECK_PATH:
			core_offered = true
		if b.is_granted:
			granted_buttons += 1
		else:
			choosable += 1
	var panel_ok: bool = granted_buttons == 1 and not core_offered and choosable > 0 \
		and panel.selected_packs.size() <= 1
	pass_all = pass_all and panel_ok
	print("DECKLINK picker: granted=%d choosable=%d core_offered=%s picked=%d" % [
		granted_buttons, choosable, str(core_offered), panel.selected_packs.size()])

	print("DECKLINK RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
