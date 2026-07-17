## damage_utils.gd
## Utility class for damage calculations. Centralizes armor and damage logic.
class_name DamageUtils
extends RefCounted

## Calculates damage after applying armor reduction.
## Formula: effective_armor = armor * (1 - armor_pen), damage_taken = max(0, damage - effective_armor)
## @param damage: The raw damage amount before armor.
## @param armor: The target's armor value.
## @param armor_pen: Armor penetration as a float (0.0 to 1.0). 1.0 = full bypass.
## @returns: The final damage after armor reduction.
static func apply_armor(damage: float, armor: float, armor_pen: float = 0.0) -> int:
	var effective_armor = armor * (1.0 - clampf(armor_pen, 0.0, 1.0))
	return max(0, int(damage - effective_armor))

## Rolls for a critical hit and returns the final damage.
## @param base_damage: The damage before crit calculation.
## @param crit_rate: Chance to crit (0.0 to 1.0).
## @param crit_multiplier: Damage multiplier on crit (e.g., 1.5 = 150% damage).
## @returns: Dictionary with "damage" (int) and "is_crit" (bool).
static func roll_crit(base_damage: float, crit_rate: float, crit_multiplier: float) -> Dictionary:
	var is_crit = randf() < crit_rate
	var final_damage = base_damage
	if is_crit:
		final_damage = base_damage * crit_multiplier
	return {
		"damage": int(final_damage),
		"is_crit": is_crit
	}

## Combines crit roll and armor application in one call.
## @param base_damage: Raw damage before any modifiers.
## @param crit_rate: Critical hit chance.
## @param crit_multiplier: Critical hit damage multiplier.
## @param armor: Target's armor value.
## @param armor_pen: Armor penetration percentage.
## @returns: Dictionary with "damage" (int) and "is_crit" (bool).
static func calculate_final_damage(
	base_damage: float,
	crit_rate: float,
	crit_multiplier: float,
	armor: float,
	armor_pen: float = 0.0
) -> Dictionary:
	var crit_result = roll_crit(base_damage, crit_rate, crit_multiplier)
	var final_damage = apply_armor(crit_result["damage"], armor, armor_pen)
	return {
		"damage": final_damage,
		"is_crit": crit_result["is_crit"]
	}

# --- Player Stat Scaling Utilities ---
# Centralizes the stat scaling logic used by projectiles, weapons, and effects.

## Scales damage stats based on player bonuses.
## @param base_damage: The base damage value.
## @param base_crit_rate: The base critical hit rate (0.0 to 1.0).
## @param base_crit_damage: The base critical hit damage multiplier.
## @param user: The entity using the attack (must have get_stat method if player).
## @returns: Dictionary with "damage", "crit_rate", "crit_damage".
## Composed crit for ANY damage source (decision July 2026, research-backed -- see
## .claude/balance/README.md "Crit composition"):
##   chance = (source base + player FLAT crit) x player crit cards
##   damage = (1 + source base + player flat crit dmg) x player crit-damage cards
## The flat layer is UNIVERSAL: it reaches sources with no base crit at all (DoT ticks, sparks,
## zones) -- a crit character can make poison crit, which is the crit-status build enabler.
## Non-player sources keep their raw authored numbers (enemy crits unchanged).
static func compose_crit(base_crit_rate: float, base_crit_damage: float, user) -> Dictionary:
	if user != null and is_instance_valid(user) and user.is_in_group("player"):
		return {
			"rate": (base_crit_rate + user.get_stat("crit_flat")) * user.get_stat("critical_hit_rate"),
			"mult": (1.0 + base_crit_damage + user.get_stat("crit_damage_flat")) \
				* user.get_stat("critical_hit_damage"),
		}
	return {"rate": base_crit_rate, "mult": base_crit_damage}

static func scale_damage_stats(base_damage: float, base_crit_rate: float, base_crit_damage: float, user: Node) -> Dictionary:
	var damage = base_damage
	var crit: Dictionary = compose_crit(base_crit_rate, base_crit_damage, user)

	if user.is_in_group("player"):
		damage *= user.get_stat("damage_increase")

	return {
		"damage": damage,
		"crit_rate": crit.rate,
		"crit_damage": crit.mult
	}

## Scales projectile-specific stats based on player bonuses.
## @param base_speed: The base projectile speed.
## @param base_status_chance: The base status effect application chance.
## @param user: The entity using the attack.
## @returns: Dictionary with "speed", "status_chance".
static func scale_projectile_stats(base_speed: float, base_status_chance: float, user: Node) -> Dictionary:
	var speed = base_speed
	var status_chance = base_status_chance

	if user.is_in_group("player"):
		speed *= user.get_stat("projectile_speed")
		status_chance *= user.get_stat("status_chance_bonus")

	return {
		"speed": speed,
		"status_chance": status_chance
	}

## Convenience method to scale all common projectile stats at once.
## @param stats: A ProjectileStats resource.
## @param user: The entity using the attack.
## @returns: Dictionary with all scaled values.
static func scale_all_projectile_stats(stats, user: Node) -> Dictionary:
	var damage_scaled = scale_damage_stats(stats.damage, stats.critical_hit_rate, stats.critical_hit_damage, user)
	var proj_scaled = scale_projectile_stats(stats.speed, stats.status_chance, user)

	return {
		"damage": damage_scaled["damage"],
		"crit_rate": damage_scaled["crit_rate"],
		"crit_damage": damage_scaled["crit_damage"],
		"speed": proj_scaled["speed"],
		"status_chance": proj_scaled["status_chance"]
	}
