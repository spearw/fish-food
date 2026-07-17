## falling_sky_weapon.gd -- Cosmic's ambient rain: a small strike at a random point near you,
## always. Fills the time between the aimed weapons' telegraphs.
## NOTE: aoe_delay stays SHORTER than the fire cadence -- the component's delay timer is shared,
## and overlapping awaits bunch strikes together (cosmetic, but keep the margin).
class_name FallingSkyWeapon
extends TransformableWeapon

@export var rain_radius: float = 250.0

func fire(multiplier: int = 1):
	var sky_user = stats_component.user
	if not is_instance_valid(sky_user):
		return
	var pos: Vector2 = sky_user.global_position \
		+ Vector2.from_angle(randf() * TAU) * randf_range(60.0, rain_radius)
	## Guided Descent: strikes bias toward enemies near the rolled point.
	if has_transformation("guided_descent"):
		var near: Array = EntityRegistry.get_candidates_near("enemies", pos, 160.0)
		if not near.is_empty() and is_instance_valid(near[0]):
			pos = near[0].global_position
	fire_behavior_component._execute_aoe_strike(
		pos, projectile_stats, stats_component.get_projectile_allegiance())

func _on_transformation_acquired(id: String):
	## Storm of Stars: the rain falls a third faster.
	if id == "storm_of_stars":
		base_fire_rate = base_fire_rate * 0.65
		update_stats()
	# guided_descent is read live in fire() via has_transformation.
