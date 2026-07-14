## projectile_pool.gd
## A singleton that maintains pools of projectiles for efficient reuse.
## Avoids expensive instantiate/queue_free cycles for high-frequency projectiles.
## Note: No class_name needed - accessed as autoload "ProjectilePool"
extends Node

const GENERIC_PROJECTILE_SCENE = preload("res://systems/projectiles/projectile.tscn")
const SPARK_PROJECTILE_SCENE = preload("res://items/weapons/spark/spark_projectile.tscn")

# Pool storage: Dictionary mapping scene path -> Array of inactive projectiles
var _pools: Dictionary = {}

# Maximum pool size per projectile type (prevents memory bloat)
const MAX_POOL_SIZE: int = 2000
# Cap concurrent spark (chain-lightning) projectiles. Each spark is an Area2D, so a dense cluster
# hammers the physics broadphase: profiling shows a hard cliff past ~200 (150 sparks ~3ms, 200 ~10ms,
# 250 ~35ms on the dev PC). 200 keeps a full lightning storm on-screen while staying below the cliff.
# Tunable per platform (lower on weaker hardware). Pairs with suppressing per-hit spark damage numbers.
const MAX_ACTIVE_SPARKS: int = 200
var _active_sparks: int = 0
# Cap concurrent generic projectiles (daggers etc.). With a 5s lifetime they accumulate, and
# hundreds of Area2Ds vs a dense enemy field detonate the physics broadphase. Only bites at extreme counts.
const MAX_ACTIVE_GENERIC: int = 300
var _active_generic: int = 0

## Get a projectile from the pool, or create a new one if pool is empty.
func get_projectile(scene: PackedScene = GENERIC_PROJECTILE_SCENE) -> Node:
	# Cap concurrent generic projectiles (sparks have their own cap via get_spark).
	if scene == GENERIC_PROJECTILE_SCENE:
		if _active_generic >= MAX_ACTIVE_GENERIC:
			return null
		_active_generic += 1

	var scene_path = scene.resource_path

	# Initialize pool for this scene type if needed
	if not _pools.has(scene_path):
		_pools[scene_path] = []

	var pool = _pools[scene_path]

	# Try to get from pool
	if pool.size() > 0:
		var projectile = pool.pop_back()
		if is_instance_valid(projectile):
			projectile.set_process(true)
			projectile.set_physics_process(true)
			projectile.visible = true
			return projectile

	# Pool empty - instantiate new
	return scene.instantiate()

## Return a projectile to the pool for reuse.
## Safe to call during physics callbacks - uses deferred removal.
func return_projectile(projectile: Node, scene: PackedScene = GENERIC_PROJECTILE_SCENE) -> void:
	if scene == GENERIC_PROJECTILE_SCENE:
		_active_generic = max(0, _active_generic - 1)
	var scene_path = scene.resource_path

	# Initialize pool for this scene type if needed
	if not _pools.has(scene_path):
		_pools[scene_path] = []

	var pool = _pools[scene_path]

	# Don't exceed max pool size
	if pool.size() >= MAX_POOL_SIZE:
		projectile.call_deferred("queue_free")
		return

	# Reset and deactivate projectile immediately
	projectile.set_process(false)
	projectile.set_physics_process(false)
	projectile.visible = false

	# Defer the entire removal and pool addition to avoid physics callback issues
	# The helper checks parent at execution time, not scheduling time
	call_deferred("_deferred_return", projectile, pool)

## Called deferred to safely remove projectile from scene tree and add to pool.
func _deferred_return(projectile: Node, pool: Array) -> void:
	if not is_instance_valid(projectile):
		return

	# Remove from parent if it has one (check at execution time)
	var parent = projectile.get_parent()
	if parent:
		parent.remove_child(projectile)

	# Add to pool
	pool.append(projectile)

## Clear all pools (useful for scene transitions)
func clear_pools() -> void:
	for scene_path in _pools.keys():
		var pool = _pools[scene_path]
		for projectile in pool:
			if is_instance_valid(projectile):
				projectile.queue_free()
		pool.clear()
	_pools.clear()

## Get pool statistics for debugging
func get_pool_stats() -> Dictionary:
	var stats = {}
	for scene_path in _pools.keys():
		stats[scene_path] = _pools[scene_path].size()
	return stats

## Convenience method to get a spark projectile from the pool.
func get_spark() -> Node:
	if _active_sparks >= MAX_ACTIVE_SPARKS:
		return null  # over the concurrent-spark cap (caller must handle null)
	_active_sparks += 1
	var spark = get_projectile(SPARK_PROJECTILE_SCENE)
	# Reset spark state for reuse
	if spark.has_method("reset"):
		spark.reset()
	return spark

## Convenience method to return a spark projectile to the pool.
func return_spark(spark: Node) -> void:
	_active_sparks = max(0, _active_sparks - 1)
	return_projectile(spark, SPARK_PROJECTILE_SCENE)
