## meteor_weapon.gd -- evolution host for Cosmic's barrage.
class_name MeteorWeapon
extends TransformableWeapon

func _on_transformation_acquired(id: String):
	## Meteor Shower: double the volley.
	if id == "meteor_shower":
		base_projectile_count += 3
	## Deep Impact: x1.5 damage, x1.5 blast, x2 knockback.
	if id == "deep_impact":
		projectile_stats.damage = projectile_stats.damage * 1.5
		projectile_stats.scale = projectile_stats.scale * 1.5
		projectile_stats.knockback_force = projectile_stats.knockback_force * 2.0
		var overrides: Dictionary = projectile_stats.effect_overrides.get(WeaponTags.Effect.AOE, {})
		var base_radius: float = overrides.get("radius",
			WeaponTagRegistry.get_effect_data(WeaponTags.Effect.AOE, {}).get("radius", 50.0))
		overrides["radius"] = base_radius * 1.5
		projectile_stats.effect_overrides[WeaponTags.Effect.AOE] = overrides
