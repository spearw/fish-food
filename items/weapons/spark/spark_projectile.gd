## spark_projectile.gd
## A spark projectile that bounces between enemies by retargeting.
## Does flat damage and tracks hit targets to avoid bouncing back.
class_name SparkProjectile
extends Node2D

# --- Allegiance ---
enum Allegiance { PLAYER, ENEMY, NONE }
var allegiance: Allegiance

# --- Spark Properties ---
@export var base_damage: int = 5  # Flat damage per hit
@export var bounce_count: int = 3  # How many times to bounce
@export var bounce_range: float = 200.0  # Range to find next target
@export var speed: float = 600.0  # Movement speed
@export var lifetime: float = 5.0  # Max lifetime before despawn

# --- Runtime State ---
var direction: Vector2 = Vector2.RIGHT
var target: Node2D = null
var user: Node2D = null
var weapon: Node2D = null
var bounces_remaining: int = 0
var _hit_targets: Dictionary = {}  # Using Dictionary for O(1) lookup
var _is_destroying: bool = false

# --- Node References ---
@onready var sprite: Sprite2D = $Area2D/Sprite2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var lifetime_timer: Timer = $LifetimeTimer
@onready var area2d: Area2D = $Area2D

func _ready():
	bounces_remaining = bounce_count

	# Configure collision based on allegiance
	CollisionUtils.set_projectile_collision(area2d, allegiance)

	# Setup lifetime timer
	if lifetime > 0:
		lifetime_timer.wait_time = lifetime
		lifetime_timer.one_shot = true
		lifetime_timer.timeout.connect(_destroy)
		lifetime_timer.start()

	# Connect hit signal
	area2d.body_entered.connect(_on_body_entered)

	# If we have an initial target, aim at it
	if is_instance_valid(target):
		direction = (target.global_position - global_position).normalized()
		rotation = direction.angle()

func _process(delta: float):
	# Home toward target if we have one
	if is_instance_valid(target):
		var direction_to_target = (target.global_position - global_position).normalized()
		# Strong homing for sparks
		direction = direction.lerp(direction_to_target, 15.0 * delta)
		rotation = direction.angle()

	global_position += direction * speed * delta

func _on_body_entered(body: Node2D):
	if _is_destroying:
		return

	# Check if this is a valid target
	var target_group = CollisionUtils.get_target_group(allegiance)
	if not body.is_in_group(target_group):
		return

	# Skip if already hit this target (O(1) Dictionary lookup)
	if _hit_targets.has(body):
		return

	# Deal damage
	if body.has_method("take_damage"):
		var is_crit = false
		# Check for crit from user stats
		if is_instance_valid(user) and user.has_method("get_stat"):
			var crit_chance = user.get_stat("critical_hit_rate")
			if randf() < crit_chance:
				is_crit = true

		var final_damage = base_damage
		if is_crit and is_instance_valid(user) and user.has_method("get_stat"):
			final_damage = int(base_damage * user.get_stat("critical_hit_damage"))

		body.take_damage(final_damage, 0.0, is_crit, self)

	# Track this target (O(1) Dictionary insert)
	_hit_targets[body] = true

	# Try to bounce
	bounces_remaining -= 1
	if bounces_remaining <= 0:
		_destroy()
		return

	# Find next target
	var next_target = _find_next_target(body.global_position)
	if next_target:
		target = next_target
		direction = (target.global_position - global_position).normalized()
		rotation = direction.angle()
	else:
		# No valid targets - fire off in random direction (sparks should always feel active)
		target = null
		var random_angle = randf() * TAU
		direction = Vector2.from_angle(random_angle)
		rotation = direction.angle()

func _find_next_target(from_position: Vector2) -> Node2D:
	var target_group = CollisionUtils.get_target_group(allegiance)
	# Spatial-hash query: only enemies in nearby cells, not every enemy on the map.
	var candidates = EntityRegistry.get_candidates_near(target_group, from_position, bounce_range)

	# Filter out already hit targets and out-of-range targets
	var valid_candidates = []
	for candidate in candidates:
		if _hit_targets.has(candidate):
			continue
		if not is_instance_valid(candidate):
			continue
		var dist = from_position.distance_to(candidate.global_position)
		if dist <= bounce_range:
			valid_candidates.append(candidate)

	if valid_candidates.is_empty():
		return null

	return TargetingUtils.find_nearest(from_position, valid_candidates)

func _destroy():
	if _is_destroying:
		return
	_is_destroying = true

	# Disable collision
	if area2d:
		area2d.set_deferred("monitoring", false)
		area2d.set_deferred("monitorable", false)

	# Stop timer
	if lifetime_timer:
		lifetime_timer.stop()

	# Return to pool instead of destroying
	ProjectilePool.return_spark(self)

## Resets spark state for pool reuse.
func reset():
	_is_destroying = false
	_hit_targets.clear()
	direction = Vector2.RIGHT
	target = null
	user = null
	weapon = null
	bounces_remaining = bounce_count

	# Re-enable collision
	if area2d:
		area2d.monitoring = true
		area2d.monitorable = true
