extends Node
## Headless check of the shared loadout slot cap. Run with --headless.
##   1. Weapons and artifacts share ONE slot pool.
##   2. Granted items (combo synergies, identity artifacts) don't spend a slot.
##   3. With a slot free, weapons/artifacts are offerable as normal.
##   4. At a full loadout they stop being offerable -- the exclusion the cap exists to create.
##   5. At a full loadout the pool is still NOT empty (stat cards remain) -- no level-up softlock.
##   6. A granted application (a combo) still lands at a full loadout, and stays off the books.

const FIRE := "res://systems/upgrades/packs/fire_pack.tres"

## A fire artifact the mock player never owns. It's the control: if it's offerable with a slot free
## and gone at a full loadout, then the CAP removed it -- not the "already owned" filter.
const CONTROL_CARD := "FlamingTouchArtifact"

## Stands in for a weapon/artifact node. Needs `is_transformed` because the inventory scan reads it.
class MockItem:
	extends Node2D
	var is_transformed: bool = false

## Minimal player: UpgradeManager.register_player only needs Equipment + Artifacts children, and the
## rarity roll reads get_stat("luck").
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

## Occupies a slot with a stand-in. Names are deliberately NOT real target_class_names, so the
## "already owned" filter can't remove anything and the cap has to do the work alone.
func _fill(parent: Node, item_name: String, granted: bool) -> void:
	var item := MockItem.new()
	item.name = item_name
	parent.add_child(item)
	if granted:
		_um.mark_granted(item)

## Does this set contain any weapon/artifact unlock?
## Asserted against the OFFERABLE set rather than a drawn hand -- a 3-card draw is random, so
## asserting on it would make this test flaky rather than meaningful.
func _has_unlock(upgrades: Array) -> bool:
	for u in upgrades:
		if u.type == Upgrade.UpgradeType.UNLOCK_WEAPON or u.type == Upgrade.UpgradeType.UNLOCK_ARTIFACT:
			return true
	return false

## Is one specific card offerable?
func _offers(upgrades: Array, target: String) -> bool:
	for u in upgrades:
		if u.target_class_name == target:
			return true
	return false

func _ready() -> void:
	# A run holding the fire deck, so the pool genuinely contains weapons and artifacts to offer.
	CurrentRun.selected_character = null
	CurrentRun.selected_pack_paths = [FIRE]
	CurrentRun.max_loadout_slots = 5

	var player := MockPlayer.new()
	add_child(player)
	# (Plain `var`, not `:=`: an untyped script instance, so its returns can't be inferred.)
	_um = load("res://systems/upgrades/upgrade_manager.gd").new()
	add_child(_um)
	_um.register_player(player)

	# --- 1 + 2. Slot accounting: weapons and artifacts share the pool; granted items are free ---
	_fill(_um.player_equipment, "FillerWeaponA", false)
	_fill(_um.player_artifacts, "FillerArtifactA", false)
	_fill(_um.player_artifacts, "FillerGrantedCombo", true)  # granted -> shouldn't count
	var shared_ok: bool = _um.get_used_slots() == 2 and _um.has_free_slot()

	# --- 3. Room to spare -> unlocks offerable, including the control ---
	var open_offerable = _um.get_offerable_upgrades()
	var offers_when_open: bool = _has_unlock(open_offerable)
	var control_open: bool = _offers(open_offerable, CONTROL_CARD)

	# --- 4 + 5. Fill to the cap ---
	_fill(_um.player_equipment, "FillerWeaponB", false)
	_fill(_um.player_equipment, "FillerWeaponC", false)
	_fill(_um.player_artifacts, "FillerArtifactB", false)
	var full_ok: bool = _um.get_used_slots() == 5 and not _um.has_free_slot()

	var full_offerable = _um.get_offerable_upgrades()
	var blocks_when_full: bool = not _has_unlock(full_offerable)
	# The control was never owned, so only the cap can explain its disappearance.
	var control_blocked: bool = not _offers(full_offerable, CONTROL_CARD)
	# If a full loadout emptied the pool, the level-up screen would show zero buttons and soft-lock.
	var full_choices = _um.get_upgrade_choices(3)
	var no_softlock: bool = full_choices.size() > 0

	print("SLOTCAP shared=%s full=%s offerable_open=%d(unlocks=%s) offerable_full=%d(unlocks=%s)" % [
		str(shared_ok), str(full_ok), open_offerable.size(), str(offers_when_open),
		full_offerable.size(), str(_has_unlock(full_offerable))])
	print("SLOTCAP control(%s): offerable_open=%s blocked_when_full=%s" % [
		CONTROL_CARD, str(control_open), str(control_blocked)])
	print("SLOTCAP no_softlock=%s (drawn at full loadout=%d) used=%d/%d" % [
		str(no_softlock), full_choices.size(), _um.get_used_slots(), CurrentRun.max_loadout_slots])

	# --- 6. A granted application still lands at a full loadout, and stays off the books ---
	var synergy := load("res://systems/upgrades/combos/synergy_spark_detonate.tres")
	_um.apply_upgrade({"upgrade": synergy, "rarity": Upgrade.Rarity.COMMON, "granted": true})
	var combo_node = _um.player_artifacts.get_node_or_null(synergy.target_class_name)
	var combo_ok: bool = combo_node != null and _um.is_granted(combo_node) and _um.get_used_slots() == 5
	print("SLOTCAP granted_combo_applied=%s still_used=%d" % [str(combo_ok), _um.get_used_slots()])

	var pass_all: bool = shared_ok and full_ok and offers_when_open and control_open \
		and blocks_when_full and control_blocked and no_softlock and combo_ok
	print("SLOTCAP RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
