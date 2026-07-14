extends Node
## Persistent probe (lives on the SceneTree root; survives the change into world.tscn).
## Boots a real run, immortalizes the player, kills the level-up pause, holds a steady ~N
## enemies (they die to the daggers, we top back up), and measures REAL wall-clock frame
## time (vsync off) over a window, then prints and quits.

var count := 100

var _spawned := false
var _boot_frames := 0
var _warm := 0
var _n := 0
var _last_us := 0
var _frame_us := 0.0
var _player: Node = null
var _dir: Node = null

const WARMUP := 60
const MEASURE := 150
const BOOT_TIMEOUT := 1500

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

func _process(_dt: float) -> void:
	get_tree().paused = false  # the run hands out a level-up that pauses; keep it running

	if not _spawned:
		_boot_frames += 1
		if _boot_frames > BOOT_TIMEOUT:
			print("FULLBENCH ERROR: world/player never became ready")
			get_tree().quit()
			return
		var scene := get_tree().current_scene
		if scene == null:
			return
		_player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(_player):
			return
		# Drop all leveled_up handlers so the level-up UI can never pause the tree.
		if _player.has_signal("leveled_up"):
			for c in _player.leveled_up.get_connections():
				_player.leveled_up.disconnect(c.callable)
		_boost(_player)
		# Bulletproof invincibility: take the player off its physics layer so enemies can't
		# contact-damage it. Daggers still fire (targeting is position-based); it just can't die.
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

	# Keep the player alive and the population near N (enemies die to the daggers).
	if is_instance_valid(_player) and "current_health" in _player:
		_player.current_health = 1000000000
	var cur := get_tree().get_nodes_in_group("enemies").size()
	if _dir and cur < count and _dir.has_method("debug_spawn"):
		_dir.debug_spawn(min(count - cur, 5))  # cap per-frame spawns; avoid a benchmark spawn-storm

	if _warm < WARMUP:
		_warm += 1
		_last_us = Time.get_ticks_usec()
		return

	# Measure real wall-clock frame time.
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		_frame_us += float(now - _last_us)
		_n += 1
	_last_us = now
	if _n >= MEASURE:
		var frame_ms := (_frame_us / float(_n)) / 1000.0
		var fps := 1000.0 / maxf(frame_ms, 0.001)
		var enemies := get_tree().get_nodes_in_group("enemies").size()
		var objs := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		var scene_children := 0
		var daggers := 0
		var sparks := 0
		if get_tree().current_scene:
			scene_children = get_tree().current_scene.get_child_count()
			for n in get_tree().current_scene.get_children():
				if n is Projectile:
					daggers += 1
				elif n is SparkProjectile:
					sparks += 1
		print("FULLBENCH count=%d enemies=%d fps=%.0f frame_ms=%.2f objects=%d children=%d daggers=%d sparks=%d dmgnums=%d" % [count, enemies, fps, frame_ms, objs, scene_children, daggers, sparks, DamageNumberPool._active])
		get_tree().quit()

func _boost(n: Node) -> void:
	if "max_health" in n:
		n.max_health = 1000000000
	if "current_health" in n:
		n.current_health = 1000000000
