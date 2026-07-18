## combo_manager.gd  (autoload "ComboManager")
## Holds the cross-deck combo definitions and decides which synergies the player may currently pick.
## Combos unlock at a trigger event (see COMBO_UNLOCK_LEVEL / the level-up UI), gated by how many cards
## the player has drafted from each deck of a pair (CurrentRun.deck_draft_counts), one combo per run.
extends Node

const COMBO_LIST_PATH := "res://systems/combos/master_combo_list.tres"
## The legacy level trigger. Lives on as the FALLBACK: it applies when no herald is scheduled
## (benches, test worlds) or when the herald left unkilled -- so a build that can't kill the boss
## is delayed, never locked out (reward-not-requirement).
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

## Whether a combo choice should be offered right now. Called from the level-up trigger AND from the
## herald-kill event. The herald kill IS the trigger when a herald is scheduled:
##   killed  -> offer immediately (any level; if the draft gate isn't met yet, the level-up checks
##              keep asking, so the offer lands at the first level-up where it is -- deferral for free)
##   alive/pending -> hold (the fight is the gate)
##   left unkilled -> fall back to the level trigger
##   never scheduled -> the level trigger, unchanged (benches and test worlds)
func should_offer_combo(level: int) -> bool:
	if CurrentRun.combo_taken or get_eligible_synergies().is_empty():
		return false
	if CurrentRun.herald_killed_at >= 0.0:
		return true
	if CurrentRun.herald_scheduled and not CurrentRun.herald_left:
		return false
	return level >= COMBO_UNLOCK_LEVEL
