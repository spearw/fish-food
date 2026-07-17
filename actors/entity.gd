## entity.gd
## Base class for all living, moving characters in the game.
## Manages health, damage, knockback, and death.
class_name Entity
extends CharacterBody2D

# Signal emitted when health changes.
signal health_changed(current_health, max_health)
# Signal emitted when the entity's health reaches zero.
signal died(stats)

@export var stats: EntityStats
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- Runtime Variables ---
var current_health: int
var max_health: int
var knockback_velocity: Vector2 = Vector2.ZERO
var is_dying: bool = false
var _speed_modifiers: Dictionary = {}  # id -> multiplier (for slow effects)
   

## Initializes the entity using its stats resource.
func _ready() -> void:
	if not stats:
		printerr("Entity spawned without an EntityStats resource! Deleting self.")
		queue_free()
		return
	
	# Apply stats from the resource.
	max_health = stats.max_health
	current_health = max_health
	self.scale = stats.scale
	animated_sprite.sprite_frames = stats.sprite_frames
	
	# Connect the health_changed signal to a virtual method for subclasses to use.
	health_changed.connect(_on_health_changed)


## Armor eaten by corrosion effects this entity's lifetime (see take_damage). Floors at full
## armor negation; never mutates the (possibly shared) stats resource.
var armor_shred: float = 0.0

## Applies physics, primarily knockback decay.
func _physics_process(delta: float) -> void:
	# Lerp knockback velocity back to zero for a smooth recovery effect.
	knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 0.05)


## Public method to apply damage to the entity.
## This is the core damage calculation logic. Subclasses can add unique effects by overriding it.
func take_damage(amount: int, armor_pen: float, is_crit: bool, source_node: Node = null) -> void:
	if is_dying:
		return

	# --- Armor Calculation (using DamageUtils) ---
	# armor_shred is per-ENTITY corrosion (the Corrosion artifact eats shells over time). It lives
	# on the instance, never on the stats resource -- enemy stats resources can be shared.
	var damage_taken = DamageUtils.apply_armor(
		amount, maxf(0.0, self.stats.armor - armor_shred), armor_pen)

	# Per-source damage attribution: ACTUAL post-armor damage, credited to the source's
	# attribution_key (armor-blocked hits honestly credit nothing). A null source is a DoT tick,
	# which credits itself where the tick is computed -- crediting it here too would double-count.
	if damage_taken > 0 and source_node != null:
		var attribution: String = "Other"
		if "attribution_key" in source_node and source_node.attribution_key != "":
			attribution = source_node.attribution_key
		CurrentRun.credit_damage(attribution, damage_taken)

	# Apply damage.
	current_health = max(0, current_health - damage_taken)
	
	# Emit the signal to notify listeners (like the UI or health bars).
	health_changed.emit(current_health, max_health)
	
	# Call the virtual method for subclass-specific post-damage logic.
	_on_take_damage(damage_taken, is_crit, source_node)
	
	# Check for death condition.
	if current_health <= 0:
		die()


## Applies a knockback force away from a given point.
## @param force: float - The strength of the knockback.
## @param from_position: Vector2 - The world position the knockback originates from.
func apply_knockback(force: float, from_position: Vector2) -> void:
	var direction = (self.global_position - from_position).normalized()
	knockback_velocity = direction * force


## Heals the entity for a given amount.
func heal(amount: int) -> void:
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)


## Handles the entity's death sequence. Meant to be overridden by subclasses.
func die() -> void:
	if is_dying: return # Prevent die() from being called multiple times.
	
	is_dying = true
	died.emit()
	# Subclasses should call super() and then add their specific death logic (e.g., play animation, drop loot).
	# For now, we simply remove the entity from the game.
	queue_free()

# --- Virtual Methods for Subclasses ---

## A "hook" for subclasses to react after damage has been calculated and applied.
func _on_take_damage(damage_taken: int, is_crit: bool, source_node: Node):
	pass # Player might emit a signal, Enemy might spawn a damage number.

## A "hook" for subclasses to react to health changes.
func _on_health_changed(current: int, max_val: int):
	pass # Enemy will use this to update its health bar.

# --- Speed Modifier Methods ---

## Applies a speed modifier with a unique ID.
## @param id: Unique identifier for this modifier (so it can be removed).
## @param multiplier: Speed multiplier (0.7 = 30% slow, 1.0 = normal).
func apply_speed_modifier(id: String, multiplier: float) -> void:
	_speed_modifiers[id] = multiplier

## Removes a speed modifier by ID.
func remove_speed_modifier(id: String) -> void:
	_speed_modifiers.erase(id)

## Gets the effective move speed after all modifiers.
## Subclasses should use this instead of stats.move_speed directly.
func get_effective_move_speed() -> float:
	var speed = stats.move_speed
	for modifier in _speed_modifiers.values():
		speed *= modifier
	return speed
