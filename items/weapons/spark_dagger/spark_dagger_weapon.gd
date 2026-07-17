## spark_dagger_weapon.gd -- evolution host for the spark dagger.
class_name SparkDaggerWeapon
extends TransformableWeapon

## Static Needles: the blade seeks the vital line. +10 points base crit on the weapon, and
## critical hits release DOUBLE sparks (data-driven: the projectile reads crit_spark_multiplier
## from its SPARK effect data). Marries the dagger's crit identity to the deck's spark engine --
## and with universal flat crit, a crit character turns this into a spark fountain.
func _on_transformation_acquired(id: String):
	if id == "static_needles":
		projectile_stats.critical_hit_rate += 0.10
		var overrides: Dictionary = projectile_stats.effect_overrides.get(WeaponTags.Effect.SPARK, {})
		overrides["crit_spark_multiplier"] = 2.0
		projectile_stats.effect_overrides[WeaponTags.Effect.SPARK] = overrides
	## Arc Fan: throws a fan of three -- the shotgun plumbing (weapon-local count + spread), so
	## projectile-count cards multiply the whole fan.
	if id == "arc_fan":
		base_projectile_count += 2
		fire_behavior_component.spread_angle_degrees = 24.0
