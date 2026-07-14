## deck_combo.gd
## A cross-deck COMBO: pairing two Decks unlocks one of several powerful synergy effects. Authored per
## deck-pair (see docs/deck_and_synergy_design.md). The player is offered a combo's synergies once
## they've invested enough in BOTH decks (power_gate) and reached the unlock event; they pick ONE, and
## may take only one combo per run.
class_name DeckCombo
extends Resource

## Display name, e.g. "Fire + Lightning".
@export var combo_name: String
## The two decks this combo pairs, by Deck.id (e.g. "fire", "lightning"). Order does not matter.
@export var deck_a_id: String
@export var deck_b_id: String
## Minimum cards drafted from EACH deck of the pair before this combo's synergies become available.
@export var power_gate: int = 4
## The synergy options (2-4). Each is an UNLOCK_ARTIFACT Upgrade that equips a combo artifact. The
## player picks ONE. They should play differently (e.g. sustain / generation / burst).
@export var synergies: Array[Upgrade]

## True if this combo is for the given (unordered) pair of deck ids.
func involves(id_a: String, id_b: String) -> bool:
	return (deck_a_id == id_a and deck_b_id == id_b) or (deck_a_id == id_b and deck_b_id == id_a)
