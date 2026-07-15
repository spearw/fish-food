## weapon.gd
## A generic weapon data container. All logic is in its components.
class_name Weapon
extends Node2D

# --- Data ---
@export var projectile_stats: ProjectileStats
# This optionally overrides the generic projectile scene with a custom one.
@export var custom_projectile_scene: PackedScene
@export var base_projectile_count: int = 1
@export var base_fire_rate: float = 2

# --- DamageType Tags (weapon identity for synergies/artifacts) ---
@export var themes: Array[WeaponTags.DamageType] = []

# --- Effect Tags (weapon behaviors for counter-spawning) ---
@export var effects: Array[WeaponTags.Effect] = []

# --- Rarity (see docs/deck_and_synergy_design.md section 3) ---
## Damage multiplier per rarity tier, indexed by Upgrade.Rarity (COMMON..MYTHIC).
##
## Authored PER WEAPON on purpose, and the ratio between tiers is the real knob. Two copies in two
## slots do 2x damage, so a tier that multiplies by exactly 2 makes merging free (same damage, one
## slot back) while anything below 2 makes it a genuine trade: damage for a slot. The default is
## geometric at 1.8x, so merging always costs ~10% damage and always returns a slot.
##
## Brotato varies this per weapon rather than using one curve -- a Fist doubles every tier
## (8/16/32/64) while a Wrench crawls (12/16/20/24) -- which is what makes merging worth chasing on
## some weapons and not on others. A uniform curve would flatten that texture away.
@export var rarity_scaling: Array[float] = [1.0, 1.8, 3.2, 5.8, 10.5]

## This instance's rarity tier (an index into rarity_scaling). MUST be set before the weapon enters
## the tree -- _ready() bakes the scaling into this instance's stats. Merging raises it.
var rarity: int = 0

# --- State ---
var last_fire_direction: Vector2 = Vector2.RIGHT
var is_transformed: bool = false

# --- Component References ---
@onready var fire_behavior_component: FireBehaviorComponent = $FireBehaviorComponent
@onready var stats_component: WeaponStatsComponent = $WeaponStatsComponent
@onready var fire_rate_timer: Timer = $FireRateTimer
@onready var targeting_component: TargetingComponent = $TargetingComponent

func _ready():
	# Create unique instance for this weapon.
	projectile_stats = projectile_stats.duplicate(true)
	# Only now that the stats are this instance's own -- scaling the shared resource would leak this
	# weapon's rarity into every other copy in the game.
	_apply_rarity_scaling()
	if not fire_rate_timer.timeout.is_connected(_on_fire_rate_timer_timeout):
		fire_rate_timer.timeout.connect(_on_fire_rate_timer_timeout)

## This instance's damage multiplier for its rarity tier.
func get_rarity_multiplier() -> float:
	if rarity_scaling.is_empty():
		return 1.0
	return rarity_scaling[clampi(rarity, 0, rarity_scaling.size() - 1)]

## Bakes the rarity tier into this instance's damage. Callable only AFTER projectile_stats has been
## duplicated -- see _ready().
func _apply_rarity_scaling() -> void:
	var mult := get_rarity_multiplier()
	if not projectile_stats or is_equal_approx(mult, 1.0):
		return

	projectile_stats.damage = int(round(projectile_stats.damage * mult))

	# A damage-over-time weapon keeps most of its damage in the status it applies, not in
	# projectile_stats.damage -- a fire weapon's direct hit is the small half. Without scaling this
	# too, rarity would barely move a fire weapon and merging one would feel pointless.
	# duplicate(true) above deep-copies the status, so this stays per-instance.
	var status = projectile_stats.status_to_apply
	if status is DotStatusEffect:
		status.damage_per_tick *= mult

	# Connect to user's stats_changed signal when available (deferred to ensure stats_component is ready)
	call_deferred("_connect_to_user_stats")

func _connect_to_user_stats():
	var user = stats_component.user
	if is_instance_valid(user) and user.has_signal("stats_changed"):
		if not user.stats_changed.is_connected(update_stats):
			user.stats_changed.connect(update_stats)
		# Initial stats update
		update_stats()

# Update internal stats whenever the user's stats change.
func update_stats():
	var user = stats_component.user
	if not is_instance_valid(user): return

	# Get fire rate from the user
	var firerate_multiplier = user.get_stat("firerate")
	fire_rate_timer.wait_time = base_fire_rate * firerate_multiplier

func _on_fire_rate_timer_timeout():
	# Delegate the actual firing to the component.
	fire()

## Public method for manual firing (e.g., by enemy AI).
func fire(damage_multiplier=1):
	fire_behavior_component.fire(damage_multiplier)
	
## Set transformed flag to true. Specific types handle their own transformations.
func apply_transformation(id: String):
	is_transformed = true

## Reduces the remaining time on the FireRateTimer by a given amount.
func reduce_cooldown(amount: float):
	# Make sure the timer is actually running and not already ready to fire.
	if is_instance_valid(fire_rate_timer) and not fire_rate_timer.is_stopped():
		# Subtract the amount from the timer's remaining time.
		# The timer will automatically fire if time_left becomes <= 0.
		# Calculate the new remaining time.
		var new_time_left = fire_rate_timer.time_left - amount
		Logs.add_message(["Time left:", new_time_left])
		fire_rate_timer.start(max(0, new_time_left))
