## septic_burst_artifact.gd -- combo synergy (Projectile + Venom): POISONED enemies that die
## burst into three venom darts.
extends ArtifactBase

const DART_STATS := preload("res://items/artifacts/combos/projectile_venom/septic_dart_stats.tres")
const PROJECTILE_SCENE := preload("res://systems/projectiles/projectile.tscn")

@export var burst_chance: float = 0.5
@export var dart_count: int = 3

func on_equipped() -> void:
	if not Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.connect(_on_kill)

func on_unequipped() -> void:
	if Events.enemy_killed.is_connected(_on_kill):
		Events.enemy_killed.disconnect(_on_kill)

func _on_kill(enemy_node: Node) -> void:
	if not is_instance_valid(enemy_node) or randf() > burst_chance:
		return
	var mgr = enemy_node.get_node_or_null("StatusEffectManager")
	if mgr == null or not mgr.active_statuses.has("poison"):
		return
	var origin: Vector2 = enemy_node.global_position
	for i in range(dart_count):
		var projectile = ProjectilePool.get_projectile(PROJECTILE_SCENE)
		if projectile == null:
			return
		var from_pool: bool = projectile._is_pooled if projectile.get("_is_pooled") != null else false
		projectile.stats = DART_STATS
		projectile.direction = Vector2.from_angle(TAU * i / dart_count + randf() * 0.5)
		projectile.allegiance = Projectile.Allegiance.PLAYER
		projectile.weapon = null
		projectile.user = user
		projectile.attribution_key = "Septic Burst"
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = origin + projectile.direction * 16.0
		projectile.rotation = projectile.direction.angle()
		if from_pool and projectile.has_method("activate"):
			projectile.activate()
		elif not from_pool:
			projectile._is_pooled = true
