## tesla_coil_weapon.gd -- evolution host for the tesla coil.
class_name TeslaCoilWeapon
extends TransformableWeapon

## Overcharged Capacitor: the coil finally becomes what its card always claimed -- a slow,
## PATIENT weapon. Longer charge, triple hit, and the bolt forks into three on impact.
const FORK_SCENE := preload("res://systems/projectiles/fork_projectile/fork_bolt_x3.tscn")
const OVERCHARGE_WAIT := 4.0
const OVERCHARGE_DAMAGE_MULT := 3.0

func _on_transformation_acquired(id: String):
	if id == "overcharged_capacitor":
		base_fire_rate = OVERCHARGE_WAIT
		# In-place on the localized per-instance stats, so the current tier is preserved and
		# future merges rescale the tripled value consistently.
		projectile_stats.damage = projectile_stats.damage * OVERCHARGE_DAMAGE_MULT
		custom_projectile_scene = FORK_SCENE
		update_stats()  # re-derive the fire timer from the new base rate
