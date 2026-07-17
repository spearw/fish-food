## boomerang_weapon.gd -- the Projectiles deck's return arc: hits going out AND coming back.
class_name BoomerangWeapon
extends TransformableWeapon

func _on_transformation_acquired(id: String):
	## Razor Return: the return pass hits for double -- positioning the catch is the play.
	## Applied per-projectile at the turn (BoomerangProjectile.return_damage_mult reads this).
	if id == "razor_return":
		razor_return = true
	## Wide Arc: longer, faster flight -- the blade owns more water on both passes.
	if id == "wide_arc":
		projectile_stats.lifetime = projectile_stats.lifetime * 1.6
		projectile_stats.speed = projectile_stats.speed * 1.2

var razor_return := false
