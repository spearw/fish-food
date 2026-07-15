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
	# Make every stats resource this weapon owns unique to this instance FIRST. They're shared assets,
	# so touching one in place would leak this weapon's rarity into every other copy in the game.
	for prop_name in _own_stats_properties():
		set(prop_name, get(prop_name).duplicate(true))
	_apply_rarity_scaling()
	if not fire_rate_timer.timeout.is_connected(_on_fire_rate_timer_timeout):
		fire_rate_timer.timeout.connect(_on_fire_rate_timer_timeout)

## The names of every ProjectileStats this weapon exports.
##
## Not just projectile_stats: a hammer exports shockwave_stats and the fireball staff exports
## wall_of_fire_stats, and both carry their own damage. Finding them by type means a new weapon with a
## new stats export is localized and scaled automatically, rather than silently sharing a resource (a
## leak) or silently ignoring rarity until someone benches it.
func _own_stats_properties() -> Array:
	var out: Array = []
	for prop in get_property_list():
		if prop["type"] != TYPE_OBJECT:
			continue
		if get(prop["name"]) is ProjectileStats:
			out.append(prop["name"])
	return out

## This instance's damage multiplier for its rarity tier.
func get_rarity_multiplier() -> float:
	if rarity_scaling.is_empty():
		return 1.0
	return rarity_scaling[clampi(rarity, 0, rarity_scaling.size() - 1)]

## Every damage source this weapon owns, as {damage, armor_pen, dot} -- walking nested stats
## (on-death explosions, trails, shockwaves) the same way rarity scaling does.
##
## This is the weapon's armor fingerprint. The encounter director reads it to decide whether an
## armored enemy is literally undamageable by the current build (see EncounterDirector.max_walled_share).
## Reads the live per-instance stats, so rarity tiers and transformations are reflected.
func get_damage_sources() -> Array:
	var out: Array = []
	var seen: Array = []
	for prop_name in _own_stats_properties():
		_collect_damage_sources(get(prop_name), out, seen)
	return out

func _collect_damage_sources(stats, out: Array, seen: Array) -> void:
	if stats == null or stats in seen:
		return
	seen.append(stats)
	var status = stats.status_to_apply if "status_to_apply" in stats else null
	out.append({
		"damage": float(stats.damage) if "damage" in stats else 0.0,
		"armor_pen": float(stats.armor_penetration) if "armor_penetration" in stats else 0.0,
		"dot": status is DotStatusEffect,
	})
	for prop in stats.get_property_list():
		if prop["type"] != TYPE_OBJECT:
			continue
		var value = stats.get(prop["name"])
		if value is ProjectileStats:
			_collect_damage_sources(value, out, seen)

## Bakes the rarity tier into every damage source this weapon owns. Callable only AFTER the stats have
## been localized -- see _ready().
func _apply_rarity_scaling() -> void:
	var mult := get_rarity_multiplier()
	if is_equal_approx(mult, 1.0):
		return
	var seen: Array = []
	for prop_name in _own_stats_properties():
		_scale_stats_tree(get(prop_name), mult, seen)

## Scales every damage source in a stats tree.
##
## A weapon does NOT keep its damage in one place, and assuming it does is how rarity silently stopped
## working: the fireball staff's projectile_stats.damage is 10, but its on-death explosion is a NESTED
## stats resource doing 25 -- the bigger half. Scaling only the root moved a third of the weapon and a
## unit test that checked the root passed anyway.
##
## `seen` guards against scaling a shared sub-resource twice (the fireball and its explosion both point
## at burning.tres) and against cycles.
func _scale_stats_tree(stats, mult: float, seen: Array) -> void:
	if stats == null or stats in seen:
		return
	seen.append(stats)

	if "damage" in stats:
		stats.damage = int(round(stats.damage * mult))

	# DoT keeps its damage in the status it applies, not in .damage -- a fire weapon's direct hit is
	# the small half, and it's the DoT that ignores armor.
	var status = stats.status_to_apply if "status_to_apply" in stats else null
	if status is DotStatusEffect and not status in seen:
		seen.append(status)
		status.damage_per_tick *= mult

	# Nested stats carry their own damage: on-death explosions, trails, shockwaves.
	for prop in stats.get_property_list():
		if prop["type"] != TYPE_OBJECT:
			continue
		var value = stats.get(prop["name"])
		if value is ProjectileStats:
			_scale_stats_tree(value, mult, seen)

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
