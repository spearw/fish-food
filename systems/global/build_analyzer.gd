## build_analyzer.gd
## Analyzes a player's build (weapons, upgrades, artifacts) to determine
## effectiveness against different enemy types for difficulty-based spawning.
class_name BuildAnalyzer
extends RefCounted

## Cached effect tag totals. Key: WeaponTags.Effect, Value: count
var effect_totals: Dictionary = {}

## Cached metrics for scaling counter effectiveness
var total_dps: float = 0.0
var total_area_coverage: float = 0.0
var has_homing: bool = false
var average_range: float = 0.0

## Analyzes the player's current build and caches the results.
## Call this when the player gains a new weapon, upgrade, or artifact.
static func analyze_player(player: Node) -> BuildAnalyzer:
	var analyzer = BuildAnalyzer.new()
	analyzer._gather_effect_tags(player)
	analyzer._calculate_metrics(player)
	return analyzer

## Gathers all effect tags from the player's weapons, upgrades, and artifacts.
func _gather_effect_tags(player: Node) -> void:
	effect_totals.clear()

	# Gather from weapons
	if player.has_method("get_weapons"):
		for weapon in player.get_weapons():
			if "effects" in weapon:
				for effect in weapon.effects:
					effect_totals[effect] = effect_totals.get(effect, 0) + 1

	# Gather from artifacts
	if player.has_method("get_artifacts"):
		for artifact in player.get_artifacts():
			if "effects" in artifact:
				for effect in artifact.effects:
					effect_totals[effect] = effect_totals.get(effect, 0) + 1

	# Gather from active upgrades (via UpgradeManager)
	var upgrade_manager = player.get_node_or_null("UpgradeManager")
	if upgrade_manager and "applied_upgrades" in upgrade_manager:
		for upgrade in upgrade_manager.applied_upgrades:
			if upgrade is Upgrade and not upgrade.effects.is_empty():
				for effect in upgrade.effects:
					effect_totals[effect] = effect_totals.get(effect, 0) + 1

## Calculates actual gameplay metrics for scaling counter effectiveness.
func _calculate_metrics(player: Node) -> void:
	total_dps = 0.0
	total_area_coverage = 0.0
	has_homing = false
	average_range = 0.0

	var weapon_count = 0

	if player.has_method("get_weapons"):
		for weapon in player.get_weapons():
			weapon_count += 1

			# Calculate DPS from weapon stats
			if "projectile_stats" in weapon and weapon.projectile_stats:
				var stats = weapon.projectile_stats
				var damage = stats.damage if "damage" in stats else 10
				var fire_rate = weapon.base_fire_rate if "base_fire_rate" in weapon else 1.0
				var proj_count = weapon.base_projectile_count if "base_projectile_count" in weapon else 1

				# DPS = damage * projectiles / fire_rate
				if fire_rate > 0:
					total_dps += (damage * proj_count) / fire_rate

				# Area coverage from AOE
				if "explosion_radius" in stats and stats.explosion_radius > 0:
					total_area_coverage += stats.explosion_radius * proj_count

				# Check for homing
				if "homing_strength" in stats and stats.homing_strength > 0:
					has_homing = true

				# Track range (if available)
				if "lifetime" in stats and "speed" in stats:
					average_range += stats.lifetime * stats.speed

	if weapon_count > 0:
		average_range /= weapon_count

## Gets the player's effectiveness against a specific enemy behavior.
## Returns a multiplier: >1.0 = strong, <1.0 = weak, 1.0 = neutral.
func get_effectiveness_vs_behavior(behavior: int) -> float:
	var base_effectiveness = 1.0

	# Combine all effect tag counters
	for effect in effect_totals.keys():
		var count = effect_totals[effect]
		var counter_value = WeaponTags.get_counter_effectiveness(effect, behavior)

		# Scale by count but with diminishing returns
		# First instance = full value, each additional = 50% of remaining
		if counter_value != 1.0:
			var scaled_value = 1.0 + (counter_value - 1.0) * _diminishing_scale(count)
			base_effectiveness *= scaled_value

	# Apply metric scaling for hybrid accuracy
	base_effectiveness = _apply_metric_scaling(base_effectiveness, behavior)

	return base_effectiveness

## Diminishing returns formula: first = 100%, second = 50%, third = 25%, etc.
func _diminishing_scale(count: int) -> float:
	if count <= 0:
		return 0.0
	# Sum of geometric series: 1 + 0.5 + 0.25 + ... = 2 * (1 - 0.5^n)
	return 2.0 * (1.0 - pow(0.5, count))

## Applies actual metric scaling to make effectiveness more accurate.
func _apply_metric_scaling(base: float, behavior: int) -> float:
	var scaled = base

	match behavior:
		0:  # SWARM - area coverage matters
			if total_area_coverage > 100:
				scaled *= 1.0 + (total_area_coverage - 100) / 500.0
		2:  # ARMORED - raw DPS matters
			if total_dps > 50:
				scaled *= 1.0 + (total_dps - 50) / 200.0
		3, 5:  # FAST, EVASIVE - homing is binary advantage
			if has_homing:
				scaled *= 1.2

	return clamp(scaled, 0.2, 3.0)

## Returns a dictionary of effectiveness vs all enemy behaviors.
## Useful for debugging or displaying build analysis.
func get_full_effectiveness_profile() -> Dictionary:
	var profile = {}
	for behavior in range(6):  # SWARM, RANGED, ARMORED, FAST, HORDE, EVASIVE
		profile[behavior] = get_effectiveness_vs_behavior(behavior)
	return profile

## Returns the behavior the player is MOST effective against.
func get_strongest_against() -> int:
	var best_behavior = 0
	var best_value = 0.0
	for behavior in range(6):
		var eff = get_effectiveness_vs_behavior(behavior)
		if eff > best_value:
			best_value = eff
			best_behavior = behavior
	return best_behavior

## Returns the behavior the player is LEAST effective against.
func get_weakest_against() -> int:
	var worst_behavior = 0
	var worst_value = 999.0
	for behavior in range(6):
		var eff = get_effectiveness_vs_behavior(behavior)
		if eff < worst_value:
			worst_value = eff
			worst_behavior = behavior
	return worst_behavior
