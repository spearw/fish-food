## sea_snake_fang_weapon.gd -- the Venom deck's stacker: a fast homing dart whose hit is small
## and whose venom is the payload (status-weighted rarity 0.3/1.5 -- tiers are almost all venom).
class_name SeaSnakeFangWeapon
extends TransformableWeapon

## Pit Viper: the fang chains to a second target at full strength -- the venom is the payload,
## so the chain is about REACH, not damage math (fork machinery, count 1, ratio 1.0).
const CHAIN_SCENE := preload("res://systems/projectiles/fork_projectile/venom_chain.tscn")
## Neurotoxin: at FULL venom stacks the target is slowed every tick (saturation).
const NEURO_SLOW := preload("res://systems/status_effects/poison/neuro_slow.tres")

func _on_transformation_acquired(id: String):
	if id == "pit_viper":
		custom_projectile_scene = CHAIN_SCENE
	if id == "neurotoxin":
		# The localized status instance (weapon._ready duplicated the whole stats tree).
		if projectile_stats.status_to_apply:
			projectile_stats.status_to_apply.max_stack_status = NEURO_SLOW
