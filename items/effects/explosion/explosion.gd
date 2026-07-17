## explosion.gd
## Deals one-time area damage to enemies within its shape, configured by ProjectileStats.
class_name Explosion
extends Area2D

## Damage-report identity, inherited from whatever spawned the explosion.
var attribution_key: String = ""

# --- Configured by ProjectileStats ---
var stats: ProjectileStats
var allegiance: Projectile.Allegiance # Still set by the spawner weapon

@onready var sprite: Sprite2D = $Sprite2D # Assuming you have a Sprite2D child
@onready var collision_shape: CollisionShape2D = $CollisionShape2D # Assuming you have one

func _ready():
	if not stats:
		printerr("Explosion spawned without ProjectileStats resource! Deleting self.")
		queue_free()
		return

	# Configure visuals from stats (if applicable)
	if sprite and stats.texture:
		sprite.texture = stats.texture
		sprite.scale = stats.scale
	elif collision_shape and collision_shape.shape == null:
		# Fallback: if no sprite/texture, ensure there's at least a default collision shape.
		pass # For now, assume a CircleShape2D is set in editor.

	# Give the physics engine a frame to register the area's position and shape.
	await get_tree().process_frame

	# Configure physics based on allegiance (using CollisionUtils).
	if not allegiance in Projectile.Allegiance.values():
		printerr("Explosion spawned without a valid allegiance! Deleting.")
		queue_free()
		return

	CollisionUtils.set_projectile_collision(self, allegiance)

	# Get all overlapping bodies.
	var bodies = get_overlapping_bodies()
	var target_group = CollisionUtils.get_target_group(allegiance)

	for body in bodies:
		if body.is_in_group(target_group) and body.has_method("take_damage"):
			body.take_damage(stats.damage, stats.armor_penetration, false, self) # Explosions don't crit by default

	# Quick scale animation for visual feedback.
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.4).from(Vector2(1, 1))
	await tween.finished
	queue_free()
