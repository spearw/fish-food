## lightning_sword_weapon.gd -- evolution host for the lightning sword.
class_name LightningSwordWeapon
extends TransformableWeapon

## Storm Blade: each swing also launches a piercing wave of charge -- melee's range answer.
## Shape, not multipliers: the sword is the bench's damage outlier, so its evolution adds REACH.
## Exported so weapon._ready() localizes and rarity-scales the wave with the instance's tier.
@export var wave_stats: ProjectileStats
const WAVE_SCENE := preload("res://systems/projectiles/projectile.tscn")

func _on_fire_rate_timer_timeout():
	super()
	if has_transformation("storm_blade"):
		_fire_wave()

func _fire_wave() -> void:
	if wave_stats == null or not is_instance_valid(stats_component.user):
		return
	var projectile = ProjectilePool.get_projectile(WAVE_SCENE)
	if projectile == null:
		return  # over the concurrent generic-projectile cap
	var wave_user = stats_component.user
	var origin: Vector2 = wave_user.global_position
	# Aim at the nearest enemy; fall back to a random slash direction.
	var dir := Vector2.RIGHT.rotated(randf() * TAU)
	var candidates: Array = EntityRegistry.get_candidates_near("enemies", origin, 420.0)
	if not candidates.is_empty() and is_instance_valid(candidates[0]):
		dir = (candidates[0].global_position - origin).normalized()
	# Mirror FireBehaviorComponent's pooled-projectile sequence exactly (stats BEFORE add_child --
	# a null-stats projectile self-destructs on entering the tree).
	var from_pool: bool = projectile._is_pooled if projectile.get("_is_pooled") != null else false
	projectile.stats = wave_stats
	projectile.direction = dir
	projectile.allegiance = stats_component.get_projectile_allegiance()
	projectile.weapon = self
	projectile.user = wave_user
	projectile.attribution_key = String(get_meta("weapon_type", name))
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = origin + dir * 30.0
	projectile.rotation = dir.angle()
	if from_pool and projectile.has_method("activate"):
		projectile.activate()
	elif not from_pool:
		projectile._is_pooled = true
