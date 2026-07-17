## daggers_weapon.gd -- evolution host for the deck's fast stream.
class_name DaggersWeapon
extends TransformableWeapon

## Ricochet: daggers chain to a second target at 80% (fork machinery, count 1).
const RICOCHET_SCENE := preload("res://systems/projectiles/fork_projectile/ricochet_dagger.tscn")

func _on_transformation_acquired(id: String):
	if id == "ricochet":
		custom_projectile_scene = RICOCHET_SCENE
	## Twin Throw: a second dagger flies backward (MIRRORED machinery).
	if id == "twin_throw":
		fire_behavior_component.fire_pattern = FireBehaviorComponent.FirePattern.MIRRORED_FORWARD
