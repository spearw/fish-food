extends Node
## Headless check of weapon duplicates: copies, merges, in-place upgrades, and the tier-sensitive
## offer filter (design doc section 3). Run with --headless.
##   1. Free slot: taking a weapon card adds a COPY -- even if owned (never auto-merges with room).
##   2. Full + same-tier copy owned: MERGE -- that copy goes up a tier, damage rescales, no new node.
##   3. Full + only lower-tier copies: REPLACE -- the lowest copy becomes the rolled tier, in place.
##   4. Offer filter at a full loadout: same-tier = offerable (merge), higher = offerable (replace),
##      lower-than-everything = DEAD (hidden), unowned weapon = hidden, Mythic-on-Mythic = hidden.
##   5. set_rarity rescales the whole damage tree (the nested-explosion lesson) and dev unlock-all
##      leaves every character and deck unlocked.

const DAGGER := "res://systems/upgrades/weapons/daggers_unlock.tres"
const STAFF := "res://systems/upgrades/weapons/fire/fireball_staff/fireball_staff_unlock.tres"

class MockItem:
	extends Node2D
	var is_transformed: bool = false

class MockPlayer:
	extends Node2D
	func _init() -> void:
		var equipment := Node2D.new()
		equipment.name = "Equipment"
		add_child(equipment)
		var artifacts := Node2D.new()
		artifacts.name = "Artifacts"
		add_child(artifacts)
	func get_stat(_key): return 1.0
	func notify_stats_changed() -> void: pass

var _um

func _take(unlock_path: String, rarity: int) -> void:
	_um.apply_upgrade({"upgrade": load(unlock_path), "rarity": rarity})

func _copies(unlock_path: String) -> Array:
	return _um._owned_copies(load(unlock_path).target_class_name)

func _rarities(unlock_path: String) -> Array:
	var out: Array = []
	for w in _copies(unlock_path):
		out.append(w.rarity)
	out.sort()
	return out

func _offer(unlock_path: String, rarity: int) -> bool:
	return _um._weapon_offerable_at(load(unlock_path), rarity)

func _ready() -> void:
	CurrentRun.selected_character = null
	CurrentRun.selected_pack_paths = []
	CurrentRun.max_loadout_slots = 5

	var player := MockPlayer.new()
	add_child(player)
	_um = load("res://systems/upgrades/upgrade_manager.gd").new()
	add_child(_um)
	_um.register_player(player)

	# --- 1. Copies with free slots: two takes -> two Commons, distinct nodes ---
	_take(DAGGER, Upgrade.Rarity.COMMON)
	_take(DAGGER, Upgrade.Rarity.COMMON)
	var copies_ok: bool = _rarities(DAGGER) == [0, 0] and _um.get_used_slots() == 2
	var d0 = _copies(DAGGER)[0]
	var base_dmg: int = d0.projectile_stats.damage
	print("MERGE copies: rarities=%s slots=%d base_dmg=%d ok=%s" % [
		str(_rarities(DAGGER)), _um.get_used_slots(), base_dmg, str(copies_ok)])

	# Fill the loadout (3 mock artifacts -> 5/5).
	for i in range(3):
		var filler := MockItem.new()
		filler.name = "Filler%d" % i
		_um.player_artifacts.add_child(filler)
	var full_ok: bool = not _um.has_free_slot()

	# --- 4a. Offer filter at full: Common merges, Epic replaces, unowned weapon hidden ---
	var offer_ok: bool = _offer(DAGGER, Upgrade.Rarity.COMMON) \
		and _offer(DAGGER, Upgrade.Rarity.EPIC) \
		and not _offer(STAFF, Upgrade.Rarity.COMMON)
	var hint: String = _um.describe_weapon_take(load(DAGGER), Upgrade.Rarity.COMMON)
	var hint_ok: bool = "merge" in hint.to_lower()
	print("MERGE offer_at_full: dagger_common=%s dagger_epic=%s staff_hidden=%s hint='%s'" % [
		str(_offer(DAGGER, Upgrade.Rarity.COMMON)), str(_offer(DAGGER, Upgrade.Rarity.EPIC)),
		str(not _offer(STAFF, Upgrade.Rarity.COMMON)), hint])

	# --- 2. Merge: Common drafted at full -> one copy becomes Rare. No new node, same slots. ---
	_take(DAGGER, Upgrade.Rarity.COMMON)
	var curve: Array = d0.rarity_scaling
	var rare_dmg: int = int(round(base_dmg * curve[1] / curve[0]))
	var merged = _copies(DAGGER).filter(func(w): return w.rarity == Upgrade.Rarity.RARE)
	var merge_ok: bool = _rarities(DAGGER) == [0, 1] and _um.get_used_slots() == 5 \
		and merged.size() == 1 and merged[0].projectile_stats.damage == rare_dmg
	print("MERGE merge: rarities=%s dmg=%d expected=%d ok=%s" % [
		str(_rarities(DAGGER)), merged[0].projectile_stats.damage if merged.size() > 0 else -1,
		rare_dmg, str(merge_ok)])

	# --- 3. Replace: Epic drafted, no Epic owned -> the LOWEST copy (Common) becomes Epic in place ---
	_take(DAGGER, Upgrade.Rarity.EPIC)
	var epic_dmg: int = int(round(base_dmg * curve[2] / curve[0]))
	var epics = _copies(DAGGER).filter(func(w): return w.rarity == Upgrade.Rarity.EPIC)
	var replace_ok: bool = _rarities(DAGGER) == [1, 2] and epics.size() == 1 \
		and epics[0].projectile_stats.damage == epic_dmg and _um.get_used_slots() == 5
	print("MERGE replace: rarities=%s epic_dmg=%d expected=%d ok=%s" % [
		str(_rarities(DAGGER)), epics[0].projectile_stats.damage if epics.size() > 0 else -1,
		epic_dmg, str(replace_ok)])

	# --- 4b. Dead tiers: everything owned is Rare+, so a Common card is hidden. Mythic-on-Mythic too.
	var dead_low_ok: bool = not _offer(DAGGER, Upgrade.Rarity.COMMON)
	for w in _copies(DAGGER):
		w.set_rarity(Upgrade.Rarity.MYTHIC)
	var dead_top_ok: bool = not _offer(DAGGER, Upgrade.Rarity.MYTHIC) \
		and not _offer(DAGGER, Upgrade.Rarity.COMMON) \
		and not _um._weapon_offerable_any_tier(load(DAGGER))
	print("MERGE dead_cards: low_hidden=%s mythic_wall_hidden=%s" % [str(dead_low_ok), str(dead_top_ok)])

	# --- 5. set_rarity rescales NESTED damage too (the fireball lesson), and dev unlocks hold ---
	CurrentRun.max_loadout_slots = 99
	_take(STAFF, Upgrade.Rarity.COMMON)
	var staff = _copies(STAFF)[0]
	var boom_c: int = staff.projectile_stats.get("on_death_effect_stats").damage
	staff.set_rarity(Upgrade.Rarity.RARE)
	var boom_r: int = staff.projectile_stats.get("on_death_effect_stats").damage
	var nested_ok: bool = boom_r == int(round(boom_c * curve[1] / curve[0]))
	# Dev unlock-all must cover EVERYTHING the master lists know about.
	var chars: int = GameData.data["unlocked_character_paths"].size()
	var decks: int = GameData.data["unlocked_pack_paths"].size()
	var all_chars: int = load("res://systems/global/lists/master_character_list.tres").characters.size()
	var all_decks: int = load("res://systems/global/lists/master_pack_list.tres").decks.size()
	var unlock_ok: bool = chars >= all_chars and decks >= all_decks
	print("MERGE nested_set_rarity: boom %d->%d ok=%s | dev_unlocks: chars=%d decks=%d ok=%s" % [
		boom_c, boom_r, str(nested_ok), chars, decks, str(unlock_ok)])

	var pass_all: bool = copies_ok and full_ok and offer_ok and hint_ok and merge_ok \
		and replace_ok and dead_low_ok and dead_top_ok and nested_ok and unlock_ok
	print("MERGE RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
