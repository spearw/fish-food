extends Node
## Damage-number stress probe (lives on the SceneTree root; survives the scene change).
## Boots a real run, immortalizes player + enemies, disables the director, then applies a controlled
## number of hits per frame to random enemies -- driving ONLY the damage-number system, with no spark
## physics to add noise. Toggle `aggregate` to A/B the per-target aggregation against one-number-per-
## hit. Measures real wall-clock frame time and the live damage-number count.

var count := 150            # immortal enemy field
var hits_per_frame := 150   # simulated hit volume (chain lightning / high fire rate)
var aggregate := true       # true: route through enemy aggregation; false: one number per hit

var _spawned := false
var _boot_frames := 0
var _warm := 0
var _n := 0
var _last_us := 0
var _frame_us := 0.0
var _dn_peak := 0
var _player: Node = null
var _dir: Node = null
var _enemies: Array = []

const WARMUP := 60
const MEASURE := 150
const BOOT_TIMEOUT := 1500

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

func _process(_dt: float) -> void:
	get_tree().paused = false

	if not _spawned:
		_boot_frames += 1
		if _boot_frames > BOOT_TIMEOUT:
			print("DMGBENCH ERROR: world/player never became ready")
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

	# Immortal enemy field (no deaths -> no loot/churn confound).
	_enemies = get_tree().get_nodes_in_group("enemies")
	for e in _enemies:
		if is_instance_valid(e) and "current_health" in e:
			e.current_health = 1000000000

	# Apply the frame's hit volume to random enemies.
	if not _enemies.is_empty():
		for i in range(hits_per_frame):
			var e = _enemies[randi() % _enemies.size()]
			if not is_instance_valid(e):
				continue
			var dmg := 8 + (randi() % 20)
			if aggregate:
				# Route through the real aggregation path.
				e._on_take_damage(dmg, false, null)
			else:
				# One fresh number per hit (old behaviour), same cheap number impl.
				var dn = DamageNumberPool.get_damage_number()
				if dn != null:
					get_tree().current_scene.add_child(dn)
					dn.start(dmg, e.global_position, false)

	if _warm < WARMUP:
		_warm += 1
		_last_us = Time.get_ticks_usec()
		return

	var now := Time.get_ticks_usec()
	if _last_us > 0:
		_frame_us += float(now - _last_us)
		_n += 1
	_last_us = now
	_dn_peak = max(_dn_peak, DamageNumberPool._active)
	if _n >= MEASURE:
		var frame_ms := (_frame_us / float(_n)) / 1000.0
		var fps := 1000.0 / maxf(frame_ms, 0.001)
		var objs := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		print("DMGBENCH enemies=%d hits_per_frame=%d aggregate=%s dn_peak=%d fps=%.0f frame_ms=%.2f objects=%d" % [
			_enemies.size(), hits_per_frame, str(aggregate), _dn_peak, fps, frame_ms, objs])
		get_tree().quit()
