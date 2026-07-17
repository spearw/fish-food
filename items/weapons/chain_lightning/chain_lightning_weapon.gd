## chain_lightning_weapon.gd -- evolution host for the chain lightning bolt.
class_name ChainLightningWeapon
extends TransformableWeapon

## Fork Lightning: bolts split on their first hit into two bolts at 60% damage.
## Superconductor: no resistance -- every hit releases 2 sparks that bounce 6 times at extended
## range (pure SPARK effect_overrides; player spark cards still add on top).
const FORK_SCENE := preload("res://systems/projectiles/fork_projectile/fork_bolt_x2.tscn")

func _on_transformation_acquired(id: String):
	if id == "fork_lightning":
		custom_projectile_scene = FORK_SCENE
	if id == "superconductor":
		var overrides: Dictionary = projectile_stats.effect_overrides.get(WeaponTags.Effect.SPARK, {})
		overrides["spark_count"] = 2
		overrides["spark_bounces"] = 6
		overrides["spark_range"] = 300.0
		projectile_stats.effect_overrides[WeaponTags.Effect.SPARK] = overrides
