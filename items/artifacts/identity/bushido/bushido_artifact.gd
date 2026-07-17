## bushido_artifact.gd -- Samurai's identity: the MOMENTUM edge.
## Each kill grants flat base crit for a rolling window; the bonus fades when kills stop.
## (Replaced the permanent kill-accumulator, which by mid-run was just a stat card. The rolling
## window makes the bonus depend on recent kills, so it drops against bosses and armored tanks --
## the designed weakness.)
##
## PERF: no Timer nodes, no per-stack allocations (kills are hot -- 10+/sec late game). Stacks are
## expiry timestamps on a GAME-time clock (physics-delta accumulation; wall time would let stacks
## expire during the level-up pause). Appends are inherently in sorted order, so pruning just
## advances a head index lazily at read time: amortized O(1), zero idle cost.
extends ArtifactBase

@export var crit_per_stack: float = 0.01   # +1% flat base crit per live kill
@export var window_seconds: float = 10.0   # how long one kill keeps its edge
@export var max_stacks: int = 50           # playtest dial; at blender kill rates this IS the value

var _clock: float = 0.0
var _expiries: Array[float] = []
var _head: int = 0

func _physics_process(delta: float) -> void:
	_clock += delta

func on_equipped() -> void:
	if not Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.connect(_on_kill)

func on_unequipped() -> void:
	if Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.disconnect(_on_kill)

func _on_kill(_enemy_node: Node) -> void:
	if _stack_count() >= max_stacks:
		_head += 1  # at cap a new kill REFRESHES momentum: drop the oldest, append the newest
	_expiries.append(_clock + window_seconds)
	# No notify_stats_changed here: crit is read live at fire time, and per-kill notifies would
	# ping the UI refresh machinery 10+ times a second for nothing.

func _stack_count() -> int:
	while _head < _expiries.size() and _expiries[_head] <= _clock:
		_head += 1
	if _head > 256:  # occasional compaction so the array doesn't grow for the whole run
		_expiries = _expiries.slice(_head)
		_head = 0
	return _expiries.size() - _head

## The universal flat layer, read via Player.get_stat("crit_flat"): momentum as base crit that
## reaches EVERY damage source -- at full edge, even poison ticks crit.
func get_crit_flat_bonus() -> float:
	return crit_per_stack * _stack_count()
