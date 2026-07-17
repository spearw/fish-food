## spike_ring_weapon.gd -- evolution host for the nova ring.
class_name SpikeRingWeapon
extends TransformableWeapon

## Shrapnel Ring: spikes burst on their first hit (multi-stage machinery, explosion payload).
## Exported so weapon._ready() localizes and rarity-scales it, nested burst included.
@export var shrapnel_stats: MultiStageProjectileStats
const EXPLODING_SCENE := preload("res://systems/projectiles/exploding_projectile/exploding_projectile.tscn")

func _on_transformation_acquired(id: String):
	## Bladed Ring: the ring becomes a WAVE -- spikes pierce everything and travel farther.
	if id == "bladed_ring":
		projectile_stats.pierce = -1
		projectile_stats.lifetime = projectile_stats.lifetime * 1.5
		projectile_stats.speed = projectile_stats.speed * 1.2
	if id == "shrapnel_ring":
		if shrapnel_stats == null:
			printerr("SpikeRingWeapon: shrapnel_stats not assigned; transform skipped")
			return
		projectile_stats = shrapnel_stats
		custom_projectile_scene = EXPLODING_SCENE
