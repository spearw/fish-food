## chain_lightning_weapon.gd -- evolution host for the chain lightning bolt.
class_name ChainLightningWeapon
extends TransformableWeapon

## Fork Lightning: bolts split on their first hit into two bolts at 60% damage.
const FORK_SCENE := preload("res://systems/projectiles/fork_projectile/fork_bolt_x2.tscn")

func _on_transformation_acquired(id: String):
	if id == "fork_lightning":
		custom_projectile_scene = FORK_SCENE
