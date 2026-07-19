extends Node
## Headless check of the herald (mini-boss) machinery. Boots the real world (whose director carries
## the three herald candidates) and drives both herald outcomes:
##   1. Scheduling: the director announces a herald -> the combo trigger leaves the level path.
##   2. Spawn: BOSS-size scaling applied, threat-ledger exempt, boss bar up, knockback immune.
##   3. Kill: herald_killed_at stamps, boss_killed fires, the combo offer opens at ANY level.
##   4. Leave: herald_left set, boss fades, combo falls back to the level-20 trigger.
##   5. Flawless proof breaks on a hit during a live herald; no-herald worlds keep the level trigger.
## Run with --headless.

var is_probe := false

var _booted := false
var _boot_frames := 0

# Event observations
var _spawned_boss: Node = null
var _spawn_count := 0
var _killed_seen := false
var _left_seen := false

func _ready() -> void:
	if is_probe:
		process_mode = Node.PROCESS_MODE_ALWAYS
		return
	CurrentRun.reset_run_state()
	CurrentRun.selected_character = load("res://actors/player/characters/test_character/test_character.tres")
	CurrentRun.selected_biome = load("res://systems/spawner/biomes/reef_biome.tres")
	CurrentRun.selected_pack_paths = []
	var probe = load("res://boss_verify.gd").new()
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
		print("BOSSVERIFY ERROR: world never became ready")
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
	Events.boss_spawned.connect(func(b, _s): _spawned_boss = b; _spawn_count += 1)
	Events.boss_killed.connect(func(_s): _killed_seen = true)
	Events.boss_left.connect(func(_s): _left_seen = true)

	# --- 1. Scheduling ---
	var scheduled_ok: bool = CurrentRun.herald_scheduled
	print("BOSSVERIFY scheduled: %s" % str(scheduled_ok))

	# While a herald is scheduled but unresolved, no combo offer at ANY level. Gate the draft
	# counts first so eligibility itself is met (fire+lightning combo, power gate 4).
	CurrentRun.deck_draft_counts = {"fire": 9, "lightning": 9}
	CurrentRun.combos_taken = 0
	var hold_ok: bool = not ComboManager.should_offer_combo(99)
	print("BOSSVERIFY hold_while_pending: %s" % str(hold_ok))

	# --- 2. Spawn (threat-exempt, BOSS scaling, knockback immunity, bar) ---
	director.spawn_pulse_timer.stop()
	var cr_before: float = director._active_threat_cr
	director.herald_time = director.run_timer + 0.2
	var waited := 0
	while _spawned_boss == null and waited < 300:
		waited += 1
		await get_tree().physics_frame
	if _spawned_boss == null:
		print("BOSSVERIFY ERROR: herald never spawned")
		print("BOSSVERIFY RESULT=FAIL")
		get_tree().quit()
		return
	var boss = _spawned_boss
	var cr_after: float = director._active_threat_cr
	var exempt_ok: bool = absf(cr_after - cr_before) < 0.001
	var names := ["The Bloom", "The Warden", "The Quillmother"]
	var name_ok: bool = boss.stats.display_name in names
	# BOSS size = 4x the authored base HP (intensity NORMAL, pre-win-time -> no other multipliers).
	var bases := {"The Bloom": 400, "The Warden": 300, "The Quillmother": 350}
	var hp_ok: bool = boss.stats.max_health == bases[boss.stats.display_name] * 4
	boss.apply_knockback(500.0, boss.global_position + Vector2.RIGHT * 10.0)
	var kb_ok: bool = boss.knockback_velocity.length() < 0.001
	var eel = EntityRegistry.get_enemy_candidates().filter(
		func(e): return is_instance_valid(e) and e != boss and not e.is_dying)
	var kb_normal_ok := true
	if not eel.is_empty():
		eel[0].apply_knockback(500.0, eel[0].global_position + Vector2.RIGHT * 10.0)
		kb_normal_ok = eel[0].knockback_velocity.length() > 100.0
	var bar = scene.find_child("BossBar", true, false)
	var bar_ok: bool = bar != null and bar.panel.visible
	print("BOSSVERIFY spawn: name=%s exempt=%s hp4x=%s kb_immune=%s kb_normal=%s bar=%s" % [
		boss.stats.display_name, str(exempt_ok), str(hp_ok), str(kb_ok), str(kb_normal_ok), str(bar_ok)])

	# --- 3. Kill -> immediate combo trigger ---
	boss.take_damage(999999, 1.0, false, null)
	waited = 0
	while CurrentRun.herald_killed_at < 0.0 and waited < 120:
		waited += 1
		await get_tree().physics_frame
	var kill_ok: bool = CurrentRun.herald_killed_at >= 0.0 and _killed_seen
	var offer_any_level_ok: bool = ComboManager.should_offer_combo(0)
	await get_tree().physics_frame
	var bar_hidden_ok: bool = bar != null and not bar.panel.visible
	print("BOSSVERIFY kill: stamped=%s offer_at_lv0=%s bar_hidden=%s" % [
		str(kill_ok), str(offer_any_level_ok), str(bar_hidden_ok)])

	# --- 4. Second herald: flawless breaks on a hit; leaving falls back to the level trigger ---
	var lui = scene.find_child("LevelUpUI", true, false)
	if lui:
		lui.hide()
	CurrentRun.herald_spawned_at = -1.0
	CurrentRun.herald_killed_at = -1.0
	CurrentRun.herald_left = false
	CurrentRun.herald_flawless = true
	director._herald_spawned = false
	_spawned_boss = null
	director.herald_time = director.run_timer + 0.2
	waited = 0
	while _spawned_boss == null and waited < 300:
		waited += 1
		await get_tree().physics_frame
	var second_ok: bool = _spawned_boss != null and _spawn_count == 2
	Events.player_was_hit.emit(null)
	var flawless_broken_ok: bool = not CurrentRun.herald_flawless
	director.herald_leave_secs = 0.0
	waited = 0
	while not CurrentRun.herald_left and waited < 120:
		waited += 1
		await get_tree().physics_frame
	var leave_ok: bool = CurrentRun.herald_left and _left_seen
	var fallback_19_ok: bool = not ComboManager.should_offer_combo(19)
	var fallback_20_ok: bool = ComboManager.should_offer_combo(20)
	print("BOSSVERIFY leave: second=%s flawless_broken=%s left=%s held_at_19=%s offered_at_20=%s" % [
		str(second_ok), str(flawless_broken_ok), str(leave_ok),
		str(fallback_19_ok), str(fallback_20_ok)])

	# --- 5. No-herald worlds keep the pure level trigger ---
	CurrentRun.herald_scheduled = false
	CurrentRun.herald_left = false
	var legacy_ok: bool = ComboManager.should_offer_combo(20) and not ComboManager.should_offer_combo(19)
	print("BOSSVERIFY legacy_trigger: %s" % str(legacy_ok))

	# --- 6. Kit exercise: every herald's mechanic runs, whichever the earlier roll picked ---
	# Pufferfish: the armor phase flips on and off.
	var puffer = director.spawn_enemy(
		load("res://actors/enemies/boss_types/herald_pufferfish/pufferfish.tres"),
		player.global_position + Vector2.RIGHT * 400.0, false)
	puffer.is_on_screen = true  # headless never fires the visibility notifier; let weapons fire
	await get_tree().physics_frame
	puffer.ai.deflated_secs = 0.6
	puffer.ai.inflated_secs = 0.6
	puffer.ai._phase_left = 0.2
	var saw_armored := false
	var saw_deflated_after := false
	for i in range(90):
		await get_tree().physics_frame
		if puffer.stats.armor == puffer.ai.inflated_armor:
			saw_armored = true
		elif saw_armored and puffer.stats.armor == 0:
			saw_deflated_after = true
	var puffer_ok: bool = saw_armored and saw_deflated_after
	puffer.take_damage(999999, 1.0, false, null)

	# Moray: the lunge commits at lunge speed, and adds get summoned through the director.
	var enemies_before: int = EntityRegistry.get_alive_enemy_count()
	var moray = director.spawn_enemy(
		load("res://actors/enemies/boss_types/herald_moray/moray.tres"),
		player.global_position + Vector2.RIGHT * 400.0, false)
	await get_tree().physics_frame
	moray.ai.chase_secs = 0.5
	moray.ai.telegraph_secs = 0.3
	moray.ai.lunge_secs = 0.4
	moray.ai.recover_secs = 0.3
	moray.ai._t = 0.2
	moray.ai._summon_t = 0.2
	var peak_speed := 0.0
	for i in range(80):
		await get_tree().physics_frame
		peak_speed = maxf(peak_speed, moray.velocity.length())
	var moray_lunge_ok: bool = peak_speed >= moray.ai.lunge_speed * 0.9
	var moray_summon_ok: bool = EntityRegistry.get_alive_enemy_count() >= enemies_before + 2
	moray.take_damage(999999, 1.0, false, null)

	# Lionfish: closes to range and enters the shoot state (stock MoveAndShoot brain).
	var lion = director.spawn_enemy(
		load("res://actors/enemies/boss_types/herald_lionfish/lionfish.tres"),
		player.global_position + Vector2.RIGHT * 220.0, false)
	lion.is_on_screen = true
	var lion_ok := false
	for i in range(60):
		await get_tree().physics_frame
		if lion.ai.current_state == lion.ai.states.get("shootbehavior"):
			lion_ok = true
			break
	lion.take_damage(999999, 1.0, false, null)
	print("BOSSVERIFY kits: puffer_phases=%s moray_lunge=%s (peak=%.0f) moray_summons=%s lion_shoots=%s" % [
		str(puffer_ok), str(moray_lunge_ok), peak_speed, str(moray_summon_ok), str(lion_ok)])

	var pass_all: bool = scheduled_ok and hold_ok and exempt_ok and name_ok and hp_ok \
		and kb_ok and kb_normal_ok and bar_ok and kill_ok and offer_any_level_ok \
		and bar_hidden_ok and second_ok and flawless_broken_ok and leave_ok \
		and fallback_19_ok and fallback_20_ok and legacy_ok \
		and puffer_ok and moray_lunge_ok and moray_summon_ok and lion_ok
	print("BOSSVERIFY RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
