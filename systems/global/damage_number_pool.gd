## damage_number_pool.gd
## A singleton that maintains a pool of damage number labels for efficient reuse.
## Avoids expensive instantiate/queue_free cycles for high-frequency damage numbers.
extends Node

const DAMAGE_NUMBER_SCENE = preload("res://ui/damage_number/damage_number.tscn")

# Pool storage
var _pool: Array = []

# Maximum pool size (prevents memory bloat)
const MAX_POOL_SIZE: int = 2000
# Cap concurrent on-screen damage numbers. Hundreds are unreadable, and their render + spawn
# churn is a primary driver of the high-count runaway. Only bites at extreme density.
const MAX_ACTIVE: int = 150
var _active: int = 0

## Get a damage number from the pool, or create a new one if pool is empty.
func get_damage_number() -> Node:
	# Over the concurrent cap -> skip (caller must handle null).
	if _active >= MAX_ACTIVE:
		return null
	_active += 1
	# Try to get from pool
	if _pool.size() > 0:
		var damage_num = _pool.pop_back()
		if is_instance_valid(damage_num):
			damage_num.visible = true
			return damage_num

	# Pool empty - instantiate new
	var damage_num = DAMAGE_NUMBER_SCENE.instantiate()
	damage_num._is_pooled = true
	return damage_num

## Return a damage number to the pool for reuse.
func return_damage_number(damage_num: Node) -> void:
	_active = max(0, _active - 1)
	# Don't exceed max pool size
	if _pool.size() >= MAX_POOL_SIZE:
		damage_num.queue_free()
		return

	# Reset and deactivate
	damage_num.visible = false
	damage_num.modulate.a = 1.0  # Reset alpha

	# Remove from scene tree but don't free
	if damage_num.get_parent():
		damage_num.get_parent().remove_child(damage_num)

	_pool.append(damage_num)

## Clear all pools (useful for scene transitions)
func clear_pool() -> void:
	for damage_num in _pool:
		if is_instance_valid(damage_num):
			damage_num.queue_free()
	_pool.clear()

## Get pool statistics for debugging
func get_pool_stats() -> int:
	return _pool.size()
