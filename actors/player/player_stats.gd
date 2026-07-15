## player_stats.gd
## A Resource to hold the player's base statistics. Inherits from EntityStats.
class_name PlayerStats
extends EntityStats

# --- Display Info ---
@export_multiline var character_description: String

# --- Meta Progression ---
## Cost in souls to unlock this character in the meta shop. 0 = already unlocked.
@export var unlock_cost: int = 100

# --- Base Gameplay Stats ---
@export var pickup_radius: float = 150.0
@export var luck: float = 1.0
@export var firerate_modifier: float = 1.0
@export var projectile_count_multiplier: float = 1.0
@export var critical_chance: float = 0.0
@export var critical_damage: float = 0.0

# --- Identity Loadout (see docs/deck_and_synergy_design.md section 3) ---
## Applied GRANTED at run start (slot-exempt): the character's identity ARTIFACT lives here -- a verb
## that changes a rule, not a stat line. Characters are deliberately NOT linked to decks or weapons:
## decks are chosen freely, and the starting weapon comes from upgrade 0's cross-deck roll.
@export var starting_upgrades: Array[Upgrade]

## Cards only this character can draw, folded into the run's pool (credited to no deck). Empty for
## everyone right now -- kept as the hook for identity-support cards later.
@export var exclusive_upgrades: Array[Upgrade]
