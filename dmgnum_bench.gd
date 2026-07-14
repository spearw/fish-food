extends Node
## Damage-number stress benchmark bootstrap (run WITHOUT --headless so rendering is measured).
##   Godot_..._console.exe --path <proj> res://dmgnum_bench.tscn -- --count=150 --hits=150 --agg=1

func _ready() -> void:
	var count := 150
	var hits := 150
	var agg := true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="):
			count = int(arg.split("=")[1])
		elif arg.begins_with("--hits="):
			hits = int(arg.split("=")[1])
		elif arg.begins_with("--agg="):
			agg = int(arg.split("=")[1]) != 0

	CurrentRun.selected_character = load("res://actors/player/characters/edgerunner/edgerunner_character.tres")
	CurrentRun.selected_biome = load("res://systems/spawner/biomes/reef_biome.tres")

	var probe = preload("res://dmgnum_bench_probe.gd").new()
	probe.count = count
	probe.hits_per_frame = hits
	probe.aggregate = agg
	get_tree().root.add_child.call_deferred(probe)
	get_tree().change_scene_to_file.call_deferred("res://world/world.tscn")
