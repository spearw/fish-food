## harpoon_gun_weapon.gd -- the Projectiles deck's big number: a slow, heavy line shot that
## pierces everything it crosses. The deck's only large hit, and its armor-relevant tool (0.4 pen).
class_name HarpoonGunWeapon
extends TransformableWeapon

## Barbed Harpoon: impaled enemies are slowed and hurled -- the harpoon controls the line it draws.
const IMPALE_SLOW := preload("res://items/weapons/harpoon_gun/impale_slow.tres")

func _on_transformation_acquired(id: String):
	if id == "barbed_harpoon":
		projectile_stats.knockback_force = projectile_stats.knockback_force * 2.5
		projectile_stats.status_to_apply = IMPALE_SLOW
		projectile_stats.status_chance = 1.0
	## Twin Harpoon: a second harpoon fires backward (MIRRORED machinery, flamethrower precedent).
	if id == "twin_harpoon":
		fire_behavior_component.fire_pattern = FireBehaviorComponent.FirePattern.MIRRORED_FORWARD
