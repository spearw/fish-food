extends Node
## Headless check of Lethal Dose (the DoT execute) in the booted world:
##   1. WITHOUT the artifact: a lethal pending total does nothing special (ticks run their course).
##   2. WITH it (equipped through the real upgrade pipeline): the moment queued DoT exceeds MAX
##      health, the enemy dies through the normal death path, and the dose's damage-report row is
##      credited with the burst.
##   3. A sub-lethal total does NOT execute (threshold is max health, not "any poison").
## Run with --headless.

const POISON := "res://systems/status_effects/poison/poison_status_effect.tres"
const HERMIT := "res://actors/enemies/normal_enemy_types/hermit_crab/hermit_crab.tres"
const DOSE := "res://systems/upgrades/artifacts/venom/lethal_dose_unlock.tres"

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
	var probe = load("res://execute_verify.gd").new()
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
		print("EXECUTE ERROR: world never became ready")
		get_tree().quit()
		return
	var player = get_tree().get_first_node_in_group("player")
	var scene := get_tree().current_scene
	if not is_instance_valid(player) or scene == null:
		return
	var director = scene.find_child("EncounterDirector", true, false)
	var um = scene.find_child("UpgradeManager", true, false)
	if director == null or um == null or not is_instance_valid(um.player):
		return
	_booted = true
	_run(director, um, player)

## A poison strong enough that ~4 stacks doom a MEDIUM hermit crab (25 HP), deterministic.
func _lethal_poison() -> StatusEffect:
	var poison: DotStatusEffect = load(POISON).duplicate(true)
	poison.additional_status_chance = 0.0
	poison.damage_per_tick = 2.0
	poison.time_between_ticks = 1.0
	poison.duration = 6.0  # ~6 ticks x 2 dmg x stacks: 3 stacks = 36 pending vs 25 max HP
	return poison

func _run(director, um, player) -> void:
	director.spawn_pulse_timer.stop()

	# --- 1. No artifact: lethal pending, no execute ---
	var crab_a = director.spawn_enemy(load(HERMIT), player.global_position + Vector2.RIGHT * 500.0)
	await get_tree().physics_frame
	var manager_a = crab_a.get_node("StatusEffectManager")
	var poison := _lethal_poison()
	for i in range(4):
		manager_a.apply_status(poison, player, "Test Fang")
	await get_tree().physics_frame
	var no_artifact_ok: bool = is_instance_valid(crab_a) and not crab_a.is_dying
	print("EXECUTE without_artifact: alive=%s" % str(no_artifact_ok))
	if is_instance_valid(crab_a):
		crab_a.take_damage(999999, 1.0, false, null)

	# --- 2. Equip Lethal Dose through the real pipeline; the doomed die now ---
	um.apply_upgrade({"upgrade": load(DOSE), "rarity": Upgrade.Rarity.LEGENDARY})
	await get_tree().physics_frame
	var stat_ok: bool = player.get_stat("dot_execute") > 0.0
	var credited_before: int = CurrentRun.damage_by_source.get("Test Fang", 0)
	var crab_b = director.spawn_enemy(load(HERMIT), player.global_position + Vector2.RIGHT * 550.0)
	await get_tree().physics_frame
	var max_hp: int = crab_b.stats.max_health
	var manager_b = crab_b.get_node("StatusEffectManager")
	for i in range(4):
		manager_b.apply_status(_lethal_poison(), player, "Test Fang")
		await get_tree().physics_frame
		if crab_b.is_dying:
			break
	var executed_ok: bool = crab_b.is_dying
	var credited_after: int = CurrentRun.damage_by_source.get("Test Fang", 0)
	var credit_ok: bool = credited_after > credited_before
	print("EXECUTE with_artifact: stat=%s executed=%s (max_hp=%d) credited=%s (+%d)" % [
		str(stat_ok), str(executed_ok), max_hp, str(credit_ok), credited_after - credited_before])

	# --- 3. Sub-lethal pending does not execute ---
	var crab_c = director.spawn_enemy(load(HERMIT), player.global_position + Vector2.RIGHT * 600.0)
	await get_tree().physics_frame
	var weak: DotStatusEffect = load(POISON).duplicate(true)
	weak.additional_status_chance = 0.0
	weak.damage_per_tick = 1.0
	weak.time_between_ticks = 1.0
	weak.duration = 3.0  # 1 stack, ~3 pending vs 25+ max HP
	manager_c_apply(crab_c, weak, player)
	await get_tree().physics_frame
	var sublethal_ok: bool = is_instance_valid(crab_c) and not crab_c.is_dying
	print("EXECUTE sublethal: alive=%s" % str(sublethal_ok))

	var pass_all: bool = no_artifact_ok and stat_ok and executed_ok and credit_ok and sublethal_ok
	print("EXECUTE RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()

func manager_c_apply(crab, status, player) -> void:
	crab.get_node("StatusEffectManager").apply_status(status, player, "Test Fang")
