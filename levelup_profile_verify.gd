extends Node
## Headless timing probe for the level-up present path. Boots the real world with two themed decks,
## then times each stage: choice generation, the full present, and the on-click apply. Output is
## microsecond timings -- the point is to find where the reported level-up freeze actually lives
## before optimizing anything. Run with --headless.

const FIRE_PACK := "res://systems/upgrades/packs/fire_pack.tres"
const LIGHTNING_PACK := "res://systems/upgrades/packs/lightning_pack.tres"

## False on the scene-root bootstrap; true on the probe that lives on the tree ROOT and survives the
## scene swap (change_scene_to_file frees the bootstrap -- the same trap every bench probe dodges).
var is_probe := false

var _booted := false
var _boot_frames := 0
# Worst single stage seen across the WARM rounds (round 0 is cold caches and gets a pass).
var _worst_stage_ms := 0.0

func _ready() -> void:
	if is_probe:
		process_mode = Node.PROCESS_MODE_ALWAYS
		return
	CurrentRun.selected_character = load("res://actors/player/characters/test_character/test_character.tres")
	CurrentRun.selected_biome = load("res://systems/spawner/biomes/reef_biome.tres")
	CurrentRun.selected_pack_paths = [FIRE_PACK, LIGHTNING_PACK]
	var probe = load("res://levelup_profile_verify.gd").new()
	probe.is_probe = true
	get_tree().root.add_child.call_deferred(probe)
	get_tree().change_scene_to_file.call_deferred("res://world/world.tscn")

func _process(_dt: float) -> void:
	if not is_probe:
		return
	if _booted:
		return
	_boot_frames += 1
	if _boot_frames > 1500:
		print("LUPROFILE ERROR: world never became ready")
		get_tree().quit()
		return
	var player = get_tree().get_first_node_in_group("player")
	var scene := get_tree().current_scene
	if not is_instance_valid(player) or scene == null:
		return
	var um = scene.find_child("UpgradeManager", true, false)
	var lui = scene.find_child("LevelUpUI", true, false)
	if um == null or lui == null or not is_instance_valid(um.player):
		return
	_booted = true
	_run_profile(um, lui)

func _ms(usec_start: int) -> float:
	return (Time.get_ticks_usec() - usec_start) / 1000.0

func _run_profile(um, lui) -> void:
	# Clear the starting-weapon offer if it presented (realistic: the player owns a weapon).
	if lui.visible and not lui.current_upgrades.is_empty():
		var t0 := Time.get_ticks_usec()
		lui._on_upgrade_button_pressed(0)
		print("LUPROFILE starting_pick_apply_ms=%.2f" % _ms(t0))

	# Stage timings, three rounds: first (cold caches) vs later (warm).
	for round_i in range(3):
		var t_choices := Time.get_ticks_usec()
		var choices: Array[Dictionary] = um.get_upgrade_choices(3)
		var choices_ms := _ms(t_choices)

		lui.current_upgrades = choices
		lui._choosing_combo = false
		lui._manipulation_allowed = true
		var t_present := Time.get_ticks_usec()
		lui._present()
		var present_ms := _ms(t_present)

		# Isolate the summary rebuild (the RichTextLabel + tabs + merge bar work inside present).
		var t_summary := Time.get_ticks_usec()
		lui._refresh_summary()
		var summary_ms := _ms(t_summary)

		var t_pick := Time.get_ticks_usec()
		lui._on_upgrade_button_pressed(0)
		var pick_ms := _ms(t_pick)

		print("LUPROFILE round=%d choices_ms=%.2f present_ms=%.2f summary_only_ms=%.2f pick_apply_ms=%.2f" % [
			round_i, choices_ms, present_ms, summary_ms, pick_ms])
		if round_i > 0:
			_worst_stage_ms = maxf(_worst_stage_ms, maxf(maxf(choices_ms, present_ms), pick_ms))

	# The offerable-pool filter alone, warm (the inner loop of choice generation).
	var t_off := Time.get_ticks_usec()
	var off: Array = um.get_offerable_upgrades()
	print("LUPROFILE offerable_ms=%.2f pool=%d" % [_ms(t_off), off.size()])

	# Budget gate: the whole present path must fit in half a frame at 60fps. It was 60ms+ when
	# routine Logs lines echoed to the console (one print() = ~8ms on a Windows console).
	var budget_ok: bool = _worst_stage_ms < 8.0
	print("LUPROFILE worst_stage_ms=%.2f budget=8.00" % _worst_stage_ms)
	print("LUPROFILE RESULT=%s" % ("PASS" if budget_ok else "FAIL"))
	get_tree().quit()
