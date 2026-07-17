## singularity_zone.gd -- the pull-then-pop at the heart of the Singularity weapon: drags nearby
## enemies toward its center for pull_duration, then detonates. The deck solving its own whiff
## problem: group enemies first, then land the aimed weapons. Custom scene, never pooled.
## Pull trick: entity.apply_knockback(force, from) pushes AWAY from `from`, so pulling toward the
## center means pushing from the enemy's own reflection on the far side.
class_name SingularityZone
extends Node2D

# Set by FireBehaviorComponent like any projectile.
var stats: ProjectileStats
var direction: Vector2 = Vector2.ZERO
var allegiance = Projectile.Allegiance.PLAYER
var weapon: Node2D
var target: Node2D
var user: Node2D
var attribution_key: String = ""

# Read off the owning weapon at ready (evolutions mutate the weapon's exports).
var pull_radius: float = 220.0
var pull_force: float = 90.0
var pull_duration: float = 1.2
var pop_per_enemy: int = 0
var pop_radius: float = 160.0

var _age: float = 0.0
var _pull_tick: float = 0.0
var _popped := false

func _ready() -> void:
	if is_instance_valid(weapon):
		pull_radius = weapon.get("pull_radius") if weapon.get("pull_radius") != null else pull_radius
		pull_force = weapon.get("pull_force") if weapon.get("pull_force") != null else pull_force
		pull_duration = weapon.get("pull_duration") if weapon.get("pull_duration") != null else pull_duration
		pop_per_enemy = weapon.get("pop_per_enemy") if weapon.get("pop_per_enemy") != null else pop_per_enemy

func _physics_process(delta: float) -> void:
	if _popped:
		return
	_age += delta
	_pull_tick -= delta
	if _pull_tick <= 0.0:
		_pull_tick = 0.1
		for e in EntityRegistry.get_candidates_near("enemies", global_position, pull_radius):
			if is_instance_valid(e) and e.has_method("apply_knockback"):
				# Push from the enemy's reflection across the center = pull toward the center.
				var mirror: Vector2 = e.global_position * 2.0 - global_position
				e.apply_knockback(pull_force, mirror)
	if _age >= pull_duration:
		_pop()

func _pop() -> void:
	_popped = true
	var caught: Array = EntityRegistry.get_candidates_near("enemies", global_position, pop_radius)
	var live := 0
	for e in caught:
		if is_instance_valid(e):
			live += 1
	# Collapse evolution: the pop scales with how many were caught in the well.
	var damage: int = int(stats.damage) + pop_per_enemy * live if stats else pop_per_enemy * live
	for e in caught:
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.take_damage(damage, stats.armor_penetration if stats else 0.0, false, self)
	queue_free()
