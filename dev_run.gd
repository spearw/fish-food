extends Node
## Dev bootstrap: boots straight into a run with a stocked build, opens each UI screen, saves
## screenshots, and quits -- the edit-and-eyeball loop without driving the desktop. Run:
##   Godot --path . res://dev_run.tscn -- --shots=C:/path/out_dir
## Without --shots it stays open for hand-testing. Grants mixed-tier weapons plus artifacts so
## the pause menu has something to show.

var is_probe := false
var _booted := false
var _frames := 0
var _shots_dir := ""

func _ready() -> void:
	if is_probe:
		process_mode = Node.PROCESS_MODE_ALWAYS
		return
	CurrentRun.reset_run_state()
	CurrentRun.selected_character = load("res://actors/player/characters/test_character/test_character.tres")
	CurrentRun.selected_biome = load("res://systems/spawner/biomes/reef_biome.tres")
	CurrentRun.selected_pack_paths = [
		"res://systems/upgrades/packs/fire_pack.tres",
		"res://systems/upgrades/packs/lightning_pack.tres"]
	var probe = load("res://dev_run.gd").new()
	probe.is_probe = true
	get_tree().root.add_child.call_deferred(probe)
	get_tree().change_scene_to_file.call_deferred("res://world/world.tscn")

func _process(_dt: float) -> void:
	if not is_probe or _booted:
		return
	_frames += 1
	var scene := get_tree().current_scene
	var player = get_tree().get_first_node_in_group("player")
	if scene == null or not is_instance_valid(player):
		return
	var um = scene.find_child("UpgradeManager", true, false)
	var lui = scene.find_child("LevelUpUI", true, false)
	if um == null or lui == null or not is_instance_valid(um.player):
		return
	_booted = true
	# Clear the starting-weapon offer, then stock a mixed-tier build.
	if lui.visible and not lui.current_upgrades.is_empty():
		lui._on_upgrade_button_pressed(0)
	um.apply_upgrade({"upgrade": load("res://systems/upgrades/weapons/daggers_unlock.tres"),
		"rarity": Upgrade.Rarity.RARE})
	um.apply_upgrade({"upgrade": load("res://systems/upgrades/weapons/fire/fireball_staff/fireball_staff_unlock.tres"),
		"rarity": Upgrade.Rarity.EPIC})
	um.apply_upgrade({"upgrade": load("res://systems/upgrades/artifacts/venom/lethal_dose_unlock.tres"),
		"rarity": Upgrade.Rarity.LEGENDARY})
	CurrentRun.deck_draft_counts = {"fire": 3, "lightning": 2}
	CurrentRun.credit_damage("Daggers", 12400)
	CurrentRun.credit_damage("FireballStaffWeapon", 5200)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.substr(8)
	if _shots_dir == "":
		self.queue_free()
		return
	_capture_screens(scene, lui)

## Opens each UI surface, lets it render, saves a PNG, moves on, quits.
func _capture_screens(scene, lui) -> void:
	await get_tree().create_timer(1.5).timeout
	await _snap("gameplay.png")

	var sp = scene.find_child("StatsPanel", true, false)
	if sp:
		# The input path assigns the player before toggling; mirror it or the sheet opens empty.
		var player = get_tree().get_first_node_in_group("player")
		sp.player = player
		sp.toggle_visibility()
		await _snap("pause.png")
		var equipment = player.get_node("Equipment")
		if equipment.get_child_count() > 0:
			sp.targeting_picker.open_for_weapon(equipment.get_child(0))
			await _snap("targeting.png")
			sp.targeting_picker.close()
		sp.toggle_visibility()

	get_tree().paused = false
	lui.show_upgrade_screen()
	await _snap("levelup.png")

	get_tree().quit()

func _snap(file_name: String) -> void:
	for i in range(4):
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shots_dir.path_join(file_name))
	print("DEVSHOT saved ", file_name)
