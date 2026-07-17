## toxic_wake_artifact.gd -- Venom deck: you leave a poisonous wake as you swim. The deck's
## kiting identity (it carries the Speed cards) made literal: movement becomes offense.
## PERF: one zone per wake_spacing pixels of actual movement, short-lived -- a handful alive at
## once, and standing still spawns nothing.
extends ArtifactBase

const WAKE_STATS := preload("res://items/artifacts/venom/toxic_wake/wake_zone_stats.tres")
const ZONE_SCENE := preload("res://items/effects/persistent_damage_effect.tscn")

@export var wake_spacing: float = 48.0

var _last_drop: Vector2 = Vector2.INF

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(user):
		return
	if _last_drop == Vector2.INF:
		_last_drop = user.global_position
		return
	if user.global_position.distance_to(_last_drop) < wake_spacing:
		return
	_last_drop = user.global_position
	var zone = ZONE_SCENE.instantiate()
	zone.stats = WAKE_STATS
	zone.allegiance = Projectile.Allegiance.PLAYER
	zone.user = user
	zone.attribution_key = "Toxic Wake"
	get_tree().current_scene.add_child(zone)
	zone.global_position = user.global_position
