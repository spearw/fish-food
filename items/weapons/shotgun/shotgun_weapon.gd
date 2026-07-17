## shotgun_weapon.gd -- evolution host for the burst cone.
class_name ShotgunWeapon
extends TransformableWeapon

func _on_transformation_acquired(id: String):
	## Choke Barrel: the focus path -- 6 heavy pellets in a 10-degree line, each piercing 3.
	if id == "choke_barrel":
		base_projectile_count = 6
		fire_behavior_component.spread_angle_degrees = 10.0
		projectile_stats.damage = projectile_stats.damage * 1.5
		projectile_stats.pierce = 3
	## Riot Spread: the wall path -- 16 pellets across 60 degrees with doubled knockback.
	if id == "riot_spread":
		base_projectile_count = 16
		fire_behavior_component.spread_angle_degrees = 60.0
		projectile_stats.knockback_force = projectile_stats.knockback_force * 2.0
