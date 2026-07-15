extends Node
## Balance benchmark bootstrap -- measures what an item is WORTH. See .claude/balance/workflow.md.
##
## Runs headless (we're measuring damage, not frame time, so rendering is irrelevant here -- unlike
## the perf benches, which must run windowed).
##
##   Godot_..._console.exe --headless --path <proj> res://balance_bench.tscn -- \
##       --weapon=res://systems/upgrades/weapons/fire/fireball_staff/fireball_staff_unlock.tres \
##       --rarity=0 --copies=1 --enemies=40 --secs=20 --immortal=1
##
## rarity: 0=COMMON 1=RARE 2=EPIC 3=LEGENDARY 4=MYTHIC
## immortal=1 -> raw damage output (a ceiling; nothing can be wasted)
## immortal=0 -> real kills against the live population model (captures overkill + AoE self-thinning)

const DEFAULT_WEAPON := "res://systems/upgrades/weapons/fire/fireball_staff/fireball_staff_unlock.tres"

func _ready() -> void:
	var weapon := DEFAULT_WEAPON
	var rarity := 0
	var copies := 1
	var enemies := 40
	var secs := 20.0
	var immortal := true
	var archetype := "baseline"
	var motion := "orbit"

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--archetype="):
			archetype = arg.split("=")[1]
		elif arg.begins_with("--motion="):
			motion = arg.split("=")[1]
		if arg.begins_with("--weapon="):
			weapon = arg.split("=", true, 1)[1]
		elif arg.begins_with("--rarity="):
			rarity = int(arg.split("=")[1])
		elif arg.begins_with("--copies="):
			copies = int(arg.split("=")[1])
		elif arg.begins_with("--enemies="):
			enemies = int(arg.split("=")[1])
		elif arg.begins_with("--secs="):
			secs = float(arg.split("=")[1])
		elif arg.begins_with("--immortal="):
			immortal = int(arg.split("=")[1]) != 0

	# A character with no starting weapon of its own -- the probe clears Equipment anyway, but this
	# keeps the run from being about someone else's kit.
	CurrentRun.selected_character = load("res://actors/player/characters/test_character/test_character.tres")
	CurrentRun.selected_biome = load("res://systems/spawner/biomes/reef_biome.tres")
	# The weapon under test is injected directly, so the draft pool is irrelevant -- but the core deck
	# still loads, and an empty selection is the honest "no upgrades" baseline.
	CurrentRun.selected_pack_paths = []

	var probe = preload("res://balance_bench_probe.gd").new()
	probe.weapon_path = weapon
	probe.rarity = rarity
	probe.copies = copies
	probe.enemy_count = enemies
	probe.seconds = secs
	probe.immortal = immortal
	probe.archetype = archetype
	probe.motion = motion
	get_tree().root.add_child.call_deferred(probe)
	get_tree().change_scene_to_file.call_deferred("res://world/world.tscn")
