## anglerfish_lure.gd -- the false chest. It reads as treasure from across the dark; walk up and
## the light turns out to be dangling from something large. Emits `touched` once when the player
## comes close; the director owns what happens next.
extends Node2D

signal touched

@export var trigger_radius: float = 130.0

var _triggered: bool = false

func _ready() -> void:
	add_to_group("anglerfish_lure")
	# The glow breathes -- close enough to a pickup shimmer to sell the lie.
	var tween := create_tween().set_loops()
	tween.tween_property($Glow, "modulate:a", 0.35, 0.9)
	tween.tween_property($Glow, "modulate:a", 0.8, 0.9)

func _physics_process(_delta: float) -> void:
	if _triggered:
		return
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) \
			and player.global_position.distance_to(global_position) <= trigger_radius:
		_triggered = true
		touched.emit()
