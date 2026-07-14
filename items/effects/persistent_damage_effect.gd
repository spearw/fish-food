## persistent_damage_effect.gd
## A generic, persistent Area2D that repeatedly applies a payload.
## Configured by a PersistentEffectStats resource.
class_name PersistentDamageEffect
extends Area2D

var stats: PersistentEffectStats
var user: Node:
	set(new_user):
		# Disconnect from any old user to prevent memory leaks.
		if is_instance_valid(user) and user.has_signal("stats_changed"):
			user.stats_changed.disconnect(_on_user_stats_changed)
			
		user = new_user
		
		# Connect to the new user's signal if they are a player.
		if is_instance_valid(user) and user.is_in_group("player"):
			user.stats_changed.connect(_on_user_stats_changed)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var tick_timer: Timer = $TickTimer
@onready var lifetime_timer: Timer = $LifetimeTimer
var allegiance
var base_scale
var _overlapping_bodies: Array = []  # Cached list of bodies in area
var _body_managers: Dictionary = {}  # body -> its StatusEffectManager (or null), resolved once on enter

func _ready():
	# Guard clause to ensure correct data type.
	self.stats = stats as PersistentEffectStats
	if not self.stats:
		printerr("PersistentDamageEffect requires a PersistentEffectStats resource!")
		queue_free()
		return
		
	# Configure physics mask based on allegiance.
	match allegiance:
		Projectile.Allegiance.PLAYER:
			self.collision_layer = 1 << 5 
			self.collision_mask = 1 << 1 
		
		Projectile.Allegiance.ENEMY:
			self.collision_layer = 1 << 6
			self.collision_mask = 1 << 0 
	
	# Configure visuals
	animated_sprite.sprite_frames = stats.animation
	animated_sprite.play("default")
	self.scale = stats.scale
	self.modulate = stats.modulation
	
	# Configure hitbox
	_generate_circular_hitbox()

	# Configure behavior
	tick_timer.wait_time = stats.tick_rate
	tick_timer.timeout.connect(_on_tick_timer_timeout)
	tick_timer.start()

	# Cache overlapping bodies via signals (avoids physics query every tick)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Despawn after set time
	lifetime_timer.wait_time = stats.duration
	lifetime_timer.timeout.connect(queue_free)
	lifetime_timer.start()

func _on_body_entered(body: Node2D) -> void:
	if body not in _overlapping_bodies:
		_overlapping_bodies.append(body)
		# Resolve the status manager once, on entry, so the per-tick loop is free of string lookups.
		_body_managers[body] = body.get_node_or_null("StatusEffectManager")

func _on_body_exited(body: Node2D) -> void:
	_overlapping_bodies.erase(body)
	_body_managers.erase(body)

func _on_tick_timer_timeout():
	var target_group = "enemies" if allegiance == Projectile.Allegiance.PLAYER else "player"

	for body in _overlapping_bodies:
		if not is_instance_valid(body):
			continue
		if body.is_in_group(target_group):
			# Apply payload (StatusEffectManager was resolved on entry, not looked up here).
			if stats.status_to_apply and randf() < stats.status_chance:
				var mgr = _body_managers.get(body)
				if mgr != null:
					mgr.apply_status(stats.status_to_apply, user)
			if stats.damage and body.has_method("take_damage"):
				body.take_damage(stats.damage, stats.armor_penetration, false)

func _generate_circular_hitbox():
	# A helper to make a circular hitbox around character
	if not animated_sprite.sprite_frames or not animated_sprite.sprite_frames.has_animation("default"): return
	var texture = animated_sprite.sprite_frames.get_frame_texture("default", 0)
	if not texture: return
	

	if not base_scale:
		base_scale = animated_sprite.scale
		
	var radius = texture.get_width() / 2.0
	if user.has_method("get_stat"):
		var size_multiplier = user.get_stat("area_size")
		radius *= size_multiplier
		animated_sprite.scale = base_scale * size_multiplier
	var circle = CircleShape2D.new()
	circle.radius = radius
	collision_shape.shape = circle

func _on_user_stats_changed():
	_generate_circular_hitbox()
