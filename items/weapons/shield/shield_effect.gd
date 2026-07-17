## shield_effect.gd
## Represents the physical shield entity. Manages its own durability (pierce).
extends Node2D

## Damage-report identity, set by FireBehaviorComponent like any projectile.
var attribution_key: String = ""

# --- Properties set by the ShieldWeapon ---
var stats: ProjectileStats
var can_block_projectiles: bool = false
var current_durability: int = 0
var hit_targets: Array = [] # Prevents hitting the same enemy multiple times with one shield
var cooldown_timer: Timer # Timer to prevent rapid-fire hits from the same enemy

# --- Component References ---
@onready var hitbox: Area2D = $Hitbox

func _ready():
	# Initialize durability from stats
	current_durability = stats.pierce + 1 if stats.pierce != -1 else -1
	
	# Ensure masks are correct
	self.hitbox.collision_mask = 1 << 1 # Enemy mask
	if can_block_projectiles:
		# Add enemy projectile mask
		self.hitbox.collision_mask |= (1 << 4) 
	
	# Connect signals for blocking melee and (later) projectiles
	hitbox.body_entered.connect(_on_body_entered)
	if can_block_projectiles:
		hitbox.area_entered.connect(_on_area_entered)
	
	# Create a cooldown timer to prevent a single enemy from draining the shield instantly
	cooldown_timer = Timer.new()
	cooldown_timer.wait_time = 0.01 # An enemy can only damage the shield once every 0.01s
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)
	add_child(cooldown_timer)


## Blocks melee enemies
func _on_body_entered(body: Node2D):
	# Don't hit targets already on cooldown
	if hit_targets.has(body):
		return
		
	if body.is_in_group("enemies"):
		# Add enemy to the cooldown list and start the timer
		hit_targets.append(body)
		cooldown_timer.start()

		# Apply Shield Bash damage if it's enabled
		if stats.damage > 0 and body.has_method("take_damage"):
			# For now, enemies cannot crit
			var is_crit = false
			body.take_damage(stats.damage, stats.armor_penetration, is_crit, self)
		
		# Always apply knockback
		if body.has_method("apply_knockback"):
			body.apply_knockback(stats.knockback_force, global_position)
		
		# The shield takes 1 point of "damage"
		_take_shield_damage()

## Blocks ranged attacks (only active with Tower Shield upgrade)
func _on_area_entered(area: Area2D):
	if area.is_in_group("enemy_projectiles"):
		area.queue_free() # Destroy the projectile
		_take_shield_damage()

## Called when the cooldown for an enemy is over
func _on_cooldown_timer_timeout():
	if not hit_targets.is_empty():
		hit_targets.pop_front()

## Reduces the shield's durability and handles breaking.
func _take_shield_damage():
	if stats.pierce != -1: # -1 is infinite
		stats.pierce -= 1
		Logs.add_message(["Shield durability: ", stats.pierce])
		# TODO: call the AnimationPlayer to show visual cracks.
		
		if stats.pierce <= 0:
			Logs.add_message(["Shield broke!"])
			queue_free()
