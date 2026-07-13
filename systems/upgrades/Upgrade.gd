## Upgrade.gd
## A data-driven resource for player upgrades, with rarity and tiered values.
class_name Upgrade
extends Resource

# --- Enums ---
enum UpgradeType { UNLOCK_WEAPON, UNLOCK_ARTIFACT, UPGRADE, TRANSFORMATION }
enum Rarity { COMMON, RARE, EPIC, LEGENDARY, MYTHIC }
enum ModifierType {MULTIPLICATIVE, ADDITIVE, POWERS}

# --- Core Properties ---
@export var id: String
@export var display_name: String
@export_multiline var description: String
@export var type: UpgradeType
@export var target_class_name: String # For finding the item to upgrade
@export var scene_to_unlock: PackedScene # For UNLOCK types

# Rarity and Tiered Value System
@export var rarity: Rarity = Rarity.COMMON

# For UPGRADE types, this is the property on the target item to modify.
@export var key: String

# Whether to add or multiply the stat by the incoming value
@export var modifier_type: ModifierType = ModifierType.ADDITIVE

# This array holds the different values for this upgrade based on rarity.
# Index 0 = COMMON, 1 = RARE, 2 = EPIC, 3 = LEGENDARY
@export var rarity_values: Array[float]

# --- Effect Tags (for counter-spawning difficulty system) ---
# Tags that describe what this upgrade enables the player to do.
@export var effects: Array[WeaponTags.Effect] = []
