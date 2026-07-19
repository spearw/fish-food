extends Node
## Headless check of the secret-boss (Anglerfish) machinery in the booted world:
##   1. Proof matrix: speed / flawless / depth each arm the lure; an unproven run never sees it.
##   2. The lure surfaces at lure_time, the summary hints, the pointer targets it.
##   3. Touching it swaps the false chest for the fight: boss up, world dims.
##   4. The kill grants the rewards in sequence: second combo capacity -> combo choice ->
##      third-deck pick (cap raised, deck joined, pool rebuilt) -> light returns.
## Run with --headless.

const BuildSummary := preload("res://systems/global/build_summary.gd")
const FIRE_PACK := "res://systems/upgrades/packs/fire_pack.tres"
const LIGHTNING_PACK := "res://systems/upgrades/packs/lightning_pack.tres"

var is_probe := false
var _booted := false
var _boot_frames := 0

func _ready() -> void:
	if is_probe:
		process_mode = Node.PROCESS_MODE_ALWAYS
		return
	CurrentRun.reset_run_state()
	CurrentRun.selected_character = load("res://actors/player/characters/test_character/test_character.tres")
	CurrentRun.selected_biome = load("res://systems/spawner/biomes/reef_biome.tres")
	CurrentRun.selected_pack_paths = [FIRE_PACK, LIGHTNING_PACK]
	var probe = load("res://angler_verify.gd").new()
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
		print("ANGLER ERROR: world never became ready")
		get_tree().quit()
		return
	var player = get_tree().get_first_node_in_group("player")
	var scene := get_tree().current_scene
	if not is_instance_valid(player) or scene == null:
		return
	var director = scene.find_child("EncounterDirector", true, false)
	var lui = scene.find_child("LevelUpUI", true, false)
	if director == null or lui == null or not is_instance_valid(director.player_node):
		return
	_booted = true
	_run(director, scene, player, lui)

func _run(director, scene, player, lui) -> void:
	# Clear the starting-weapon offer so the run is in a normal state.
	await get_tree().physics_frame
	if lui.visible and not lui.current_upgrades.is_empty():
		lui._on_upgrade_button_pressed(0)
	director.spawn_pulse_timer.stop()

	# --- 1. Proof matrix (pure function against CurrentRun state) ---
	var none_ok: bool = not director._secret_proof_met()
	CurrentRun.herald_spawned_at = 100.0
	CurrentRun.herald_killed_at = 130.0
	CurrentRun.herald_flawless = false
	var speed_ok: bool = director._secret_proof_met()
	CurrentRun.herald_killed_at = 190.0
	var slow_ok: bool = not director._secret_proof_met()
	CurrentRun.herald_flawless = true
	var flawless_ok: bool = director._secret_proof_met()
	CurrentRun.herald_spawned_at = -1.0
	CurrentRun.herald_killed_at = -1.0
	CurrentRun.combos_taken = 1
	CurrentRun.deck_draft_counts = {"fire": 6, "lightning": 7}
	var depth_ok: bool = director._secret_proof_met()
	CurrentRun.deck_draft_counts = {"fire": 6, "lightning": 2}
	var shallow_ok: bool = not director._secret_proof_met()
	print("ANGLER proofs: none=%s speed=%s slow=%s flawless=%s depth=%s shallow=%s" % [
		str(none_ok), str(speed_ok), str(slow_ok), str(flawless_ok), str(depth_ok), str(shallow_ok)])

	# --- 1b. Unproven run: the check runs once and nothing surfaces ---
	CurrentRun.combos_taken = 0
	CurrentRun.deck_draft_counts = {}
	director.lure_time = director.run_timer + 0.2
	for i in range(40):
		await get_tree().physics_frame
	var no_lure_ok: bool = get_tree().get_nodes_in_group("anglerfish_lure").is_empty() \
		and not CurrentRun.lure_alive and director._lure_checked
	print("ANGLER unproven: no_lure=%s" % str(no_lure_ok))

	# --- 2. Proven run: the lure surfaces, the summary hints, the pointer knows ---
	CurrentRun.herald_spawned_at = 100.0
	CurrentRun.herald_killed_at = 120.0
	director._lure_checked = false
	director.lure_time = director.run_timer + 0.2
	var waited := 0
	while get_tree().get_nodes_in_group("anglerfish_lure").is_empty() and waited < 300:
		waited += 1
		await get_tree().physics_frame
	var lures: Array = get_tree().get_nodes_in_group("anglerfish_lure")
	var lure_ok: bool = not lures.is_empty() and CurrentRun.lure_alive
	var hint_ok: bool = BuildSummary.lure_line() != ""
	var bar = scene.find_child("BossBar", true, false)
	var pointer_ok: bool = bar != null and bar._lure != null
	print("ANGLER lure: spawned=%s hint=%s pointer=%s" % [str(lure_ok), str(hint_ok), str(pointer_ok)])
	if not lure_ok:
		print("ANGLER RESULT=FAIL")
		get_tree().quit()
		return

	# --- 3. The touch: fight starts, world dims ---
	var world = scene
	player.global_position = lures[0].global_position
	waited = 0
	while not is_instance_valid(director._secret_boss) and waited < 120:
		waited += 1
		await get_tree().physics_frame
	var boss = director._secret_boss
	var fight_ok: bool = is_instance_valid(boss) and boss.stats.display_name == "The Anglerfish"
	var lure_gone_ok: bool = not CurrentRun.lure_alive
	for i in range(100):
		await get_tree().physics_frame
	var dim_ok: bool = world.get_node("Darkness").color.r < 0.9
	var bar_ok: bool = bar.panel.visible
	print("ANGLER fight: boss=%s lure_gone=%s dim=%s bar=%s" % [
		str(fight_ok), str(lure_gone_ok), str(dim_ok), str(bar_ok)])

	# --- 4. The kill: capacity 2 -> combo choice -> third deck -> light returns ---
	CurrentRun.deck_draft_counts = {"fire": 9, "lightning": 9}
	var pool_before: int = director.get_tree().current_scene.find_child(
		"UpgradeManager", true, false).active_upgrade_pool.size()
	boss.take_damage(999999, 1.0, false, null)
	waited = 0
	while not CurrentRun.secret_boss_killed and waited < 120:
		waited += 1
		await get_tree().physics_frame
	var capacity_ok: bool = CurrentRun.combo_capacity == 2
	# The reward chain: first the combo choice...
	waited = 0
	while not (lui.visible and lui._choosing_combo) and waited < 180:
		waited += 1
		await get_tree().physics_frame
	var combo_screen_ok: bool = lui.visible and lui._choosing_combo
	var taken_id := ""
	if combo_screen_ok:
		taken_id = lui.current_upgrades[0]["upgrade"].id
		lui._on_upgrade_button_pressed(0)
	var spent_ok: bool = CurrentRun.combos_taken == 1
	var excluded_ok: bool = taken_id != "" \
		and ComboManager.get_eligible_synergies().all(func(s): return s.id != taken_id)
	# ...then the third-deck pick.
	waited = 0
	while not (lui.visible and lui._choosing_deck) and waited < 180:
		waited += 1
		await get_tree().physics_frame
	var deck_screen_ok: bool = lui.visible and lui._choosing_deck
	var deck_join_ok := false
	var pool_grew_ok := false
	if deck_screen_ok:
		lui._on_upgrade_button_pressed(0)
		await get_tree().physics_frame
		var um = scene.find_child("UpgradeManager", true, false)
		deck_join_ok = CurrentRun.max_themed_decks == 3 \
			and CurrentRun.get_active_deck_paths().size() == 3
		pool_grew_ok = um.active_upgrade_pool.size() > pool_before
	for i in range(120):
		await get_tree().physics_frame
	var light_ok: bool = world.get_node("Darkness").color.r > 0.95
	print("ANGLER rewards: capacity=%s combo_screen=%s spent=%s excluded=%s deck_screen=%s joined=%s pool_grew=%s light=%s" % [
		str(capacity_ok), str(combo_screen_ok), str(spent_ok), str(excluded_ok),
		str(deck_screen_ok), str(deck_join_ok), str(pool_grew_ok), str(light_ok)])

	var pass_all: bool = none_ok and speed_ok and slow_ok and flawless_ok and depth_ok \
		and shallow_ok and no_lure_ok and lure_ok and hint_ok and pointer_ok and fight_ok \
		and lure_gone_ok and dim_ok and bar_ok and capacity_ok and combo_screen_ok \
		and spent_ok and excluded_ok and deck_screen_ok and deck_join_ok and pool_grew_ok \
		and light_ok
	print("ANGLER RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
