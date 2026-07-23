## enemy.gd
## A generic enemy scene, configured by an EnemyStats resource. Inherits from Entity.
class_name Enemy
extends Entity

# --- Scene Exports ---
@export var damage_number_scene: PackedScene
@export var soul_scene: PackedScene
@export var heart_scene: PackedScene

# --- Node References ---
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar: TextureProgressBar = $TextureProgressBar
@onready var visibility_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var death_timer: Timer = $DeathTimer
@onready var damage_cooldown_timer: Timer = $DamageCooldown
@onready var proximity_detector: Area2D = $ProximityDetector

# --- Runtime Variables ---
var player_node: Node2D
var behavior: EnemyBehavior = null
var is_on_screen: bool = false
var can_deal_damage: bool = true
var ai: Node
var _cached_weapons: Array = []  # Cached weapon list for fire_weapons()
var spawned_size: EnemyTags.Size = EnemyTags.Size.MEDIUM  # Set by encounter director at spawn
# Regeneration bookkeeping: heal() takes ints, so fractional regen accumulates here; the pulse
# timer throttles the green heal flash to once a second.
var _regen_accum: float = 0.0
var _regen_pulse_cooldown: float = 0.0
# Blocked-hit clink throttle: a walled build hitting 10 times a second needs ONE clink, not ten.
var _blocked_clink_cooldown: float = 0.0
# Status stack pips (venom): lazy-created label under the health bar; updated when the count moves.
var _stack_pips: Label = null
var _last_stack_count: int = 0



## Initializes the enemy. The parent Entity's _ready() is called automatically first.
func _ready() -> void:
	# The parent _ready() handles the stats check, health init, and scaling.
	# We still call it with super() to ensure any future parent logic is run.
	super._ready()
	
	modulate = stats.modulate
	player_node = get_tree().get_first_node_in_group("player")
	
	# Instantiate the AI brain from the stats resource.
	if stats.ai_scene:
		ai = stats.ai_scene.instantiate()
		add_child(ai)
		if ai.has_method("initialize_ai"):
			ai.initialize_ai(stats.default_behavior_name)
			
	# Equip weapons defined in the stats resource.
	if stats.weapon_scenes:
		var equipment_node = get_node("Equipment")
		for weapon_scene in stats.weapon_scenes:
			var new_weapon = weapon_scene.instantiate()
			# The weapon needs a reference to its user (this enemy).
			var stats_comp = new_weapon.get_node("WeaponStatsComponent")
			if stats_comp:
				stats_comp.user = self
			equipment_node.add_child(new_weapon)
		# Cache weapon list after all weapons are added
		_cached_weapons = equipment_node.get_children()

	# After equipment is ready, initialize the behavior component.
	if is_instance_valid(behavior) and behavior.has_method("initialize_behavior"):
		behavior.initialize_behavior(self)
	
	# Initialize the health bar (it will be hidden until damage is taken).
	update_health_bar(current_health, stats.max_health)
	health_bar.visible = false
	
	# Connect signals for screen visibility detection.
	visibility_notifier.screen_entered.connect(_on_screen_entered)
	visibility_notifier.screen_exited.connect(_on_screen_exited)

## Physics processing for movement, AI, and collision.
func _physics_process(delta: float) -> void:
	# Call the parent class's physics process to apply knockback decay.
	super._physics_process(delta)
	
	if is_dying:
		# If dying, act as a ragdoll affected only by knockback.
		velocity = knockback_velocity
	else:
		# If alive, process AI behavior.
		if is_instance_valid(behavior):
			behavior.process_behavior(delta, self)

		_blocked_clink_cooldown -= delta
		# Venom stack pips: a "***" row under the health bar, updated only when the count moves.
		if is_on_screen:
			_update_stack_pips()

		# Constant regeneration (the DoT counter): ticks always, race it with direct DPS.
		tick_regen(delta)

		# Update sprite orientation based on stats (skip if off-screen for performance).
		if is_on_screen:
			if stats.face_movement_direction:
				if velocity.length() > 0.1:
					var rotation_offset_radians = deg_to_rad(stats.rotation_offset_degrees)
					animated_sprite.rotation = velocity.angle() + rotation_offset_radians
			else:
				# Flip sprite horizontally to face movement direction.
				if abs(velocity.x) > 0.1:
					animated_sprite.flip_h = (velocity.x < 0) if not stats.is_flipped else (velocity.x > 0)

		# Check for collision with the player to deal contact damage.
		if can_deal_damage:
			for i in range(get_slide_collision_count()):
				var collision = get_slide_collision(i)
				if not collision: continue
				
				var collided_object = collision.get_collider()
				
				if is_instance_valid(collided_object) and collided_object.is_in_group("player"):
					# Start internal damage cooldown to prevent rapid-fire hits.
					can_deal_damage = false 
					damage_cooldown_timer.start(0.5) 
					
					# Damage the player.
					collided_object.take_damage(stats.damage, stats.armor_pen, false, self)
					# Apply knockback to the player.
					var knockback = 400 + (stats.damage * 5)
					collided_object.apply_knockback(knockback, self.global_position)
					return
					
		# Add the decaying knockback from the parent to the velocity from behavior.
		velocity += knockback_velocity
		
	move_and_slide()

# --- Overridden Base Class Methods ---

## This virtual method is called by the parent Entity's `take_damage` function
## AFTER health has been reduced. We use it for enemy-specific visual feedback.
func _on_take_damage(damage_taken: int, is_crit: bool, _source_node: Node) -> void:
	# Optional cosmetic (perf setting). Numbers themselves are cheap (~1ms/150) and pool-capped, but a
	# player on weak hardware can turn them off.
	if not GameSettings.show_damage_numbers:
		return
	# Armor ate the whole hit: show the clink (throttled) so the wall is VISIBLE, then stop --
	# a zeroed hit has no number to float.
	if damage_taken <= 0:
		if _blocked_clink_cooldown > 0.0 or not is_on_screen:
			return
		_blocked_clink_cooldown = 0.5
		var clink = DamageNumberPool.get_damage_number()
		if clink == null:
			return
		get_tree().current_scene.add_child(clink)
		clink.start_blocked(self.global_position)
		return
	# Spawn a floating damage number (including for spark hits).
	var dmg_num_instance = DamageNumberPool.get_damage_number()
	if dmg_num_instance == null:
		return  # damage-number cap reached (too many on screen)
	# Add to the main scene tree so it doesn't move with the enemy.
	get_tree().current_scene.add_child(dmg_num_instance)
	dmg_num_instance.start(damage_taken, self.global_position, is_crit)

## This virtual method is called by the parent Entity whenever health changes.
func _on_health_changed(current: int, max_val: int) -> void:
	update_health_bar(current, max_val)

## Overrides the parent `die` method to add a delay before disappearing,
## allowing for a death animation or effect.
func die() -> void:
	if is_dying: return

	# Set the state flag from the parent class.
	is_dying = true

	# Immediately remove from alive candidates (for targeting optimization)
	EntityRegistry.mark_enemy_dying(self)

	# Stop being a target.
	self.remove_from_group("enemy")
	
	# Start a short timer to allow death effects to play out.
	death_timer.wait_time = 0.3
	death_timer.one_shot = true
	if not death_timer.timeout.is_connected(finalize_death):
		death_timer.timeout.connect(finalize_death)
	death_timer.start()

# --- Enemy-Specific Methods ---

## This function contains the logic that happens after the death timer.
func finalize_death() -> void:
	died.emit(stats) # Announce death to encounter director.
	Events.emit_signal("enemy_killed", self) # Announce death for player powers.
	LootManager.process_loot_drop(stats, self.global_position, self.player_node)
	queue_free()

## The regeneration race (the DoT counter): damage over time races it, direct DPS beats it.
## Public and self-contained: the balance bench holds its dummy field still by turning enemy
## physics OFF, then drives this same race by hand -- one code path, so the bench cannot drift
## from the game.
func tick_regen(delta: float) -> void:
	if is_dying or stats.regen_per_sec <= 0.0 or current_health >= stats.max_health:
		return
	_regen_accum += stats.regen_per_sec * delta
	_regen_pulse_cooldown -= delta
	if _regen_accum >= 1.0:
		var whole := int(_regen_accum)
		_regen_accum -= whole
		heal(whole)
		if _regen_pulse_cooldown <= 0.0 and is_on_screen:
			_regen_pulse_cooldown = 1.0
			var tween := create_tween()
			tween.tween_property(self, "modulate", Color(0.6, 1.5, 0.6, 1.0), 0.15)
			tween.tween_property(self, "modulate", stats.modulate, 0.25)

## Tells all equipped weapons to fire.
func fire_weapons() -> void:
	# Don't fire weapons when off-screen (saves projectile spawning)
	if not is_on_screen:
		return
	for weapon in _cached_weapons:
		if is_instance_valid(weapon) and weapon.has_method("fire"):
			weapon.fire()
				
## Temporarily overrides the enemy's AI behavior.
func override_behavior(new_state_name: String, duration: float, context: Dictionary = {}) -> void:
	if is_instance_valid(ai):
		ai.set_state_by_name(new_state_name, context)
		if duration > 0:
			# Use a safe callback to prevent calling methods on freed nodes
			get_tree().create_timer(duration).timeout.connect(_restore_ai_state_safe)

## Safe wrapper that checks if AI is still valid before restoring state.
func _restore_ai_state_safe() -> void:
	if is_instance_valid(ai) and not is_dying:
		ai.restore_default_state()

## Venom stacks made visible: one pip per stack under the health bar (the stack count is a real
## damage multiplier, so it deserves a readout). Lazy-created; text only changes when the count does.
func _update_stack_pips() -> void:
	var manager = get_node_or_null("StatusEffectManager")
	if manager == null:
		return
	var count: int = 0
	for status_id in manager.active_statuses:
		var effect = manager.active_statuses[status_id]["effect"]
		if "stacks" in effect and effect.max_stacks > 1:
			count = maxi(count, effect.stacks)
	if count == _last_stack_count:
		return
	_last_stack_count = count
	if _stack_pips == null:
		if count == 0:
			return
		_stack_pips = Label.new()
		_stack_pips.modulate = Color(0.5, 1.0, 0.4, 0.95)
		_stack_pips.add_theme_font_size_override("font_size", 11)
		_stack_pips.position = health_bar.position + Vector2(0, health_bar.size.y + 1.0)
		add_child(_stack_pips)
	_stack_pips.text = "*".repeat(count)
	_stack_pips.visible = count > 0

## Updates the health bar's visual state.
func update_health_bar(current: int, max_val: int) -> void:
	health_bar.max_value = max_val
	health_bar.value = current
	# Show once damaged -- unless health bars are turned off for performance.
	health_bar.visible = current < max_val and GameSettings.show_health_bars
	
# --- Signal Callbacks ---

func _on_screen_entered() -> void:
	is_on_screen = true
	# Resume animations when visible
	if is_instance_valid(animated_sprite):
		animated_sprite.speed_scale = 1.0

func _on_screen_exited() -> void:
	is_on_screen = false
	# Pause animations when off-screen (saves CPU/GPU)
	if is_instance_valid(animated_sprite):
		animated_sprite.speed_scale = 0.0

## Resets the contact damage cooldown.
func _on_damage_cooldown_timer_timeout() -> void:
	can_deal_damage = true
