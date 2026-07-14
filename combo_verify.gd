extends Node
## Headless check of the combo eligibility framework: the power gate (BOTH decks invested), the
## one-per-run flag, and the level-unlock trigger. Run with --headless.

func _ready() -> void:
	var combo := DeckCombo.new()
	combo.combo_name = "Fire + Lightning"
	combo.deck_a_id = "fire"
	combo.deck_b_id = "lightning"
	combo.power_gate = 4
	combo.synergies = [Upgrade.new(), Upgrade.new()]  # 2 dummy synergy options
	ComboManager._combos = [combo]

	# 1. No investment -> gate not met -> nothing offered.
	CurrentRun.deck_draft_counts = {}
	CurrentRun.combo_taken = false
	var none_ok: bool = ComboManager.get_eligible_synergies().is_empty() and not ComboManager.is_gate_met(combo)

	# 2. Only ONE deck invested -> still not met (need both).
	CurrentRun.deck_draft_counts = {"fire": 5}
	var one_side_ok: bool = not ComboManager.is_gate_met(combo)

	# 3. Both decks invested >= gate -> met -> both synergies offered.
	CurrentRun.deck_draft_counts = {"fire": 4, "lightning": 6}
	var gate_ok: bool = ComboManager.is_gate_met(combo)
	var offered: Array = ComboManager.get_eligible_synergies()
	var offered_ok: bool = offered.size() == 2

	# 4. Level trigger: below unlock level -> no; at/above (with gate met) -> yes.
	var trigger_ok: bool = not ComboManager.should_offer_combo(ComboManager.COMBO_UNLOCK_LEVEL - 1) \
		and ComboManager.should_offer_combo(ComboManager.COMBO_UNLOCK_LEVEL)

	# 5. One per run: after taking a combo, nothing is offered.
	CurrentRun.combo_taken = true
	var one_per_run_ok: bool = ComboManager.get_eligible_synergies().is_empty() \
		and not ComboManager.should_offer_combo(ComboManager.COMBO_UNLOCK_LEVEL)

	var ok: bool = none_ok and one_side_ok and gate_ok and offered_ok and trigger_ok and one_per_run_ok
	print("COMBOVERIFY none=%s one_side=%s gate=%s offered=%d trigger=%s one_per_run=%s RESULT=%s" % [
		str(none_ok), str(one_side_ok), str(gate_ok), offered.size(), str(trigger_ok), str(one_per_run_ok),
		"PASS" if ok else "FAIL"])
	get_tree().quit()
