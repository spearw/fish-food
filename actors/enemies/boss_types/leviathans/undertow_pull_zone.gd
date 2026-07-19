## undertow_pull_zone.gd -- The Undertow's swallow: a zone that drags the PLAYER toward its center.
## The pull trick from SingularityZone: apply_knockback pushes AWAY from `from`, so pulling toward
## the center means passing the player's own position reflected through it.
extends Node2D

var pull_radius: float = 240.0
var pull_force: float = 130.0
var duration: float = 3.5

var _t: float = 0.0

func _ready() -> void:
	add_to_group("pull_zone")

func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) \
			and player.global_position.distance_to(global_position) <= pull_radius:
		player.apply_knockback(pull_force, player.global_position * 2.0 - global_position)
