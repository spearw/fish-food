extends Node
## Headless check for biome soft-preference + difficulty countering composition. Run with --headless.
##  NORMAL: biome preference alone -> native enemies favored (~80%), off-biome still appears.
##  HARD:   countering divides weight by build effectiveness -> shifts toward the enemy the player is
##          WEAK against (the off-biome ARMORED one here), i.e. clearly less native than NORMAL.

class MockAnalyzer:
	extends BuildAnalyzer
	func get_effectiveness_vs_behavior(behavior: int) -> float:
		if behavior == EnemyTags.Behavior.SWARM:
			return 2.0    # player strong vs the native enemy
		if behavior == EnemyTags.Behavior.ARMORED:
			return 0.5    # player weak vs the off-biome enemy
		return 1.0

func _sample(dir, pool, native, n: int) -> float:
	var c := 0
	for i in n:
		if dir._pick_weighted_enemy(pool) == native:
			c += 1
	return 100.0 * c / float(n)

func _ready() -> void:
	var biome := BiomeDefinition.new()
	biome.biome_tag = EnemyTags.Biome.REEF
	biome.native_preference = 4.0

	var native := EnemyStats.new()
	native.biome_tags = [EnemyTags.Biome.REEF]
	native.behavior_tags = [EnemyTags.Behavior.SWARM]
	var offbiome := EnemyStats.new()
	offbiome.biome_tags = [EnemyTags.Biome.FRESHWATER]
	offbiome.behavior_tags = [EnemyTags.Behavior.ARMORED]

	# Keep the director OUT of the tree so its _ready() (which wants a scene-only $Timer) doesn't run;
	# we call the selection function directly with state we set here.
	var dir = load("res://systems/spawner/encounter_director.gd").new()
	dir.active_biome = biome
	dir.encounter_config = null

	var pool: Array[EnemyStats] = [native, offbiome]

	# NORMAL: no countering -> pure biome preference.
	dir.build_analyzer = null
	CurrentRun.counter_mode = CurrentRun.CounterMode.NEUTRAL
	var normal_pct := _sample(dir, pool, native, 3000)

	# HARD: countering composes on top of the biome preference.
	dir.build_analyzer = MockAnalyzer.new()
	CurrentRun.counter_mode = CurrentRun.CounterMode.ADVERSARIAL
	var hard_pct := _sample(dir, pool, native, 3000)

	var biome_ok := normal_pct > 70.0 and normal_pct < 90.0   # native favored, off-biome still appears
	var counter_ok := hard_pct < normal_pct - 15.0            # HARD clearly shifts away from native
	var ok := biome_ok and counter_ok
	print("BIOMEVERIFY normal_native=%.1f%% hard_native=%.1f%% biome_ok=%s counter_ok=%s RESULT=%s" % [
		normal_pct, hard_pct, str(biome_ok), str(counter_ok), "PASS" if ok else "FAIL"])
	get_tree().quit()
