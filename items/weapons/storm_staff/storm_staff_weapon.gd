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
