## enemy_tags.gd
## Enum definitions for the enemy tag system.
## Tags are used for encounter weighting, weapon bonuses, and counter-spawning.
class_name EnemyTags
extends RefCounted

## Biome tags - where the enemy naturally appears
enum Biome {
	FRESHWATER,
	SALTWATER,
	DEEP,
	CAVE,
	REEF,
	TROPICAL,
	ARCTIC,
}

## Type tags - what kind of creature the enemy is (for weapon bonuses)
enum Type {
	FISH,
	JELLYFISH,
	CRUSTACEAN,
	SLUG,
	CEPHALOPOD,
	MAMMAL,
	PLANT,
}

## Size tags - affects stats at spawn time
enum Size {
	TINY,
	SMALL,
	MEDIUM,
	LARGE,
	BOSS,
}

## Behavior tags - combat role (for counter-spawning AI)
enum Behavior {
	SWARM,       # Direct chase (Enemy AI)
	RANGED,      # Shoots projectiles
	ARMORED,     # High armor
	FAST,        # High speed
	HORDE,       # Groups with allies before attacking (Horde AI)
	EVASIVE,     # Hard to hit
	REGENERATOR, # Constant healing -- the DoT counter (raw direct DPS beats it)
}

## Size multipliers applied at spawn time
## Keys: hp, damage, speed, armor_mult, xp, scale
const SIZE_MULTIPLIERS = {
	Size.TINY:   {"hp": 0.4,  "damage": 0.4,  "speed": 1.3, "armor_mult": 0.5, "xp": 0.5,  "scale": 0.6},
	Size.SMALL:  {"hp": 0.7,  "damage": 0.7,  "speed": 1.15, "armor_mult": 0.75, "xp": 0.75, "scale": 0.8},
	Size.MEDIUM: {"hp": 1.0,  "damage": 1.0,  "speed": 1.0, "armor_mult": 1.0, "xp": 1.0,  "scale": 1.0},
	Size.LARGE:  {"hp": 1.6,  "damage": 1.3,  "speed": 0.8, "armor_mult": 1.5, "xp": 1.5,  "scale": 1.3},
	Size.BOSS:   {"hp": 4.0,  "damage": 2.0,  "speed": 0.6, "armor_mult": 2.0, "xp": 3.0,  "scale": 1.8},
}

## Helper to get multipliers for a size
static func get_size_multipliers(size: Size) -> Dictionary:
	return SIZE_MULTIPLIERS.get(size, SIZE_MULTIPLIERS[Size.MEDIUM])
