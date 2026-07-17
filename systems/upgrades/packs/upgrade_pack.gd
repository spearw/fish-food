## upgrade_pack.gd  (class: Deck)
## A Resource representing a DECK: a themed, synergistic set of Upgrade cards a player brings into a
## run. (Formerly "UpgradePack" -- the file keeps its legacy name; the class and data are "Deck".)
class_name Deck
extends Resource

## Stable identifier for this deck (e.g. "fire", "lightning"). Used to reference the deck for
## cross-deck combo/synergy pairings. Should be unique and set on every deck.
@export var id: String = ""

@export var deck_name: String
@export_multiline var deck_description: String
## An icon for the deck to be displayed in the UI.
@export var deck_icon: Texture2D
## Cost in souls to unlock this deck in the meta shop. 0 = already unlocked.
@export var unlock_cost: int = 100

# The list of all Upgrade resources contained within this deck.
@export var upgrades: Array[Upgrade]

## Counts this deck's cards by category, derived from each Upgrade's type. This is the deck "structure"
## in COUNTED form -- no sizes are enforced (decks may differ); it's for design visibility / warnings.
## NOTE: "upgrades" here lumps stat cards and deck-mechanic cards together (both are UpgradeType.UPGRADE);
## split them later if mechanic cards get their own type/tag.
## The deck's contents by NAME, for the select screen -- derived from the card data itself so it
## can never go stale. Post core-deck dissolution (design doc section 1b) "which stats does this
## deck carry" is a load-bearing read: generic stat cards are recognized by the "player_" id
## convention every shared stat card follows; other UPGRADE-type cards are deck-mechanic cards.
func get_manifest() -> Dictionary:
	var m := {"weapons": [], "stats": [], "mechanics": [], "artifacts": [], "evolutions": 0}
	for u in upgrades:
		if u == null:
			continue
		match u.type:
			Upgrade.UpgradeType.UNLOCK_WEAPON:
				m.weapons.append(u.display_name)
			Upgrade.UpgradeType.TRANSFORMATION:
				m.evolutions += 1
			Upgrade.UpgradeType.UNLOCK_ARTIFACT:
				m.artifacts.append(u.display_name)
			Upgrade.UpgradeType.UPGRADE:
				if u.id.begins_with("player_"):
					m.stats.append(u.display_name)
				else:
					m.mechanics.append(u.display_name)
	return m

func get_composition() -> Dictionary:
	var counts := {"weapons": 0, "evolutions": 0, "artifacts": 0, "upgrades": 0}
	for u in upgrades:
		if u == null:
			continue
		match u.type:
			Upgrade.UpgradeType.UNLOCK_WEAPON:
				counts.weapons += 1
			Upgrade.UpgradeType.TRANSFORMATION:
				counts.evolutions += 1
			Upgrade.UpgradeType.UNLOCK_ARTIFACT:
				counts.artifacts += 1
			Upgrade.UpgradeType.UPGRADE:
				counts.upgrades += 1
	return counts
