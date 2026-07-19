## crackle_zone.gd -- the Storm Eel's wake: a short-lived patch that pulses damage to the player.
extends Node2D

var radius: float = 70.0
var damage: int = 8
var duration: float = 3.0
var tick_every: float = 0.5

var _t: float = 0.0
var _tick: float = 0.0

func _ready() -> void:
	add_to_group("crackle_zone")

func _physics_process(delta: float) -> void:
	_t += delta
	_tick -= delta
	if _t >= duration:
		queue_free()
		return
	if _tick <= 0.0:
		_tick = tick_every
		var player = get_tree().get_first_node_in_group("player")
		if is_instance_valid(player) \
				and player.global_position.distance_to(global_position) <= radius:
			player.take_damage(damage, 0.0, false, null)
