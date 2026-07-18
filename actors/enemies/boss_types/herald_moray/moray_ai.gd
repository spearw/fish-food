## moray_ai.gd -- The Warden (herald): a movement-check boss.
## Cycle: chase -> telegraph (stops, flashes, locks your position) -> lunge along the locked line ->
## recover. Also summons garden eel adds on a timer. Scene-attached only (no class_name).
extends AIController

@export var chase_secs: float = 3.5
@export var telegraph_secs: float = 0.7
@export var lunge_speed: float = 950.0
@export var lunge_secs: float = 0.45
@export var recover_secs: float = 0.8
@export var summon_every: float = 15.0
@export var max_adds: int = 4
@export var summon_stats: EnemyStats

enum Mode { CHASE, TELEGRAPH, LUNGE, RECOVER }
var _mode: Mode = Mode.CHASE
var _t: float = 0.0
var _summon_t: float = 0.0
var _lunge_dir: Vector2 = Vector2.RIGHT
var _adds: Array = []
var _director: Node = null

func _ready():
	super._ready()
	_t = chase_secs
	_summon_t = summon_every * 0.5

func _physics_process(delta):
	if not is_instance_valid(host) or host.is_dying or not is_instance_valid(host.player_node):
		super._physics_process(delta)
		return

	_t -= delta
	match _mode:
		Mode.CHASE:
			set_state(states["chasebehavior"])
			if _t <= 0.0:
				_enter(Mode.TELEGRAPH, telegraph_secs)
				_flash_telegraph()
		Mode.TELEGRAPH:
			set_state(states["idlebehavior"])
			# The aim tracks until the lunge commits -- dodging is done during the lunge, not before.
			_lunge_dir = (host.player_node.global_position - host.global_position).normalized()
			if _t <= 0.0:
				_enter(Mode.LUNGE, lunge_secs)
		Mode.LUNGE:
			set_state(states["idlebehavior"])
			if _t <= 0.0:
				_enter(Mode.RECOVER, recover_secs)
		Mode.RECOVER:
			set_state(states["idlebehavior"])
			if _t <= 0.0:
				_enter(Mode.CHASE, chase_secs)

	_summon_t -= delta
	if _summon_t <= 0.0:
		_summon_t = summon_every
		_summon_adds()

	super._physics_process(delta)  # runs the current behavior (chase moves, idle zeroes velocity)

	# After the behavior ran, the lunge overwrites: full commit along the locked line.
	if _mode == Mode.LUNGE:
		host.velocity = _lunge_dir * lunge_speed

func _enter(mode: Mode, secs: float) -> void:
	_mode = mode
	_t = secs

## The tell: two quick white-hot pulses over the telegraph window.
func _flash_telegraph() -> void:
	var tween := host.create_tween()
	for i in range(2):
		tween.tween_property(host, "modulate", Color(2.2, 1.2, 1.2, 1.0), telegraph_secs * 0.25)
		tween.tween_property(host, "modulate", host.stats.modulate, telegraph_secs * 0.25)

## Spawns eel adds near the boss, through the director so they join the population ledger
## (adds are pressure, not free bodies -- the director thins its own top-up to pay for them).
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
	for i in range(2):
		var offset := Vector2.RIGHT.rotated(randf_range(0, TAU)) * randf_range(80.0, 140.0)
		_adds.append(_director.spawn_enemy(summon_stats, host.global_position + offset))
