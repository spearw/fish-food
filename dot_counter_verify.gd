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
	var m_ok: bool = WeaponTags.get_counter_effectiveness(WeaponTags.Effect.DOT, EnemyTags.Behavior.ARMORED) == 1.5 \
		and WeaponTags.get_counter_effectiveness(WeaponTags.Effect.DOT, EnemyTags.Behavior.FAST) == 0.7 \
		and WeaponTags.get_counter_effectiveness(WeaponTags.Effect.DOT, EnemyTags.Behavior.EVASIVE) == 1.3 \
		and WeaponTags.get_counter_effectiveness(WeaponTags.Effect.DOT, EnemyTags.Behavior.RANGED) == 0.8
	print("DOTCOUNTER matrix: armored=1.5 fast=0.7 evasive=1.3 ranged=0.8 ok=%s" % str(m_ok))

	# --- 2. BuildAnalyzer sees the flamethrower's DOT tag ---
	var player := MockPlayer.new()
	add_child(player)
	var flamer = load("res://systems/components/flamethrower_weapon.tscn").instantiate()
	player.get_node("Equipment").add_child(flamer)
	var analyzer = BuildAnalyzer.analyze_player(player)
	var sees_dot: bool = analyzer.effect_totals.has(WeaponTags.Effect.DOT)
	print("DOTCOUNTER analyzer_sees_flamethrower_dot=%s" % str(sees_dot))

	# --- 3. HARD mode: FAST outweighs ARMORED for this build ---
	var director = load("res://systems/spawner/encounter_director.gd").new()
	director.build_analyzer = analyzer
	CurrentRun.counter_mode = CurrentRun.CounterMode.HARD
	var w_fast: float = director._apply_difficulty_weight(1.0, _fake_enemy([EnemyTags.Behavior.FAST]))
	var w_armored: float = director._apply_difficulty_weight(1.0, _fake_enemy([EnemyTags.Behavior.ARMORED]))
	var w_evasive: float = director._apply_difficulty_weight(1.0, _fake_enemy([EnemyTags.Behavior.EVASIVE]))
	CurrentRun.counter_mode = CurrentRun.CounterMode.NORMAL
	director.free()
	var hard_ok: bool = w_fast > w_armored and w_fast > w_evasive
	print("DOTCOUNTER hard_weights: fast=%.2f armored=%.2f evasive=%.2f (fast must top) ok=%s" % [
		w_fast, w_armored, w_evasive, str(hard_ok)])

	var pass_all: bool = m_ok and sees_dot and hard_ok
	print("DOTCOUNTER RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
