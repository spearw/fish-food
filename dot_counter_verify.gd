extends Node
## Headless check that HARD counter mode actually counters a DoT build. Run with --headless.
##   1. The DOT matrix row matches the measured/structural matchups: armor does nothing to DoT
##      (100% pen), fast closers outrace the ramp, one graze applies the full burn.
##   2. BuildAnalyzer sees the flamethrower's DOT tag (the purest DoT weapon was untagged).
##   3. End to end: in HARD mode the director weights a FAST enemy ABOVE an ARMORED one for a DoT
##      build -- the old row did the opposite, countering toxin/fire with the one thing it ignores.

class MockPlayer:
	extends Node2D
	func _init() -> void:
		var equipment := Node2D.new()
		equipment.name = "Equipment"
		add_child(equipment)
		var artifacts := Node2D.new()
		artifacts.name = "Artifacts"
		add_child(artifacts)
	func get_stat(_key): return 1.0
	# BuildAnalyzer gathers via these METHODS, not by walking children.
	func get_weapons() -> Array:
		return get_node("Equipment").get_children()
	func get_artifacts() -> Array:
		return get_node("Artifacts").get_children()

func _fake_enemy(behaviors: Array) -> EnemyStats:
	var stats := EnemyStats.new()
	stats.behavior_tags.assign(behaviors)
	stats.challenge_rating = 1.0
	return stats

func _ready() -> void:
	# --- 1. The matrix row ---
	# DOT=1.8, PIERCE=0.7 and SPARK=0.5 vs ARMORED are SWEEP-MEASURED values (Jul 2026).
	var m_ok: bool = WeaponTags.get_counter_effectiveness(WeaponTags.Effect.DOT, EnemyTags.Behavior.ARMORED) == 1.8 \
		and WeaponTags.get_counter_effectiveness(WeaponTags.Effect.DOT, EnemyTags.Behavior.FAST) == 0.7 \
		and WeaponTags.get_counter_effectiveness(WeaponTags.Effect.DOT, EnemyTags.Behavior.EVASIVE) == 1.3 \
		and WeaponTags.get_counter_effectiveness(WeaponTags.Effect.DOT, EnemyTags.Behavior.RANGED) == 0.8 \
		and WeaponTags.get_counter_effectiveness(WeaponTags.Effect.PIERCE, EnemyTags.Behavior.ARMORED) == 0.7 \
		and WeaponTags.get_counter_effectiveness(WeaponTags.Effect.SPARK, EnemyTags.Behavior.ARMORED) == 0.5
	print("DOTCOUNTER matrix: dot=1.8 pierce=0.7 spark=0.5 (vs armored) fast=0.7 evasive=1.3 ranged=0.8 ok=%s" % str(m_ok))

	# --- 2. BuildAnalyzer sees the flamethrower's DOT tag ---
	var player := MockPlayer.new()
	add_child(player)
	var flamer = load("res://systems/components/flamethrower_weapon.tscn").instantiate()
	player.get_node("Equipment").add_child(flamer)
	var analyzer = BuildAnalyzer.analyze_player(player)
	var sees_dot: bool = analyzer.effect_totals.has(WeaponTags.Effect.DOT)
	print("DOTCOUNTER analyzer_sees_flamethrower_dot=%s" % str(sees_dot))

	# --- 3. The three tiers, end to end, for a DoT build ---
	var director = load("res://systems/spawner/encounter_director.gd").new()
	director.build_analyzer = analyzer
	var fast := _fake_enemy([EnemyTags.Behavior.FAST])
	var armored := _fake_enemy([EnemyTags.Behavior.ARMORED])
	var evasive := _fake_enemy([EnemyTags.Behavior.EVASIVE])

	# ADVERSARIAL ("Abyssal"): the depths hunt the build -- FAST tops.
	CurrentRun.counter_mode = CurrentRun.CounterMode.ADVERSARIAL
	var w_fast: float = director._apply_difficulty_weight(1.0, fast)
	var w_armored: float = director._apply_difficulty_weight(1.0, armored)
	var w_evasive: float = director._apply_difficulty_weight(1.0, evasive)
	var hard_ok: bool = w_fast > w_armored and w_fast > w_evasive
	print("DOTCOUNTER abyssal: fast=%.2f armored=%.2f evasive=%.2f (fast must top) ok=%s" % [
		w_fast, w_armored, w_evasive, str(hard_ok)])

	# FAVORING ("Normal"): the exact inverse -- what you're strong against tops.
	CurrentRun.counter_mode = CurrentRun.CounterMode.FAVORING
	var f_fast: float = director._apply_difficulty_weight(1.0, fast)
	var f_armored: float = director._apply_difficulty_weight(1.0, armored)
	var favoring_ok: bool = f_armored > f_fast and f_armored > 1.0 and f_fast < 1.0
	print("DOTCOUNTER normal(favoring): fast=%.2f armored=%.2f (armored must top) ok=%s" % [
		f_fast, f_armored, str(favoring_ok)])

	# NEUTRAL ("Hard"): the ocean is indifferent -- weights pass through untouched.
	CurrentRun.counter_mode = CurrentRun.CounterMode.NEUTRAL
	var neutral_ok: bool = director._apply_difficulty_weight(1.0, fast) == 1.0 \
		and director._apply_difficulty_weight(1.0, armored) == 1.0
	print("DOTCOUNTER hard(neutral): passthrough ok=%s" % str(neutral_ok))

	# The eff^k dial: k=0 neutralizes counter modes entirely; k=2 amplifies the measured spread.
	CurrentRun.counter_mode = CurrentRun.CounterMode.ADVERSARIAL
	director.counter_strength = 0.0
	var k0: float = director._apply_difficulty_weight(1.0, fast)
	director.counter_strength = 2.0
	var k2: float = director._apply_difficulty_weight(1.0, fast)
	director.counter_strength = 1.0
	var dial_ok: bool = is_equal_approx(k0, 1.0) and k2 > w_fast and absf(k2 - w_fast * w_fast) < 0.01
	print("DOTCOUNTER dial: k=0 -> %.2f (neutral) k=1 -> %.2f k=2 -> %.2f (= k1 squared) ok=%s" % [
		k0, w_fast, k2, str(dial_ok)])

	CurrentRun.counter_mode = CurrentRun.CounterMode.FAVORING  # restore the game default
	director.free()

	var pass_all: bool = m_ok and sees_dot and hard_ok and favoring_ok and neutral_ok and dial_ok
	print("DOTCOUNTER RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
