extends Node2D
## Headless perf benchmark for the enemy-clump case.
## Spawns N lil_fishy enemies clumped on a stub player and measures average physics/process
## time per frame. A/Bs old-vs-new by reconstructing the pre-fix behavior at runtime.
##
## Run (console build, headless):
##   Godot_..._console.exe --headless --path <proj> res://perf_bench.tscn -- --mode=new --count=200
##   modes: new (current fixes) | old (mask=3 + every enemy's proximity Area2D on)

const ENEMY_SCENE := preload("res://actors/enemies/enemy.tscn")
const STATS_PATH := "res://actors/enemies/normal_enemy_types/lil_fishy/lil_fishy.tres"
const WARMUP := 40
const MEASURE := 150

var _mode := "new"
var _count := 200
var _frame := 0
var _n := 0
var _phys := 0.0
var _proc := 0.0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.split("=")[1]
		elif arg.begins_with("--count="):
			_count = int(arg.split("=")[1])

	Engine.max_fps = 0  # uncapped so the timing reflects real throughput
	Engine.max_physics_steps_per_frame = 1  # never sub-step; measure ONE tick's true cost

	# Stub player target in group "player". collision_layer 0 => enemies don't run
	# contact-damage callbacks on it (keeps the benchmark focused on movement/collision).
	var player: CharacterBody2D = preload("res://perf_stub_player.gd").new()
	player.collision_layer = 0
	player.collision_mask = 0
	player.add_to_group("player")
	add_child(player)

	var stats := load(STATS_PATH)
	var enemies: Array = []
	for i in _count:
		var e := ENEMY_SCENE.instantiate()
		e.stats = stats
		e.global_position = Vector2.RIGHT.rotated(randf() * TAU) * (randf() * 180.0)
		add_child(e)
		enemies.append(e)

	# Reconstruct the PRE-FIX behavior for an apples-to-apples comparison.
	if _mode == "old":
		for e in enemies:
			e.collision_mask = 3  # old: collide with player_body (1) + enemy_body (2)
			if is_instance_valid(e.ai) and e.ai.has_method("enable_ally_detection"):
				e.ai.enable_ally_detection()  # old: every enemy ran the proximity Area2D

	print("BENCH_START mode=%s count=%d" % [_mode, _count])


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame <= WARMUP:
		return
	_phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	_proc += Performance.get_monitor(Performance.TIME_PROCESS)
	_n += 1
	if _n >= MEASURE:
		var pm := (_phys / _n) * 1000.0
		var cm := (_proc / _n) * 1000.0
		var tot: float = pm + cm
		var fps: float = 1000.0 / max(tot, 0.001)
		print("BENCH_RESULT mode=%s count=%d physics_ms=%.3f process_ms=%.3f total_ms=%.3f fps_ceiling=%.0f" % [_mode, _count, pm, cm, tot, fps])
		get_tree().quit()
