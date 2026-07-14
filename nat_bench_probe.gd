extends Node
## Natural-spawn probe (lives on the SceneTree root; survives the change into world.tscn).
## Boots a real run, immortalizes the player, kills the level-up pause, then forces the director's
## run_timer to `sim_time` so the difficulty TARGET is high -- and lets the EncounterDirector spawn
## and recycle NATURALLY (no forced spawns). Verifies the new population model self-bounds the live
## enemy count at the target/cap, and measures real wall-clock frame time. Prints and quits.

var sim_time := 1195.0    # run_timer (seconds) to force; ~20-min climax by default
var scale_override := 0.0  # if > 0, overrides target_threat_scale (to push the target past the cap)

var _booted := false
var _boot_frames := 0
var _player: Node = null
var _dir: Node = null

var _boot_us := 0
var _warm_done := false
var _meas_start_us := 0
var _meas_frames := 0
var _pop_min := 1 << 30
var _pop_max := 0

const BOOT_TIMEOUT := 2000
const WARM_SECONDS := 4.0     # let the population ramp toward the target and settle
const MEASURE_SECONDS := 2.5

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

func _process(_dt: float) -> void:
	get_tree().paused = false  # the run hands out a level-up that pauses; keep it running

	if not _booted:
		_boot_frames += 1
		if _boot_frames > BOOT_TIMEOUT:
			print("NATBENCH ERROR: world/player never became ready")
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
		if "max_health" in _player:
			_player.max_health = 1000000000
		if "current_health" in _player:
			_player.current_health = 1000000000
		# Bulletproof invincibility so enemies can't contact-kill it; daggers still fire.
		if "collision_layer" in _player:
			_player.collision_layer = 0
		_dir = scene.find_child("EncounterDirector", true, false)
		if _dir == null:
			print("NATBENCH ERROR: no EncounterDirector")
			get_tree().quit()
			return
		# Force the difficulty target high, and isolate the population model by skipping the one-time
		# burst/boss events (they are cap-exempt by design and would muddy this measurement).
		_dir.run_timer = sim_time
		if scale_override > 0.0:
			_dir.target_threat_scale = scale_override
		if "pending_encounter_sets" in _dir:
			_dir.pending_encounter_sets.clear()
		_booted = true
		_boot_us = Time.get_ticks_usec()
		return

	# Keep the player alive so it keeps clearing enemies (director refills toward the target).
	if is_instance_valid(_player) and "current_health" in _player:
		_player.current_health = 1000000000

	var now := Time.get_ticks_usec()
	var since_boot := float(now - _boot_us) / 1_000_000.0

	if not _warm_done:
		if since_boot >= WARM_SECONDS:
			_warm_done = true
			_meas_start_us = now
			_meas_frames = 0
		return

	# Measure window: count frames and track the live population band.
	_meas_frames += 1
	var pop := get_tree().get_nodes_in_group("enemies").size()
	_pop_min = min(_pop_min, pop)
	_pop_max = max(_pop_max, pop)

	var meas_elapsed := float(now - _meas_start_us) / 1_000_000.0
	if meas_elapsed >= MEASURE_SECONDS:
		var frame_ms := (meas_elapsed * 1000.0) / float(max(_meas_frames, 1))
		var fps := 1000.0 / maxf(frame_ms, 0.001)
		var target_cr: float = _dir.difficulty_curve.sample(_dir.run_timer) * _dir.threat_level \
			* CurrentRun.get_intensity_multiplier() * _dir.target_threat_scale
		var objs := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		print("NATBENCH sim_t=%.0f target_cr=%.0f cap=%d pop_min=%d pop_max=%d active_cr=%.0f fps=%.0f frame_ms=%.2f objects=%d" % [
			sim_time, target_cr, _dir.max_active_enemies, _pop_min, _pop_max,
			_dir._active_threat_cr, fps, frame_ms, objs])
		get_tree().quit()
