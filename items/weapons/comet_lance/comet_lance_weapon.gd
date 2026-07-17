## comet_lance_weapon.gd -- Cosmic's precision strike: one fast comet on the nearest enemy every
## couple of seconds.
class_name CometLanceWeapon
extends TransformableWeapon

func _on_transformation_acquired(id: String):
	## Twin Comets: two strikes per call.
	if id == "twin_comets":
		base_projectile_count += 1
	## Iron Star: 60% armor penetration and a heavier hit. The Cosmic
	## deck's armor answer.
	if id == "iron_star":
		projectile_stats.armor_penetration = 0.6
		projectile_stats.damage = projectile_stats.damage * 1.25
