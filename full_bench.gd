extends Node
## Full-frame benchmark bootstrap (run WITHOUT --headless so rendering is measured).
## Boots straight into a real run (real player + auto-firing daggers + projectiles +
## damage numbers + rendering), then hands off to a persistent probe that spawns a wave
## and measures the whole frame. Menus are bypassed by setting CurrentRun directly.
##   Godot_..._console.exe --path <proj> res://full_bench.tscn -- --count=100

func _ready() -> void:
	var count := 100
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="):
			count = int(arg.split("=")[1])

	CurrentRun.selected_character = load("res://actors/player/characters/edgerunner/edgerunner_character.tres")
	CurrentRun.selected_biome = load("res://systems/spawner/biomes/reef_biome.tres")

	# The probe lives on the SceneTree root so it survives the change into the world scene.
	var probe = preload("res://full_bench_probe.gd").new()
	probe.count = count
	# During _ready the tree is "busy setting up children", so immediate add_child /
	# change_scene error out. Defer both so they run once the tree is idle.
	get_tree().root.add_child.call_deferred(probe)
	get_tree().change_scene_to_file.call_deferred("res://world/world.tscn")
