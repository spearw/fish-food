extends Node
## Headless check of card manipulation (reroll / banish) and the per-run reset. Run with --headless.
##   1. Banish removes a card from every subsequent draw this run, at every tier.
##   2. Charges are finite: 2 banishes, 2 rerolls, then refusals.
##   3. redraw_choice never returns a card already on screen (or returns {} on a thin pool).
##   4. reset_run_state restores charges and clears banishes -- and clears the run flags whose
##      staleness was a live bug (starting_weapon_chosen / combo_taken / deck_draft_counts).

const FIRE := "res://systems/upgrades/packs/fire_pack.tres"
const FLAMETHROWER := "res://systems/upgrades/weapons/fire/flamethrower/flamethrower_unlock.tres"

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

func _ready() -> void:
	CurrentRun.selected_character = null
	CurrentRun.selected_pack_paths = [FIRE] as Array[String]
	CurrentRun.max_loadout_slots = 99
	CurrentRun.reset_run_state()

	var player := MockPlayer.new()
	add_child(player)
	var um = load("res://systems/upgrades/upgrade_manager.gd").new()
	add_child(um)
	um.register_player(player)

	# --- 1 + 2. Banish: gone from the offerable set and from draws; charges run out ---
	var flamethrower = load(FLAMETHROWER)
	var before: bool = flamethrower in um.get_offerable_upgrades()
	var b1: bool = um.try_banish(flamethrower)
	var after: bool = flamethrower in um.get_offerable_upgrades()
	var drawn_banished := false
	for i in range(12):
		for choice in um.get_upgrade_choices(3):
			if choice["upgrade"] == flamethrower:
				drawn_banished = true
	var b2: bool = um.try_banish(load("res://systems/upgrades/artifacts/fire/pyrophobia_unlock.tres"))
	var b3: bool = um.try_banish(load(FIRE).upgrades[2])  # out of charges
	var banish_ok: bool = before and b1 and not after and not drawn_banished and b2 and not b3 \
		and CurrentRun.banishes_remaining == 0
	print("CARDMANIP banish: before=%s gone_after=%s never_drawn=%s charges=%s" % [
		str(before), str(not after), str(not drawn_banished), str(banish_ok)])

	# --- 2b. Reroll charges ---
	var r1: bool = um.try_spend_reroll()
	var r2: bool = um.try_spend_reroll()
	var r3: bool = um.try_spend_reroll()
	var reroll_ok: bool = r1 and r2 and not r3 and CurrentRun.rerolls_remaining == 0
	print("CARDMANIP reroll charges: %s" % str(reroll_ok))

	# --- 3. redraw_choice avoids what's on screen ---
	var shown: Array[Dictionary] = um.get_upgrade_choices(3)
	var exclude: Array = shown.map(func(c): return c["upgrade"])
	var redraw_ok := true
	for i in range(6):
		var repl: Dictionary = um.redraw_choice(exclude)
		if not repl.is_empty() and repl["upgrade"] in exclude:
			redraw_ok = false
	print("CARDMANIP redraw_avoids_shown=%s" % str(redraw_ok))

	# --- 4. reset_run_state: the per-run reset (the run-2 staleness bug) ---
	CurrentRun.starting_weapon_chosen = true
	CurrentRun.combo_taken = true
	CurrentRun.deck_draft_counts = {"fire": 7}
	CurrentRun.reset_run_state()
	var reset_ok: bool = CurrentRun.rerolls_remaining == CurrentRun.REROLLS_PER_RUN \
		and CurrentRun.banishes_remaining == CurrentRun.BANISHES_PER_RUN \
		and CurrentRun.banished_upgrades.is_empty() \
		and not CurrentRun.starting_weapon_chosen and not CurrentRun.combo_taken \
		and CurrentRun.deck_draft_counts.is_empty()
	var unbanished: bool = flamethrower in um.get_offerable_upgrades()
	print("CARDMANIP reset: state_cleared=%s banished_restored=%s" % [str(reset_ok), str(unbanished)])

	var pass_all: bool = banish_ok and reroll_ok and redraw_ok and reset_ok and unbanished
	print("CARDMANIP RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
