extends Node
## Headless check of the three polish crumbs (booted world):
##   1. Blocked-hit clink: an armor-zeroed hit floats a gray "0" (throttled) instead of silence.
##   2. Venom stack pips: a "***" row under the health bar tracks the stack count.
##   3. Early armor band: the Hermit Crab (armor 4) joins the spawn pool at 2:30 -- the first
##      armored enemy teaches the clink before armor numbers get real.
## Run with --headless.

const POISON := "res://systems/status_effects/poison/poison_status_effect.tres"
const HERMIT := "res://actors/enemies/normal_enemy_types/hermit_crab/hermit_crab.tres"

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
	CurrentRun.selected_pack_paths = []
	var probe = load("res://polish_verify.gd").new()
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
		print("POLISH ERROR: world never became ready")
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
	director.spawn_pulse_timer.stop()

	# --- 1. The clink ---
	var hermit = director.spawn_enemy(load(HERMIT), player.global_position + Vector2.RIGHT * 500.0)
	await get_tree().physics_frame
	hermit.is_on_screen = true  # headless never fires the visibility notifier
	var labels_before: int = _count_blocked_labels(scene)
	hermit.take_damage(3, 0.0, false, null)  # 3 into armor 4+ -> zeroed -> clink
	await get_tree().physics_frame
	var clink_ok: bool = _count_blocked_labels(scene) == labels_before + 1
	# Throttle: a second zeroed hit inside the cooldown adds nothing.
	hermit.take_damage(3, 0.0, false, null)
	await get_tree().physics_frame
	var throttle_ok: bool = _count_blocked_labels(scene) == labels_before + 1
	# A real hit still floats a real number (not a clink).
	var real_before: int = _count_blocked_labels(scene)
	hermit.take_damage(20, 0.0, false, null)
	await get_tree().physics_frame
	var real_ok: bool = _count_blocked_labels(scene) == real_before
	print("POLISH clink: shown=%s throttled=%s real_hit_unaffected=%s" % [
		str(clink_ok), str(throttle_ok), str(real_ok)])

	# --- 2. Stack pips ---
	var star = director.spawn_enemy(
		load("res://actors/enemies/normal_enemy_types/sea_star/sea_star.tres"),
		player.global_position + Vector2.RIGHT * 550.0)
	await get_tree().physics_frame
	star.is_on_screen = true
	var manager = star.get_node("StatusEffectManager")
	var poison = load(POISON).duplicate(true)
	poison.additional_status_chance = 0.0  # determinism: no escalation side rolls
	for i in range(3):
		manager.apply_status(poison, player)
	for i in range(5):
		await get_tree().physics_frame
	var pips_ok: bool = star.get("_stack_pips") != null and star._stack_pips.text == "***" \
		and star._stack_pips.visible
	print("POLISH pips: %s (text=\"%s\")" % [
		str(pips_ok), star._stack_pips.text if star._stack_pips else "none"])

	# --- 3. The armor band schedule ---
	director.run_timer = 149.0
	var before_names: Array = director._get_currently_available_enemies().map(
		func(e): return e.display_name)
	director.run_timer = 151.0
	var after_names: Array = director._get_currently_available_enemies().map(
		func(e): return e.display_name)
	var band_ok: bool = not "Hermit Crab" in before_names and "Hermit Crab" in after_names
	var hermit_stats: EnemyStats = load(HERMIT)
	var gentle_ok: bool = hermit_stats.armor == 4
	print("POLISH band: scheduled=%s armor4=%s" % [str(band_ok), str(gentle_ok)])

	var pass_all: bool = clink_ok and throttle_ok and real_ok and pips_ok and band_ok and gentle_ok
	print("POLISH RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()

## Gray "0" labels currently floating (the clink's fingerprint).
func _count_blocked_labels(scene) -> int:
	var count := 0
	for child in scene.get_children():
		if child is Label and child.text == "0" and child.modulate.a > 0.0:
			count += 1
	return count
