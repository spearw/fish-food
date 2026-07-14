extends Node
## Spark stress benchmark bootstrap (run WITHOUT --headless so rendering is measured).
## Boots a real run, then hands off to a probe that directly sustains a live spark population and
## measures frame time. spark_target=0 gives the enemies-only baseline for the same field.
##   Godot_..._console.exe --path <proj> res://spark_bench.tscn -- --count=150 --sparks=250 --bounces=6

func _ready() -> void:
	var count := 150
	var sparks := 250
	var bounces := 6
	var life := 1.0
	var nodmg := false
	var spatial := -1  # -1 = leave SparkProjectile default; 0/1 = force Area2D / spatial-hash
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="):
			count = int(arg.split("=")[1])
		elif arg.begins_with("--sparks="):
			sparks = int(arg.split("=")[1])
		elif arg.begins_with("--bounces="):
			bounces = int(arg.split("=")[1])
		elif arg.begins_with("--life="):
			life = float(arg.split("=")[1])
		elif arg.begins_with("--nodmg="):
			nodmg = int(arg.split("=")[1]) != 0
		elif arg.begins_with("--spatial="):
			spatial = int(arg.split("=")[1])

	# Toggle spark hit-detection mode for the A/B (before any spark spawns).
	if spatial != -1:
		SparkProjectile.use_spatial_hits = spatial != 0
	# Lift the concurrent-spark cap so the bench can measure whatever count it targets.
	ProjectilePool.max_active_sparks = max(sparks + 100, ProjectilePool.max_active_sparks)

	CurrentRun.selected_character = load("res://actors/player/characters/edgerunner/edgerunner_character.tres")
	CurrentRun.selected_biome = load("res://systems/spawner/biomes/reef_biome.tres")

	var probe = preload("res://spark_bench_probe.gd").new()
	probe.count = count
	probe.spark_target = sparks
	probe.spark_bounces = bounces
	probe.spark_lifetime = life
	probe.suppress_dmgnums = nodmg
	get_tree().root.add_child.call_deferred(probe)
	get_tree().change_scene_to_file.call_deferred("res://world/world.tscn")
