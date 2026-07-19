## undertow_ai.gd -- The Undertow: the space-control exam.
## Always: slow pursuit and wide telegraphed tidal charges. Below two thirds: aimed maw slams.
## Below one third: the swallow -- a warned pull zone dropped under the player's feet.
extends "res://actors/enemies/boss_types/leviathans/leviathan_ai_base.gd"

@export var chase_secs: float = 4.5
@export var telegraph_secs: float = 0.9
@export var charge_speed: float = 700.0
@export var charge_secs: float = 0.6
@export var recover_secs: float = 1.0
@export var slam_every: float = 5.0
@export var pull_every: float = 8.0
@export var pull_warning_secs: float = 0.8

const PULL_ZONE := preload("res://actors/enemies/boss_types/leviathans/undertow_pull_zone.tscn")
const WARNING := preload("res://items/effects/warning_indicator/warning_indicator.tscn")

enum Mode { CHASE, TELEGRAPH, CHARGE, RECOVER }
var _mode: Mode = Mode.CHASE
var _t: float = 0.0
var _slam_t: float = 0.0
var _pull_t: float = 0.0
var _charge_dir: Vector2 = Vector2.RIGHT

func _ready():
	super._ready()
	_t = chase_secs
	_slam_t = slam_every * 0.5
	_pull_t = pull_every * 0.5

func _physics_process(delta):
	if not is_instance_valid(host) or host.is_dying or not is_instance_valid(host.player_node):
		super._physics_process(delta)
		return
	_update_phase()

	_t -= delta
	match _mode:
		Mode.CHASE:
			set_state(states["chasebehavior"])
			if _t <= 0.0:
				_mode = Mode.TELEGRAPH
				_t = telegraph_secs * telegraph_scale
				_flash()
		Mode.TELEGRAPH:
			set_state(states["idlebehavior"])
			_charge_dir = (host.player_node.global_position - host.global_position).normalized()
			if _t <= 0.0:
				_mode = Mode.CHARGE
				_t = charge_secs
		Mode.CHARGE:
			set_state(states["idlebehavior"])
			if _t <= 0.0:
				_mode = Mode.RECOVER
				_t = recover_secs
				_after_attack()
		Mode.RECOVER:
			set_state(states["idlebehavior"])
			if _t <= 0.0:
				_mode = Mode.CHASE
				_t = chase_secs

	# The slam and the swallow run on their own clocks, gated by phase.
	if _phase >= 1:
		_slam_t -= delta
		if _slam_t <= 0.0:
			_slam_t = slam_every
			fire_named("MawSlamWeapon")
			_after_attack()
	if _phase >= 2:
		_pull_t -= delta
		if _pull_t <= 0.0:
			_pull_t = pull_every
			_drop_swallow()

	super._physics_process(delta)
	if _mode == Mode.CHARGE:
		host.velocity = _charge_dir * charge_speed

## Warns at the player's position, then opens the pull there.
func _drop_swallow() -> void:
	var at: Vector2 = host.player_node.global_position
	var scene := host.get_tree().current_scene
	var warning := WARNING.instantiate()
	scene.add_child(warning)
	warning.global_position = at
	var timer := host.get_tree().create_timer(pull_warning_secs * telegraph_scale)
	timer.timeout.connect(func():
		if not is_instance_valid(scene):
			return
		var zone := PULL_ZONE.instantiate()
		scene.add_child(zone)
		zone.global_position = at)

func _flash() -> void:
	var tween := host.create_tween()
	tween.tween_property(host, "modulate", Color(1.6, 1.6, 2.2, 1.0), telegraph_secs * 0.4)
	tween.tween_property(host, "modulate", host.stats.modulate, telegraph_secs * 0.4)
