## weapon_tags.gd
## Enum definitions for the weapon tag system.
## Themes define what a weapon IS (damage type, synergies).
## Effects define what a weapon DOES (mechanical behaviors).
## Also contains the counter matrix for difficulty-based spawning.
class_name WeaponTags
extends RefCounted

## DamageType tags - the weapon's elemental/thematic identity.
## Affects: damage type bonuses, artifact synergies, visuals.
enum DamageType {
	FIRE,       # Fire-themed, typically paired with DOT
	ICE,        # Ice-themed, typically paired with SLOW
	LIGHTNING,  # Lightning-themed, typically paired with CHAIN
	SALT,       # Salt/desiccation, bonus vs freshwater enemies
	NATURE,     # Nature/poison, typically paired with DOT
	ARCANE,     # Pure magic damage
	PHYSICAL,   # Non-elemental physical damage
}

## Effect tags - the weapon's mechanical behaviors.
## Affects: how projectiles interact with enemies, counter-spawning weights.
enum Effect {
	# Damage patterns
	DOT,        # Damage over time (burn, poison, bleed)
	SLOW,       # Reduces enemy movement speed
	CHAIN,      # Bounces to nearby enemies
	PIERCE,     # Passes through enemies
	AOE,        # Area of effect damage
	KNOCKBACK,  # Pushes enemies away

	# Projectile behaviors
	HOMING,     # Tracks targets
	BURST,      # Multiple projectiles per shot
	EXPLOSIVE,  # Explodes on impact

	# Special effects
	LIFESTEAL,  # Heals user on hit
	ARMOR_PEN,  # Ignores armor
	CRIT_BOOST, # Increased crit chance/damage
	SPARK,      # Spawns spark projectiles on hit (lightning weapons)

	# Range/targeting
	MELEE,      # Close range attacks
	LONG_RANGE, # Long distance attacks
	HIGH_FIRE_RATE, # Many small hits
	SINGLE_TARGET,  # High damage to single target
}

## Counter matrix: Effect → { EnemyTags.Behavior → effectiveness }
## Values > 1.0 = player is STRONG against this enemy behavior
## Values < 1.0 = player is WEAK against this enemy behavior
## Used by difficulty system to weight enemy spawns.
const COUNTER_MATRIX = {
	Effect.AOE: {
		0: 1.5,   # SWARM - AOE shreds groups
		4: 1.4,   # HORDE - good vs grouped enemies
		2: 0.7,   # ARMORED - damage spread thin
	},
	Effect.PIERCE: {
		0: 1.4,   # SWARM - pierce hits multiple
		4: 1.3,   # HORDE - pierce through lines
	},
	Effect.HOMING: {
		5: 1.8,   # EVASIVE - can't dodge homing
		3: 1.5,   # FAST - tracking catches up
	},
	Effect.SLOW: {
		3: 1.6,   # FAST - slowing negates speed
		5: 1.3,   # EVASIVE - easier to hit when slowed
	},
	Effect.ARMOR_PEN: {
		2: 1.8,   # ARMORED - bypasses armor
	},
	Effect.SINGLE_TARGET: {
		2: 1.4,   # ARMORED - burst through defenses
		0: 0.5,   # SWARM - overwhelmed by numbers
		4: 0.6,   # HORDE - can't handle groups
	},
	Effect.HIGH_FIRE_RATE: {
		0: 1.3,   # SWARM - spray and pray works
		2: 0.7,   # ARMORED - many weak hits blocked
	},
	Effect.MELEE: {
		1: 0.5,   # RANGED - kited by shooters
		0: 1.2,   # SWARM - cleave through groups
	},
	Effect.LONG_RANGE: {
		1: 1.4,   # RANGED - can outrange them
	},
	Effect.EXPLOSIVE: {
		0: 1.5,   # SWARM - explosions hit groups
		4: 1.4,   # HORDE - area denial
	},
	Effect.CHAIN: {
		0: 1.6,   # SWARM - chains between targets
		4: 1.5,   # HORDE - chains through groups
	},
	Effect.DOT: {
		2: 0.6,   # ARMORED - ticks may be reduced by armor
		3: 1.2,   # FAST - DOT keeps damaging
	},
	Effect.KNOCKBACK: {
		0: 1.2,   # SWARM - crowd control
		3: 0.8,   # FAST - they close distance quickly
	},
}

## Gets the effectiveness of a player effect tag against an enemy behavior.
## Returns > 1.0 if strong, < 1.0 if weak, 1.0 if neutral.
static func get_counter_effectiveness(effect: Effect, behavior: int) -> float:
	if effect in COUNTER_MATRIX:
		return COUNTER_MATRIX[effect].get(behavior, 1.0)
	return 1.0

## Calculates total effectiveness of a set of effect tags against an enemy behavior.
## Combines all relevant multipliers.
static func get_combined_effectiveness(effects: Array, behavior: int) -> float:
	var total = 1.0
	for effect in effects:
		total *= get_counter_effectiveness(effect, behavior)
	return total
