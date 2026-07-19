extends Node
## Headless check of the leviathan (final boss) machinery in the booted world:
##   1. Draw: once a starting weapon exists, the run's leviathan is drawn from the trio and the
##      build summary names it (the known-exam reveal, with the herald rider folded in).
##   2. Win gate: with a leviathan drawn, the survival timer alone no longer wins; the kill does.
##   3. Spawn at win_time: boss bar up, rider baked into the display name, threat-exempt.
##   4. Kits: crab molts (armor drops, jellies spawn, re-plates), eel chain-lunges and leaves
##      crackle zones, undertow drops the swallow pull zone below one third.
##   5. Riders map correctly from each slain herald.
## Run with --headless.

const BuildSummary := preload("res://systems/global/build_summary.gd")

var is_probe := false
var _booted := false
var _boot_frames := 0
var _spawned: Node = null

func _ready() -> void:
	if is_probe:
		process_mode = Node.PROCESS_MODE_ALWAYS
		return
	CurrentRun.reset_run_state()
	CurrentRun.selected_character = load("res://actors/player/characters/test_character/test_character.tres")
	CurrentRun.selected_biome = load("res://systems/spawner/biomes/reef_biome.tres")
	CurrentRun.selected_pack_paths = []
	var probe = load("res://leviathan_verify.gd").new()
	probe.is_probe = true
	get_tree().root.add_child.call_deferred(probe)
	get_tree().change_scene_to_file.call_deferred("res://world/world.tscn")

func _process(_dt: float) -> void:
	if not is_probe:
		return
	get_tree().paused = false
	if _booted:
		return
	_boot_frames += 1
	if _boot_frames > 1500:
		print("LEVIATHAN ERROR: world never became ready")
		get_tree().quit()
		return
	var player = get_tree().get_first_node_in_group("player")
	var scene := get_tree().current_scene
	if not is_instance_valid(player) or scene == null:
		return
	var director = scene.find_child("EncounterDirector", true, false)
	if director == null or not is_instance_valid(director.player_node):
		return
	_booted = true
	_run(director, scene, player)

func _run(director, scene, player) -> void:
	Events.boss_spawned.connect(func(b, _s): _spawned = b)
	var world = scene

	# --- 1. Draw + reveal ---
	CurrentRun.starting_weapon_chosen = true
	CurrentRun.herald_slain_name = "The Bloom"
	var waited := 0
	while CurrentRun.leviathan_stats == null and waited < 300:
		waited += 1
		await get_tree().physics_frame
	var trio := ["The Undertow", "The King Crab", "The Storm Eel"]
	var draw_ok: bool = CurrentRun.leviathan_stats != null \
		and CurrentRun.leviathan_stats.display_name in trio
	var line: String = BuildSummary.leviathan_line()
	var reveal_ok: bool = draw_ok and line.contains(CurrentRun.leviathan_stats.display_name) \
		and line.contains("(Spined)")
	print("LEVIATHAN draw: drawn=%s line=\"%s\" ok=%s" % [
		CurrentRun.leviathan_stats.display_name if draw_ok else "none", line, str(reveal_ok)])

	# --- 2. The timer alone no longer wins ---
	world.survival_goal_seconds = world.game_time + 0.2
	for i in range(40):
		await get_tree().physics_frame
	var timer_suppressed_ok: bool = not world._win_shown
	print("LEVIATHAN timer_suppressed: %s" % str(timer_suppressed_ok))

	# --- 3. Spawn at win_time, rider on the bar, kill wins ---
	director.win_time = director.run_timer + 0.2
	waited = 0
	while _spawned == null and waited < 300:
		waited += 1
		await get_tree().physics_frame
	var bar = scene.find_child("BossBar", true, false)
	var spawn_ok: bool = _spawned != null and is_instance_valid(director._leviathan)
	var rider_name_ok: bool = spawn_ok and _spawned.stats.display_name.ends_with("(Spined)")
	var bar_ok: bool = bar != null and bar.panel.visible
	_spawned.take_damage(999999, 1.0, false, null)
	waited = 0
	while not CurrentRun.leviathan_killed and waited < 120:
		waited += 1
		await get_tree().physics_frame
	var win_ok := false
	for i in range(30):
		await get_tree().physics_frame
		if world._win_shown:
			win_ok = true
			break
	var lui = scene.find_child("LevelUpUI", true, false)
	var win_screen_ok: bool = lui != null and lui._win_screen
	print("LEVIATHAN win_gate: spawn=%s rider_name=%s bar=%s killed_wins=%s win_screen=%s" % [
		str(spawn_ok), str(rider_name_ok), str(bar_ok), str(win_ok), str(win_screen_ok)])
	if lui:
		lui._win_screen = false
		lui.hide()

	# --- 4a. King Crab: plated, molts on the crossed third, jellies out, re-plates ---
	CurrentRun.herald_slain_name = "The Quillmother"
	var crab = director.spawn_enemy(
		load("res://actors/enemies/boss_types/leviathans/king_crab/king_crab.tres"),
		player.global_position + Vector2.RIGHT * 500.0, false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var plated_ok: bool = crab.stats.armor == crab.ai.plated_armor
	var quilled_ok: bool = crab.ai.rider == "Quilled"
	crab.ai.molt_secs = 0.5
	var jellies_before: int = EntityRegistry.get_alive_enemy_count()
	crab.current_health = int(crab.stats.max_health * 0.6)
	var molted := false
	for i in range(30):
		await get_tree().physics_frame
		if crab.stats.armor == 0:
			molted = true
			break
	var adds_ok: bool = EntityRegistry.get_alive_enemy_count() >= jellies_before + 2
	var replated := false
	for i in range(60):
		await get_tree().physics_frame
		if crab.stats.armor == crab.ai.plated_armor:
			replated = true
			break
	print("LEVIATHAN crab: plated=%s molt=%s adds=%s replate=%s quilled=%s" % [
		str(plated_ok), str(molted), str(adds_ok), str(replated), str(quilled_ok)])
	crab.take_damage(999999, 1.0, false, null)

	# --- 4b. Storm Eel: Restless rider, chain lunge speed, crackle wake ---
	CurrentRun.herald_slain_name = "The Warden"
	var eel = director.spawn_enemy(
		load("res://actors/enemies/boss_types/leviathans/storm_eel/storm_eel.tres"),
		player.global_position + Vector2.RIGHT * 500.0, false)
	await get_tree().physics_frame
	var restless_ok: bool = absf(eel.ai.telegraph_scale - 0.8) < 0.001
	eel.ai._t = 0.1
	var peak := 0.0
	for i in range(120):
		await get_tree().physics_frame
		peak = maxf(peak, eel.velocity.length())
	var lunge_ok: bool = peak >= eel.ai.lunge_speed * 0.9
	var wake_ok: bool = get_tree().get_nodes_in_group("crackle_zone").size() > 0
	print("LEVIATHAN eel: restless=%s lunge=%s (peak=%.0f) wake=%s" % [
		str(restless_ok), str(lunge_ok), peak, str(wake_ok)])
	eel.take_damage(999999, 1.0, false, null)

	# --- 4c. Undertow: below one third, the swallow opens under the player ---
	CurrentRun.herald_slain_name = "The Bloom"
	var undertow = director.spawn_enemy(
		load("res://actors/enemies/boss_types/leviathans/undertow/undertow.tres"),
		player.global_position + Vector2.RIGHT * 500.0, false)
	await get_tree().physics_frame
	var spined_ok: bool = undertow.ai.rider == "Spined"
	undertow.current_health = int(undertow.stats.max_health * 0.3)
	undertow.ai._pull_t = 0.1
	undertow.ai.pull_warning_secs = 0.05
	var pull_ok := false
	for i in range(90):
		await get_tree().physics_frame
		if get_tree().get_nodes_in_group("pull_zone").size() > 0:
			pull_ok = true
			break
	print("LEVIATHAN undertow: spined=%s pull_zone=%s" % [str(spined_ok), str(pull_ok)])
	undertow.take_damage(999999, 1.0, false, null)

	var pass_all: bool = draw_ok and reveal_ok and timer_suppressed_ok and spawn_ok \
		and rider_name_ok and bar_ok and win_ok and win_screen_ok \
		and plated_ok and molted and adds_ok and replated and quilled_ok \
		and restless_ok and lunge_ok and wake_ok and spined_ok and pull_ok
	print("LEVIATHAN RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
