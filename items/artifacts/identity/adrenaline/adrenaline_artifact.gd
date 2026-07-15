## adrenaline_artifact.gd
## Edgerunner's identity artifact: kills surge her speed. Every kill triggers (or refreshes) a short
## burst of move speed -- momentum as a mechanic, staying fast means staying deadly.
extends ArtifactBase

@export var speed_bonus: float = 0.35
@export var duration: float = 2.0

var _burst_timer: Timer

func _ready() -> void:
	_burst_timer = Timer.new()
	_burst_timer.one_shot = true
	_burst_timer.timeout.connect(_on_burst_ended)
	add_child(_burst_timer)

func on_equipped() -> void:
	if not Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.connect(_on_kill)

func on_unequipped() -> void:
	if Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.disconnect(_on_kill)

func _on_kill(_enemy_node: Node) -> void:
	var was_idle := _burst_timer.is_stopped()
	_burst_timer.start(duration)
	# Speed is cached on the player; only poke it when the modifier actually changes state.
	if was_idle and is_instance_valid(user) and user.has_method("notify_stats_changed"):
		user.notify_stats_changed()

func _on_burst_ended() -> void:
	if is_instance_valid(user) and user.has_method("notify_stats_changed"):
		user.notify_stats_changed()

func get_speed_modifier() -> float:
	if _burst_timer and not _burst_timer.is_stopped():
		return 1.0 + speed_bonus
	return 1.0
