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

# --- Starting Loadout ---
# Defines the character's unique starting weapon(s) and artifact(s).
@export var starting_upgrades: Array[Upgrade]

# --- Deck Identity (see docs/deck_and_synergy_design.md section 2) ---
## The character's linked PRIMARY deck -- their identity. Granted automatically at run start; the
## player only chooses the secondary. Null = an "open" character, who picks both themed decks.
@export var primary_deck: Deck

## Cards only this character can draw -- their exclusive weapon's evolutions. They live here instead
## of in a deck, which is exactly what makes the weapon exclusive: no deck can offer them to anyone
## else. Folded into the run's pool and credited to primary_deck's draft count.
@export var exclusive_upgrades: Array[Upgrade]
