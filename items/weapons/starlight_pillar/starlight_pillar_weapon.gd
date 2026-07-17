## starlight_pillar_weapon.gd -- Cosmic's lingering light: a beam column that stands where it
## falls, ticking everything inside. Rides the zone machinery, so status-duration extends it.
class_name StarlightPillarWeapon
extends TransformableWeapon

func _on_transformation_acquired(id: String):
	## Eternal Light: the pillar stands nearly twice as long.
	if id == "eternal_light":
		if projectile_stats is MultiStageProjectileStats and projectile_stats.on_death_effect_stats:
			var zone = projectile_stats.on_death_effect_stats
			zone.duration = zone.duration * 1.8
			zone.lifetime = zone.lifetime * 1.8
	## Widening Gyre: the column blooms wider and ticks faster.
	if id == "widening_gyre":
		if projectile_stats is MultiStageProjectileStats and projectile_stats.on_death_effect_stats:
			var zone = projectile_stats.on_death_effect_stats
			zone.scale = zone.scale * 1.6
			zone.tick_rate = zone.tick_rate * 0.75
