## skyfall_artifact.gd -- Cosmic deck: your kills have a chance to call a small cosmic burst down
## on another enemy nearby. The sky answers momentum.
extends ArtifactBase

const EXPLOSION_SCENE := preload("res://systems/projectiles/explosion/explosion_effect.tscn")

@export var call_chance: float = 0.15
@export var burst_damage: int = 20
@export var search_radius: float = 300.0

func on_equipped() -> void:
	if not Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.connect(_on_kill)

func on_unequipped() -> void:
	if Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.disconnect(_on_kill)

func _on_kill(enemy_node: Node) -> void:
	if not is_instance_valid(enemy_node) or randf() > call_chance:
		return
	var near: Array = EntityRegistry.get_candidates_near(
		"enemies", enemy_node.global_position, search_radius)
	var target: Node2D = null
	for e in near:
		if is_instance_valid(e) and e != enemy_node:
			target = e
			break
	if target == null:
		return
	var explosion_stats = ExplosionStats.new()
	explosion_stats.damage = burst_damage
	explosion_stats.scale = Vector2(3.0, 3.0)
	explosion_stats.modulation = Color(0.85, 0.9, 1.0, 0.85)
	explosion_stats.effect_duration = 0.3
	var explosion = EXPLOSION_SCENE.instantiate()
	explosion.stats = explosion_stats
	explosion.allegiance = Projectile.Allegiance.PLAYER
	explosion.user = user
	explosion.attribution_key = "Skyfall"
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = target.global_position
