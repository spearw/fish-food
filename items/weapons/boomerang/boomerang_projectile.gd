## boomerang_projectile.gd -- at half-life the blade turns and homes back to its thrower,
## hitting everything on both passes (a body can be struck once per pass -- re-entry re-triggers).
## Custom scene, never pooled.
class_name BoomerangProjectile
extends Projectile

var _flight_time: float = 0.0
var _returning := false

func _process(delta: float) -> void:
	super(delta)
	if _is_destroying:
		return
	_flight_time += delta
	# Visual spin.
	if sprite:
		sprite.rotation += 14.0 * delta
	if not _returning and _flight_time >= stats.lifetime * 0.5:
		_returning = true
		# Razor Return evolution: the return pass hits for double (read off the owning weapon).
		if is_instance_valid(weapon) and weapon.get("razor_return") == true:
			damage = damage * 2.0
	if _returning and is_instance_valid(user):
		direction = (user.global_position - global_position).normalized()
		rotation = direction.angle()
		# Caught: the throw is complete.
		if global_position.distance_to(user.global_position) < 26.0:
			_destroy()
