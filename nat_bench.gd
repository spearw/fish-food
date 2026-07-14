extends Node
## Natural-spawn benchmark bootstrap (run WITHOUT --headless so rendering is measured).
## Boots straight into a real run, then hands off to a persistent probe that forces the difficulty
## time and lets the director spawn/recycle naturally -- verifying the population self-bounds.
##   Godot_..._console.exe --path <proj> res://nat_bench.tscn -- --sim=1195

func _ready() -> void:
	var sim := 1195.0
	var scale := 0.0
	var perfmode := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sim="):
			sim = float(arg.split("=")[1])
		elif arg.begins_with("--scale="):
			scale = float(arg.split("=")[1])
		elif arg.begins_with("--perfmode="):
			perfmode = int(arg.split("=")[1]) != 0

	# Bench-only: apply the GameSettings performance toggles WITHOUT persisting them to disk.
	if perfmode:
		GameSettings.show_damage_numbers = false
		GameSettings.show_health_bars = false
		GameSettings.show_status_vfx = false

	CurrentRun.selected_character = load("res://actors/player/characters/edgerunner/edgerunner_character.tres")
	CurrentRun.selected_biome = load("res://systems/spawner/biomes/reef_biome.tres")

	# The probe lives on the SceneTree root so it survives the change into the world scene.
	var probe = preload("res://nat_bench_probe.gd").new()
	probe.sim_time = sim
	probe.scale_override = scale
	# During _ready the tree is "busy setting up children", so defer both the add and the scene swap.
	get_tree().root.add_child.call_deferred(probe)
	get_tree().change_scene_to_file.call_deferred("res://world/world.tscn")
