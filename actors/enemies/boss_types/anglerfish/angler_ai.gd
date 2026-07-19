## angler_ai.gd -- The Anglerfish: the secret boss found by its own false light.
## The meanest lunge cycle in the game (you sought this fight out), plus waves of invisi jellies
## from the dark. No phases, no mercy; the darkness overlay is handled by the world.
extends AIController

@export var chase_secs: float = 2.5
@export var telegraph_secs: float = 0.5
@export var lunge_speed: float = 1050.0
@export var lunge_secs: float = 0.4
@export var recover_secs: float = 0.6
@export var summon_every: float = 12.0
@export var max_adds: int = 6
@export var adds_per_wave: int = 3
@export var summon_stats: EnemyStats

enum Mode { CHASE, TELEGRAPH, LUNGE, RECOVER }
var _mode: Mode = Mode.CHASE
var _t: float = 0.0
var _summon_t: float = 4.0
var _lunge_dir: Vector2 = Vector2.RIGHT
var _adds: Array = []
var _director: Node = null

func _ready():
	super._ready()
	_t = chase_secs

func _physics_process(delta):
	if not is_instance_valid(host) or host.is_dying or not is_instance_valid(host.player_node):
		super._physics_process(delta)
		return

	_t -= delta
	match _mode:
		Mode.CHASE:
			set_state(states["chasebehavior"])
			if _t <= 0.0:
				_mode = Mode.TELEGRAPH
				_t = telegraph_secs
				_flash()
		Mode.TELEGRAPH:
			set_state(states["idlebehavior"])
			_lunge_dir = (host.player_node.global_position - host.global_position).normalized()
			if _t <= 0.0:
				_mode = Mode.LUNGE
				_t = lunge_secs
		Mode.LUNGE:
			set_state(states["idlebehavior"])
			if _t <= 0.0:
				_mode = Mode.RECOVER
				_t = recover_secs
		Mode.RECOVER:
			set_state(states["idlebehavior"])
			if _t <= 0.0:
				_mode = Mode.CHASE
				_t = chase_secs

	_summon_t -= delta
	if _summon_t <= 0.0:
		_summon_t = summon_every
		_summon_adds()

	super._physics_process(delta)
	if _mode == Mode.LUNGE:
		host.velocity = _lunge_dir * lunge_speed

## Invisi jellies out of the dark, through the director so they join the population ledger.
func _summon_adds() -> void:
	if summon_stats == null:
		return
	_adds = _adds.filter(func(a): return is_instance_valid(a) and not a.is_dying)
	if _adds.size() >= max_adds:
		return
	if _director == null or not is_instance_valid(_director):
		_director = host.get_tree().current_scene.find_child("EncounterDirector", true, false)
	if _director == null:
		return
	for i in range(adds_per_wave):
		var offset := Vector2.RIGHT.rotated(randf_range(0, TAU)) * randf_range(120.0, 220.0)
		_adds.append(_director.spawn_enemy(summon_stats, host.global_position + offset))

func _flash() -> void:
	var tween := host.create_tween()
	tween.tween_property(host, "modulate", Color(2.0, 1.6, 1.1, 1.0), telegraph_secs * 0.4)
	tween.tween_property(host, "modulate", host.stats.modulate, telegraph_secs * 0.4)
