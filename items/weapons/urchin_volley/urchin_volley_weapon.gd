## urchin_volley_weapon.gd -- the Venom deck's crowd-seeder: a radial burst of poisoning spines.
## Fire it while swimming THROUGH the school -- pairs with the deck's move-speed identity.
class_name UrchinVolleyWeapon
extends TransformableWeapon

## Tidepool: spines leave small poison puddles where they land (thunderhead machinery, tide-sized).
## Exported so weapon._ready() localizes and rarity-scales it, nested puddle included.
@export var tidepool_stats: MultiStageProjectileStats
const EXPLODING_SCENE := preload("res://systems/projectiles/exploding_projectile/exploding_projectile.tscn")

func _on_transformation_acquired(id: String):
	if id == "tidepool":
		if tidepool_stats == null:
			printerr("UrchinVolleyWeapon: tidepool_stats not assigned; transform skipped")
			return
		projectile_stats = tidepool_stats
		custom_projectile_scene = EXPLODING_SCENE
	## Needle Storm: the volume path -- near-double spines, faster volleys.
	if id == "needle_storm":
		base_projectile_count += 6
		base_fire_rate = base_fire_rate * 0.75
		update_stats()
