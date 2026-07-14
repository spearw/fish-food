## biome_definition.gd
## A Resource that defines a biome for the encounter system.
## Biomes softly PREFER their native enemies (weighted up) rather than hard-filtering -- off-biome
## enemies can still appear, which keeps variety and lets difficulty countering reach across biomes.
class_name BiomeDefinition
extends Resource

## Display name shown in UI (e.g., "Freshwater Lake")
@export var display_name: String = ""

## The biome tag this definition represents.
@export var biome_tag: EnemyTags.Biome = EnemyTags.Biome.FRESHWATER

## How much MORE likely a native enemy (one carrying this biome's tag) is to be chosen vs an
## off-biome enemy. 1.0 = no preference; higher = a stronger pull toward native. Off-biome enemies
## still appear (soft preference). Tune per biome.
@export var native_preference: float = 4.0

## Tag weights for enemy selection within this biome.
## If null, uses unweighted random selection among biome-matching enemies.
@export var encounter_config: EncounterConfig

## Optional description for UI tooltips
@export_multiline var description: String = ""

## Background tint color for this biome (multiplied with base background)
@export var background_color: Color = Color(0.14, 0.14, 0.14, 1.0)

## Spawn-weight multiplier for an enemy in this biome: native enemies (carrying this biome's tag) get
## `native_preference`, everything else 1.0. This is the soft preference the encounter director applies.
func get_native_multiplier(enemy_stats: EnemyStats) -> float:
	return native_preference if biome_tag in enemy_stats.biome_tags else 1.0

## True if the enemy is native to this biome. No longer the spawn gate (see get_native_multiplier);
## kept for any caller that wants a hard native check.
func can_enemy_spawn(enemy_stats: EnemyStats) -> bool:
	return biome_tag in enemy_stats.biome_tags
