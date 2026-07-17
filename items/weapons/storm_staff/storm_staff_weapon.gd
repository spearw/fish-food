## storm_staff_weapon.gd -- evolution host for the storm staff.
class_name StormStaffWeapon
extends TransformableWeapon

## Thunderhead: bolts detonate into storm clouds that rain strikes. Rides the persistent-zone
## machinery (molotov ground-fire pattern), so cloud duration scales with status_duration --
## Lingering Fumes extends storms, a natural lightning x toxin bridge.
## Exported so weapon._ready() localizes AND rarity-scales it (nested cloud stats included) --
## a transform must never lose the instance's tier.
@export var thunderhead_stats: MultiStageProjectileStats
const EXPLODING_SCENE := preload("res://systems/projectiles/exploding_projectile/exploding_projectile.tscn")

func _on_transformation_acquired(id: String):
	if id == "thunderhead":
		if thunderhead_stats == null:
			printerr("StormStaffWeapon: thunderhead_stats not assigned; transform skipped")
			return
		projectile_stats = thunderhead_stats
		custom_projectile_scene = EXPLODING_SCENE
	## Ball Lightning: bolts become slow drifting orbs that pierce everything, retarget after
	## kills, and spark every enemy they touch (the living-flame mutation set, recolored).
	## can_retarget makes pooled projectiles unpoolable -- safe since abandon_generic (eel-bug fix).
	if id == "ball_lightning":
		projectile_stats.pierce = -1
		projectile_stats.speed = projectile_stats.speed * 0.4
		projectile_stats.lifetime = projectile_stats.lifetime * 2.5
		projectile_stats.can_retarget = true
		projectile_stats.homing_strength = 3.0
		projectile_stats.scale = projectile_stats.scale * 1.6
