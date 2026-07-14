## combo_manager.gd  (autoload "ComboManager")
## Holds the cross-deck combo definitions and decides which synergies the player may currently pick.
## Combos unlock at a trigger event (see COMBO_UNLOCK_LEVEL / the level-up UI), gated by how many cards
## the player has drafted from each deck of a pair (CurrentRun.deck_draft_counts), one combo per run.
extends Node

const COMBO_LIST_PATH := "res://systems/combos/master_combo_list.tres"
## The level at which combos first become offerable (placeholder; later a mini-boss kill).
const COMBO_UNLOCK_LEVEL := 20

var _combos: Array = []

func _ready() -> void:
	var list = load(COMBO_LIST_PATH)
	if list and "combos" in list:
		_combos = list.combos
	else:
		Logs.add_message("ComboManager: no combo list at %s (combos disabled)." % COMBO_LIST_PATH)

## The synergy Upgrades the player may currently choose: from every combo whose power gate is met, if
## the player has not already taken a combo this run. Empty if none are available.
func get_eligible_synergies() -> Array:
	if CurrentRun.combo_taken:
		return []
	var result: Array = []
	for combo in _combos:
		if combo != null and is_gate_met(combo):
			result.append_array(combo.synergies)
	return result

## True if the player has invested enough in BOTH decks of the pair (>= power_gate cards each).
func is_gate_met(combo) -> bool:
	var counts: Dictionary = CurrentRun.deck_draft_counts
	return counts.get(combo.deck_a_id, 0) >= combo.power_gate \
		and counts.get(combo.deck_b_id, 0) >= combo.power_gate

## Whether a combo choice should be offered right now (used by the level-up trigger).
func should_offer_combo(level: int) -> bool:
	return level >= COMBO_UNLOCK_LEVEL and not CurrentRun.combo_taken and not get_eligible_synergies().is_empty()
