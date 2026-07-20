extends Node
## Dev bootstrap for the OUT-OF-RUN screens: boots the main menu, screenshots it, opens the
## run-selection panel, screenshots that, quits. Companion to dev_run.gd (the in-run screens).
##   Godot --path . res://dev_menus.tscn -- --shots=C:/path/out_dir
## The probe lives on the tree ROOT: change_scene frees the bootstrap (the verifier trap).

var is_probe := false
var _shots_dir := ""

func _ready() -> void:
	if is_probe:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_capture()
		return
	var probe = load("res://dev_menus.gd").new()
	probe.is_probe = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			probe._shots_dir = arg.substr(8)
	get_tree().root.add_child.call_deferred(probe)
	get_tree().change_scene_to_file.call_deferred("res://ui/main_menu/main_menu.tscn")

func _capture() -> void:
	await get_tree().create_timer(1.0).timeout
	var menu = get_tree().current_scene
	await _snap("menu.png")
	var select = menu.get_node("CharacterSelectPanel")
	menu.get_node("MainMenuButtons").hide()
	select.show()
	await get_tree().create_timer(0.4).timeout
	await _snap("select.png")
	select._open_character_overlay()
	await _snap("select_character.png")
	select._overlay.visible = false
	select._open_deck_overlay()
	await _snap("select_decks.png")
	# The whole click-through, end to end: pick two decks, confirm, start the run.
	select._on_tile_pressed(1)  # Fire
	select._on_tile_pressed(2)  # Lightning
	await _snap("select_decks_picked.png")
	select._on_overlay_confirm()
	await _snap("select_filled.png")
	select._on_select_and_start_button_pressed()
	await get_tree().create_timer(2.0).timeout
	var started: bool = get_tree().current_scene != null \
		and get_tree().current_scene.name == "World"
	print("DEVSHOT run_started=", started)
	get_tree().quit()

func _snap(file_name: String) -> void:
	for i in range(4):
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shots_dir.path_join(file_name))
	print("DEVSHOT saved ", file_name)
