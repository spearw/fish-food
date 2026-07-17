## riposte_volley_artifact.gd -- combo synergy (Melee + Projectile): getting hit answers with a
## burst of three darts at the attacker. Every wound is a reload.
extends ArtifactBase

const DART_STATS := preload("res://items/artifacts/combos/melee_projectile/riposte_dart_stats.tres")
const PROJECTILE_SCENE := preload("res://systems/projectiles/projectile.tscn")

@export var dart_count: int = 3
@export var spread_radians: float = 0.35

func on_equipped() -> void:
	if not Events.player_was_hit.is_connected(_on_player_hit):
		Events.player_was_hit.connect(_on_player_hit)

func on_unequipped() -> void:
	if Events.player_was_hit.is_connected(_on_player_hit):
		Events.player_was_hit.disconnect(_on_player_hit)

func _on_player_hit(source_node: Node) -> void:
	if not is_instance_valid(user) or not is_instance_valid(source_node) \
			or not source_node is Node2D:
		return
	var base_dir: Vector2 = (source_node.global_position - user.global_position).normalized()
	for i in range(dart_count):
		var projectile = ProjectilePool.get_projectile(PROJECTILE_SCENE)
		if projectile == null:
			return
		var from_pool: bool = projectile._is_pooled if projectile.get("_is_pooled") != null else false
		projectile.stats = DART_STATS
		projectile.direction = base_dir.rotated(spread_radians * (i - (dart_count - 1) / 2.0))
		projectile.allegiance = Projectile.Allegiance.PLAYER
		projectile.weapon = null
		projectile.user = user
		projectile.attribution_key = "Riposte Volley"
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = user.global_position + projectile.direction * 24.0
		projectile.rotation = projectile.direction.angle()
		if from_pool and projectile.has_method("activate"):
			projectile.activate()
		elif not from_pool:
			projectile._is_pooled = true
