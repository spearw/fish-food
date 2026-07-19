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
		# Sweep-measured (Jul 2026, re-confirmed on the 23-weapon field: n=5 pierce weapons ALL
		# zeroed into armor). Causal, not incidental -- pierce multiplies TARGETS, not per-hit
		# damage, and flat armor eats small per-hit numbers. Tightened 0.7 -> 0.5 on user review.
		2: 0.5,   # ARMORED - many pierced targets, but each hit is small and armor eats it
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
		# AUTHORED, not measured: hit volume is regeneration's natural predator -- the inverse of
		# this row's armor entry. Daggers finally get their showcase matchup.
		6: 1.4,   # REGENERATOR - sustained hits outpace the healing
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
		# Sweep-measured (Jul 2026): chain lightning zeroed into armor for the same reason the
		# spark family does -- the chain IS small spark hits. Aligned with SPARK's entry.
		2: 0.5,   # ARMORED - armor eats the chain's tiny hits
		# AUTHORED, not measured: aligned with SPARK's regen entry, same archetype.
		6: 1.3,   # REGENERATOR - constant small hits outpace the healing
	},
	# DoT's real matchups (measured + structural -- see .claude/balance/workflow.md, armor section):
	# ticks carry 100% armor pen, so armor does NOTHING to a DoT build (measured: flamethrower flat
	# across 15 and 37.5 armor). Its structural weakness is the RAMP -- damage-over-TIME loses to
	# whatever makes the time unavailable: fast closers reach you before the ticks finish, and
	# standoff shooters kite its short-range delivery (cones, lobbed clouds). One graze applies the
	# full burn, so evasive enemies are WEAK against it. In HARD mode (low effectiveness = weighted
	# up) this sends fast+ranged pressure at a toxin/fire build instead of the armored enemies it
	# laughs at -- the old row did the opposite.
	Effect.DOT: {
		# Sweep-measured (Jul 2026): the DoT fleet holds 6.7-17.6x the field-typical output into
		# armor (n=5). Causal -- ticks carry 100% armor pen -- so this sits at the squash ceiling.
		2: 1.8,   # ARMORED - ticks ignore armor entirely (100% pen, by design)
		3: 0.7,   # FAST - closers outrace the ramp
		5: 1.3,   # EVASIVE - one graze applies the full effect
		1: 0.8,   # RANGED - standoff shooters kite the short-range delivery
		# AUTHORED, not measured (the bench has no regen column yet): regeneration is DoT's hard
		# counter by design -- constant healing races the ticks the way armor eats small hits.
		# The deliberate mirror of DOT-vs-ARMORED. Structural, so it sits at the squash floor.
		6: 0.5,   # REGENERATOR - healing races the ticks
	},
	Effect.KNOCKBACK: {
		0: 1.2,   # SWARM - crowd control
		3: 0.8,   # FAST - they close distance quickly
	},
	Effect.SPARK: {
		# Sweep-measured (Jul 2026): the whole spark family (n=5 -- chain lightning, tesla, spark
		# dagger, lightning sword, storm staff) held ~0.09x the field-typical output into armor.
		# Causal -- sparks are the many-tiny-hits archetype (3-6 damage per hit) and flat armor eats
		# small hits wholesale. Softened above the raw measurement so Abyssal pressures lightning
		# builds without deleting them; their real out is tiers (merge depth) or drafting pen/DoT.
		2: 0.5,   # ARMORED - armor eats tiny spark hits
		# AUTHORED, not measured: what armor eats wholesale, regeneration cannot keep up with --
		# every tiny hit lands in full and the stream never pauses.
		6: 1.4,   # REGENERATOR - the hit stream never lets the healing catch up
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
