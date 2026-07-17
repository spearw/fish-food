## ink_jet_weapon.gd -- a cone spray that poisons and
## slows (the deck's only slow).
class_name InkJetWeapon
extends TransformableWeapon

## Deep Ink: the spray leaves small lingering ink blots (zone machinery, blot-sized).
## Exported so weapon._ready() localizes and rarity-scales it, nested blot included.
@export var deep_ink_stats: MultiStageProjectileStats
const EXPLODING_SCENE := preload("res://systems/projectiles/exploding_projectile/exploding_projectile.tscn")

func _on_transformation_acquired(id: String):
	if id == "deep_ink":
		if deep_ink_stats == null:
			printerr("InkJetWeapon: deep_ink_stats not assigned; transform skipped")
			return
		projectile_stats = deep_ink_stats
		custom_projectile_scene = EXPLODING_SCENE

## Jet Propulsion: squid physics -- every spray shoves you BACKWARD (an escape tool wearing a
## weapon's clothes; rides the knockback velocity the movement code already decays).
const JET_IMPULSE := 240.0

func fire(multiplier: int = 1):
	super.fire(multiplier)
	if not has_transformation("jet_propulsion"):
		return
	var jet_user = stats_component.user
	if not is_instance_valid(jet_user) or not "knockback_velocity" in jet_user:
		return
	var target = get_node("TargetingComponent").find_target(
		global_position, stats_component.get_projectile_allegiance())
	if is_instance_valid(target):
		var dir: Vector2 = (target.global_position - jet_user.global_position).normalized()
		jet_user.knockback_velocity -= dir * JET_IMPULSE
