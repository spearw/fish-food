## artifact_base.gd
## Base class for all artifacts. Provides a standard interface for stat modifiers.
## Subclasses can override specific methods to provide their effects.
class_name ArtifactBase
extends Node

## The player/entity that owns this artifact. Set by UpgradeManager when equipped.
var user: Node = null

## Effect tags for counter-spawning difficulty system.
## Override in subclass or set in inspector to define what this artifact enables.
@export var effects: Array[WeaponTags.Effect] = []

## Called when the artifact is first equipped.
## Override in subclasses for setup logic (connecting signals, etc.).
func on_equipped() -> void:
	pass

## Called when the artifact is removed.
## Override in subclasses for cleanup logic.
func on_unequipped() -> void:
	pass

# --- Stat Modifier Interface ---
# Player.get_stat() will query all artifacts for these modifiers.
# Return 1.0 for "no change" (multiplicative), 0.0 for "no change" (additive).

## Returns a multiplicative modifier for move speed. Default: 1.0 (no change).
func get_speed_modifier() -> float:
	return 1.0

## Returns a multiplicative modifier for damage. Default: 1.0 (no change).
func get_damage_modifier() -> float:
	return 1.0

## Returns a multiplicative modifier for player size/scale. Default: 1.0 (no change).
func get_size_modifier() -> float:
	return 1.0

## Returns a multiplicative modifier for fire rate. Default: 1.0 (no change).
func get_firerate_modifier() -> float:
	return 1.0

## Returns a multiplicative modifier for critical hit chance. Default: 1.0 (no change).
func get_crit_chance_modifier() -> float:
	return 1.0

## Returns a multiplicative modifier for critical hit damage. Default: 1.0 (no change).
func get_crit_damage_modifier() -> float:
	return 1.0

## Returns an additive bonus to projectile count. Default: 0 (no bonus).
func get_projectile_bonus() -> int:
	return 0

## Returns a multiplicative modifier for armor. Default: 1.0 (no change).
func get_armor_modifier() -> float:
	return 1.0

## Returns a multiplicative modifier for max health. Default: 1.0 (no change).
func get_max_health_modifier() -> float:
	return 1.0

## Returns a multiplicative modifier for pickup radius. Default: 1.0 (no change).
func get_pickup_radius_modifier() -> float:
	return 1.0

## Returns a multiplicative modifier for luck. Default: 1.0 (no change).
func get_luck_modifier() -> float:
	return 1.0

# --- Generic Stat Query ---
# Alternative approach: query by stat key name.

## Generic stat modifier query. Override for custom stats not covered above.
## @param stat_key: The name of the stat (e.g., "move_speed", "damage_increase").
## @returns: Multiplicative modifier (1.0 = no change).
func get_stat_modifier(stat_key: String) -> float:
	match stat_key:
		"move_speed":
			return get_speed_modifier()
		"damage_increase":
			return get_damage_modifier()
		"size", "area_size":
			return get_size_modifier()
		"firerate":
			return get_firerate_modifier()
		"critical_hit_rate":
			return get_crit_chance_modifier()
		"critical_hit_damage":
			return get_crit_damage_modifier()
		"armor":
			return get_armor_modifier()
		"max_health":
			return get_max_health_modifier()
		"pickup_radius":
			return get_pickup_radius_modifier()
		"luck":
			return get_luck_modifier()
		_:
			return 1.0
