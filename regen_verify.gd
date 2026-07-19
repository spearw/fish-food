extends Node
## Headless check of the regenerator (the DoT counter) in the booted world:
##   1. Constant regen: a damaged sea star heals back with no further interaction.
##   2. Size scaling: the spawned instance's regen matches base x its size's HP multiplier.
##   3. Direct DPS races it: repeated direct hits net progress and kill it.
##   4. Walled logic: a pure-DoT build is regen-walled; ANY direct source clears it; armor
##      walls are unchanged; the field count sees regen walls.
##   5. The counter matrix carries the authored REGENERATOR column (DOT weak, hit-volume strong).
## Run with --headless.

var is_probe := false
var _booted := false
var _boot_frames := 0

const SEA_STAR := "res://actors/enemies/normal_enemy_types/sea_star/sea_star.tres"

func _ready() -> void:
	if is_probe:
		process_mode = Node.PROCESS_MODE_ALWAYS
		return
	CurrentRun.reset_run_state()
	CurrentRun.selected_character = load("res://actors/player/characters/test_character/test_character.tres")
	CurrentRun.selected_biome = load("res://systems/spawner/biomes/reef_biome.tres")
	CurrentRun.selected_pack_paths = []
	var probe = load("res://regen_verify.gd").new()
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
		print("REGEN ERROR: world never became ready")
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
	_run(director, player)

func _run(director, player) -> void:
	director.spawn_pulse_timer.stop()

	# --- 1 + 2. Constant regen on the spawned instance, scaled by its rolled size ---
	var star = director.spawn_enemy(load(SEA_STAR), player.global_position + Vector2.RIGHT * 600.0)
	await get_tree().physics_frame
	var hp_mult: float = EnemyTags.get_size_multipliers(star.spawned_size)["hp"]
	var scale_ok: bool = absf(star.stats.regen_per_sec - 8.0 * hp_mult) < 0.01
	star.current_health = int(star.stats.max_health * 0.5)
	var hp_before: int = star.current_health
	for i in range(75):  # ~1.25s at 60fps -> ~10 HP at base regen
		await get_tree().physics_frame
	var healed: int = star.current_health - hp_before
	var regen_ok: bool = healed >= 5
	print("REGEN heal: size=%s regen=%.1f scaled_ok=%s healed=%d ok=%s" % [
		EnemyTags.Size.keys()[star.spawned_size], star.stats.regen_per_sec,
		str(scale_ok), healed, str(regen_ok)])

	# --- 3. Direct DPS races the healing and wins ---
	var dead := false
	for i in range(240):
		await get_tree().physics_frame
		if not is_instance_valid(star) or star.is_dying:
			dead = true
			break
		if i % 6 == 0:  # ~10 hits/s of 8 damage >> 8 HP/s regen
			star.take_damage(8, 0.0, false, null)
	print("REGEN direct_dps_wins: %s" % str(dead))

	# --- 4. Walled logic ---
	var star_stats: EnemyStats = load(SEA_STAR)
	var pure_dot := {"sources": [{"damage": 0.0, "armor_pen": 0.0, "dot": true, "dot_tick": 4.0}],
		"any_dot": true, "any_direct": false, "chip_floor": false}
	var mixed := {"sources": [{"damage": 10.0, "armor_pen": 0.0, "dot": true, "dot_tick": 4.0}],
		"any_dot": true, "any_direct": true, "chip_floor": false}
	var dagger_like := {"sources": [{"damage": 10.0, "armor_pen": 0.0, "dot": false}],
		"any_dot": false, "any_direct": true, "chip_floor": false}
	var walled_pure_ok: bool = director._is_walled_candidate(star_stats, pure_dot)
	var open_mixed_ok: bool = not director._is_walled_candidate(star_stats, mixed)
	var open_direct_ok: bool = not director._is_walled_candidate(star_stats, dagger_like)
	# Armor walls unchanged: the old mock shape (no any_direct key) still armor-walls.
	var legacy_build := {"sources": [{"damage": 10.0, "armor_pen": 0.0, "dot": false}],
		"any_dot": false}
	var armor_stats: EnemyStats = star_stats.duplicate()
	armor_stats.regen_per_sec = 0.0
	armor_stats.armor = 15
	var armor_wall_ok: bool = director._is_walled_candidate(armor_stats, legacy_build)
	# The live field count sees a regen wall for a pure-DoT build.
	var star2 = director.spawn_enemy(load(SEA_STAR), player.global_position + Vector2.RIGHT * 650.0)
	await get_tree().physics_frame
	EntityRegistry._rebuild_grid()
	var field: Dictionary = director._count_walled_field(pure_dot)
	var field_ok: bool = field["walled"] >= 1
	star2.take_damage(999999, 1.0, false, null)
	print("REGEN walls: pure_dot=%s mixed_open=%s direct_open=%s armor_unchanged=%s field=%s" % [
		str(walled_pure_ok), str(open_mixed_ok), str(open_direct_ok),
		str(armor_wall_ok), str(field_ok)])

	# --- 5. The authored matrix column ---
	var matrix_ok: bool = \
		WeaponTags.COUNTER_MATRIX[WeaponTags.Effect.DOT][EnemyTags.Behavior.REGENERATOR] == 0.5 \
		and WeaponTags.COUNTER_MATRIX[WeaponTags.Effect.HIGH_FIRE_RATE][EnemyTags.Behavior.REGENERATOR] == 1.4 \
		and WeaponTags.COUNTER_MATRIX[WeaponTags.Effect.SPARK][EnemyTags.Behavior.REGENERATOR] == 1.4 \
		and WeaponTags.COUNTER_MATRIX[WeaponTags.Effect.CHAIN][EnemyTags.Behavior.REGENERATOR] == 1.3
	print("REGEN matrix: %s" % str(matrix_ok))

	var pass_all: bool = scale_ok and regen_ok and dead and walled_pure_ok and open_mixed_ok \
		and open_direct_ok and armor_wall_ok and field_ok and matrix_ok
	print("REGEN RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
