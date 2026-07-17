## dot_status_effect.gd
## A specialized status effect that deals damage over time and can apply additional statuses.
class_name DotStatusEffect
extends StatusEffect

# --- Properties ---
@export var damage_per_tick: float = 2.0
@export var time_between_ticks: float = 1.0
@export_range(0.0, 1.0) var additional_status_chance: float = 0.0
@export var additional_status_effect: StatusEffect

# --- Runtime variables used by the manager ---
var tick_timer: float = 0.0

func _init():
	# DoT effects need per-frame processing for tick timers
	needs_processing = true

# --- Overridden Functions ---
## Called once when Burning is first applied.
func on_apply(manager: StatusEffectManager, source):
	# Apply the first tick of damage immediately.
	_do_damage_tick(manager, source)
	# Reset the tick timer.
	var time_multiplier = 1
	if is_instance_valid(source):
		time_multiplier = source.get_stat("dot_damage_tick_rate")
	tick_timer = time_between_ticks * time_multiplier

## Called every frame.
func on_process(manager: StatusEffectManager, delta: float, source):
	tick_timer -= delta
	if tick_timer <= 0:
		_do_damage_tick(manager, source)
		# Reset the timer for the next tick.
		var time_multiplier = 1
		if is_instance_valid(source):
			time_multiplier = source.get_stat("dot_damage_tick_rate")
		tick_timer = time_between_ticks * time_multiplier

## The weapon (or artifact) whose hit applied this status -- stamped by StatusEffectManager at
## application so ticks credit the right row in the damage report.
var attribution_key: String = ""

## Helper function to apply damage and check for ignite.
func _do_damage_tick(manager: StatusEffectManager, source):
	var host = manager.get_parent()
	if host.has_method("take_damage"):
		var damage_multiplier = 1.0
		if is_instance_valid(source):
			damage_multiplier = source.get_stat("dot_damage_bonus")

		# Universal crit (July 2026): ticks have ZERO base crit, so only a player's flat crit
		# layer (x crit cards) can make them crit -- the crit-status build enabler. Enemy-sourced
		# statuses compose to rate 0 and never crit.
		var crit: Dictionary = DamageUtils.compose_crit(0.0, 0.5, source)
		var rolled: Dictionary = DamageUtils.roll_crit(
			damage_per_tick * damage_multiplier, crit.rate, crit.mult)
		# Tick attribution happens HERE (take_damage sees a null source and skips crediting):
		# 100% pen means the post-armor result is exactly the rolled tick.
		CurrentRun.credit_damage(
			attribution_key if attribution_key != "" else "Other", rolled.damage)
		# 100% armor pen.
		host.take_damage(rolled.damage, 1, rolled.is_crit)
		
		# Handle Ignite chance.
		var status_chance_mult = 1.0
		if is_instance_valid(source):
			status_chance_mult = source.get_stat("status_chance_bonus")

		if additional_status_chance > 0 and randf() < (additional_status_chance * status_chance_mult):
			if additional_status_effect:
				# Escalations (burn -> ignite) keep crediting the weapon that started the chain.
				manager.apply_status(additional_status_effect, source, attribution_key)
