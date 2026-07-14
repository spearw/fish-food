extends Node
## Spark stress probe (lives on the SceneTree root; survives the change into world.tscn).
## Boots a real run, immortalizes the player, disables the director, force-spawns a fixed enemy
## field, then DIRECTLY spawns and sustains a live population of real spark projectiles (bouncing
## between the enemies) so the full spark runtime is exercised: movement, Area2D collision, and the
## bounce-retargeting that used to be O(sparks x enemies) before the spatial-hash fix. Measures real
## wall-clock frame time at the target spark load. spark_target=0 gives the enemies-only baseline.
##
## This is the spark verification that never actually ran: the daggers ship with CRIT_BOOST +
## fire-rate (not SPARK), so every earlier benchmark had sparks=0.

var count := 150          # enemy field size (bounce-target candidates)
var spark_target := 250   # live sparks to sustain (0 = baseline). 300 is the pool's hard cap.
var spark_bounces := 6
var spark_lifetime := 1.0
var suppress_dmgnums := false  # if true, block damage-number spawns to isolate pure spark cost

var _spawned := false
var _boot_frames := 0
var _warm := 0
var _n := 0
var _last_us := 0
var _frame_us := 0.0
var _spark_peak := 0
var _player: Node = null
var _dir: Node = null

const WARMUP := 90
const MEASURE := 150
const BOOT_TIMEOUT := 1500
const SPARK_RANGE := 250.0
const MAX_SPAWN_PER_FRAME := 25  # smooth the ramp toward spark_target

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

func _process(_dt: float) -> void:
	get_tree().paused = false  # the run hands out a level-up that pauses; keep it running

	if not _spawned:
		_boot_frames += 1
		if _boot_frames > BOOT_TIMEOUT:
			print("SPARKBENCH ERROR: world/player never became ready")
			get_tree().quit()
			return
		var scene := get_tree().current_scene
		if scene == null:
			return
		_player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(_player):
			return
		if _player.has_signal("leveled_up"):
			for c in _player.leveled_up.get_connections():
				_player.leveled_up.disconnect(c.callable)
		_boost(_player)
		if "collision_layer" in _player:
			_player.collision_layer = 0
		_dir = scene.find_child("EncounterDirector", true, false)
		if _dir:
			_dir.set_physics_process(false)
			var t = _dir.get_node_or_null("Timer")
			if t:
				t.stop()
			if _dir.has_method("debug_spawn"):
				_dir.debug_spawn(count)
		_spawned = true
		return

	# Keep the player alive, and make the enemy field IMMORTAL so sparks can't kill it. This isolates
	# pure spark cost: no deaths means no XP-orb / loot pile-up and no spawn churn confounding the
	# measurement (a stationary bench player never magnets the orbs, so kills would flood the scene).
	if is_instance_valid(_player) and "current_health" in _player:
		_player.current_health = 1000000000
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and "current_health" in e:
			e.current_health = 1000000000

	# Optionally block damage-number spawns (pin the pool "full") to isolate pure spark cost.
	if suppress_dmgnums:
		DamageNumberPool._active = 1000000

	# Sustain the live spark population toward spark_target.
	var deficit := spark_target - ProjectilePool._active_sparks
	var to_spawn: int = min(deficit, MAX_SPAWN_PER_FRAME)
	for i in range(to_spawn):
		_spawn_one_spark()

	if _warm < WARMUP:
		_warm += 1
		_last_us = Time.get_ticks_usec()
		return

	# Measure real wall-clock frame time; track the peak live spark count.
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		_frame_us += float(now - _last_us)
		_n += 1
	_last_us = now
	_spark_peak = max(_spark_peak, ProjectilePool._active_sparks)
	if _n >= MEASURE:
		var frame_ms := (_frame_us / float(_n)) / 1000.0
		var fps := 1000.0 / maxf(frame_ms, 0.001)
		var enemies := get_tree().get_nodes_in_group("enemies").size()
		var objs := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		print("SPARKBENCH enemies=%d spark_target=%d spark_peak=%d bounces=%d fps=%.0f frame_ms=%.2f objects=%d" % [
			enemies, spark_target, _spark_peak, spark_bounces, fps, frame_ms, objs])
		# Census scene children by script/class so we can see what is actually piling up.
		var census := {}
		for n in get_tree().current_scene.get_children():
			var k := n.get_class()
			if n.get_script() != null:
				k = str(n.get_script().resource_path).get_file()
			census[k] = census.get(k, 0) + 1
		var keys := census.keys()
		keys.sort_custom(func(a, b): return census[a] > census[b])
		var parts := []
		for k in keys:
			parts.append("%s=%d" % [k, census[k]])
		print("SPARKCENSUS total_children=%d %s" % [get_tree().current_scene.get_child_count(), " ".join(parts)])
		print("SPARKCENSUS active_dmgnums=%d active_sparks=%d" % [DamageNumberPool._active, ProjectilePool._active_sparks])
		get_tree().quit()

## Directly spawns one real spark at a random enemy, aimed at a nearby enemy so it bounces through
## the field (exercising _find_next_target every bounce).
func _spawn_one_spark() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	var origin = enemies[randi() % enemies.size()]
	if not is_instance_valid(origin):
		return
	var spark = ProjectilePool.get_spark()
	if spark == null:
		return  # at the concurrent-spark cap
	spark.allegiance = SparkProjectile.Allegiance.PLAYER
	spark.user = _player
	spark.weapon = null
	spark.base_damage = 6
	spark.bounce_count = spark_bounces
	spark.bounces_remaining = spark_bounces
	spark.bounce_range = SPARK_RANGE
	spark.speed = 600.0
	spark.lifetime = spark_lifetime
	spark.global_position = origin.global_position
	var near := EntityRegistry.get_enemies_near(origin.global_position, SPARK_RANGE)
	spark.target = near[0] if not near.is_empty() else null
	if is_instance_valid(spark.target):
		spark.direction = (spark.target.global_position - spark.global_position).normalized()
	else:
		spark.direction = Vector2.from_angle(randf() * TAU)
	spark.rotation = spark.direction.angle()
	get_tree().current_scene.add_child(spark)

func _boost(n: Node) -> void:
	if "max_health" in n:
		n.max_health = 1000000000
	if "current_health" in n:
		n.current_health = 1000000000
