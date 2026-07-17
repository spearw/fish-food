## persistent_damage_effect.gd
## A generic, persistent Area2D that repeatedly applies a payload.
## Configured by a PersistentEffectStats resource.
class_name PersistentDamageEffect
extends Area2D

var stats: PersistentEffectStats
## Damage-report identity, inherited from whatever spawned the zone.
var attribution_key: String = ""
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

	# Despawn after set time, scaled by the owner's status-duration stat: a persistent zone IS a
	# status writ large, so Lingering Fumes (and fire_fuel) extend clouds, ground fire and firewalls.
	# This is the persistence-build lever -- cloud count has NO cap; how many are alive is just
	# duration / spawn-rate, and this multiplies the numerator (playtest finding, Jul 2026).
	var duration: float = stats.duration
	if is_instance_valid(user) and user.has_method("get_stat"):
		duration *= maxf(user.get_stat("status_duration"), 0.1)
	lifetime_timer.wait_time = duration
	lifetime_timer.timeout.connect(queue_free)
	lifetime_timer.start()

## Rolling Fog: zones with drift_speed > 0 creep toward the nearest enemy. Target re-resolved on
## a coarse timer (spatial queries per-frame per-zone would be waste); motion is per-frame.
var _drift_target: Node2D = null
var _drift_requery: float = 0.0

func _physics_process(delta: float) -> void:
	if stats == null or stats.get("drift_speed") == null or stats.drift_speed <= 0.0:
		return
	_drift_requery -= delta
	if _drift_requery <= 0.0 or not is_instance_valid(_drift_target):
		_drift_requery = 0.35
		var near: Array = EntityRegistry.get_candidates_near("enemies", global_position, 320.0)
		_drift_target = near[0] if not near.is_empty() and is_instance_valid(near[0]) else null
	if is_instance_valid(_drift_target):
		global_position += (_drift_target.global_position - global_position).normalized() \
			* stats.drift_speed * delta

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
			var status_chance_mult: float = user.get_stat("status_chance_bonus") \
				if is_instance_valid(user) and user.is_in_group("player") else 1.0
			if stats.status_to_apply and randf() < stats.status_chance * status_chance_mult:
				var mgr = _body_managers.get(body)
				if mgr != null:
					# Statuses inherit the zone's damage-report identity (was uncredited "Other").
					mgr.apply_status(stats.status_to_apply, user, attribution_key)
			if stats.damage and body.has_method("take_damage"):
				# Universal crit: the zone's own base composes with the player's flat layer.
				var crit: Dictionary = DamageUtils.compose_crit(
					stats.critical_hit_rate, stats.critical_hit_damage, user)
				var rolled: Dictionary = DamageUtils.roll_crit(stats.damage, crit.rate, crit.mult)
				body.take_damage(rolled.damage, stats.armor_penetration, rolled.is_crit, self)

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
