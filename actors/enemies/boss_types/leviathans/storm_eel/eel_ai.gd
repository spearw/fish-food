## eel_ai.gd -- The Storm Eel: the movement exam.
## Cycle: pursue, telegraph, then a CHAIN of retargeting lunges that leave crackling wake zones,
## capped with a radial discharge. Below one third the chain grows by a lunge. Fastest leviathan,
## least HP; it punishes builds that cannot reposition.
extends "res://actors/enemies/boss_types/leviathans/leviathan_ai_base.gd"

@export var drift_secs: float = 3.0
@export var telegraph_secs: float = 0.5
@export var lunge_speed: float = 1000.0
@export var lunge_secs: float = 0.32
@export var base_chain: int = 3
@export var recover_secs: float = 1.0
@export var wake_every: float = 0.15

const CRACKLE_ZONE := preload("res://actors/enemies/boss_types/leviathans/crackle_zone.tscn")

enum Mode { DRIFT, TELEGRAPH, LUNGE, RECOVER }
var _mode: Mode = Mode.DRIFT
var _t: float = 0.0
var _lunges_left: int = 0
var _lunge_dir: Vector2 = Vector2.RIGHT
var _wake_t: float = 0.0

func _ready():
	super._ready()
	_t = drift_secs

func _physics_process(delta):
	if not is_instance_valid(host) or host.is_dying or not is_instance_valid(host.player_node):
		super._physics_process(delta)
		return
	_update_phase()

	_t -= delta
	match _mode:
		Mode.DRIFT:
			set_state(states["chasebehavior"])
			if _t <= 0.0:
				_mode = Mode.TELEGRAPH
				_t = telegraph_secs * telegraph_scale
				_lunges_left = base_chain + (1 if _phase >= 2 else 0)
				_flash()
		Mode.TELEGRAPH:
			set_state(states["idlebehavior"])
			_lunge_dir = (host.player_node.global_position - host.global_position).normalized()
			if _t <= 0.0:
				_mode = Mode.LUNGE
				_t = lunge_secs
		Mode.LUNGE:
			set_state(states["idlebehavior"])
			_wake_t -= delta
			if _wake_t <= 0.0:
				_wake_t = wake_every
				_drop_wake()
			if _t <= 0.0:
				_lunges_left -= 1
				if _lunges_left > 0:
					# Retarget between lunges: the chain hunts, it doesn't repeat itself.
					_lunge_dir = (host.player_node.global_position - host.global_position).normalized()
					_t = lunge_secs
				else:
					fire_named("DischargeNovaWeapon")
					_after_attack()
					_mode = Mode.RECOVER
					_t = recover_secs
		Mode.RECOVER:
			set_state(states["idlebehavior"])
			if _t <= 0.0:
				_mode = Mode.DRIFT
				_t = drift_secs

	super._physics_process(delta)
	if _mode == Mode.LUNGE:
		host.velocity = _lunge_dir * lunge_speed

func _drop_wake() -> void:
	var zone := CRACKLE_ZONE.instantiate()
	host.get_tree().current_scene.add_child(zone)
	zone.global_position = host.global_position

func _flash() -> void:
	var tween := host.create_tween()
	tween.tween_property(host, "modulate", Color(1.4, 1.8, 2.4, 1.0), telegraph_secs * 0.4)
	tween.tween_property(host, "modulate", host.stats.modulate, telegraph_secs * 0.4)
