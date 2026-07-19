## world.gd
## Manages the main game state and scene-level logic.
extends Node2D

# The time in seconds the player must survive to win.
@export var survival_goal_seconds: float = 1200.0
var game_time: float = 0.0
var is_game_over: bool = false
# Win fires exactly once; going infinite resumes the run past it.
var _win_shown: bool = false
var is_infinite: bool = false

# Player references
@export var player_scene: PackedScene
@onready var player: CharacterBody2D = null

# Game references.
@onready var upgrade_manager: Node = $UpgradeManager
@onready var spawner: Node = $EncounterDirector
@onready var level_up_ui: CanvasLayer = $LevelUpUI

# Hud
@onready var hud: CanvasLayer = $HUD

# Background
@onready var background_sprite: Sprite2D = $ParallaxBackground/ParallaxLayer/Sprite2D

## Called once when the node enters the scene tree.
func _ready() -> void:
	# Apply biome background color
	_apply_biome_visuals()

	# Check if a character was selected for the current run.
	if CurrentRun.selected_character:
		# Instance our generic player scene.
		player = player_scene.instantiate()
		# Add player to scene tree
		add_child(player)
		# Init spawner.
		spawner.player_node = player
		# Init level up logic.
		level_up_ui.player_node = player
		level_up_ui.player_node.leveled_up.connect(level_up_ui.on_player_leveled_up)
		# Init stats.
		player.initialize_character(CurrentRun.selected_character, upgrade_manager)
		
		player.died.connect(_on_player_died)
		# The win rides the leviathan's death when this run has one (the director draws it); the
		# timer alone no longer ends the run -- see _physics_process.
		Events.leviathan_killed.connect(_on_leviathan_killed)
	else:
		# Failsafe in case we somehow get here without selecting a character.
		printerr("World: No character selected in CurrentRun! Returning to main menu.")
		get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")
		return

func _physics_process(delta: float):
	# Don't advance the timer if the game has ended.
	if is_game_over:
		return
		
	game_time += delta

	# Update the HUD with the new time.
	hud.update_time(game_time)

	# The win condition (once -- going infinite keeps the clock and spawns running).
	# With a leviathan drawn, reaching the goal spawns the final fight instead of the win screen
	# (the director handles the spawn at its own win_time); the win fires on the kill. Worlds with
	# no leviathan (benches, test setups) keep the plain timer win.
	if game_time >= survival_goal_seconds and not _win_shown \
			and CurrentRun.leviathan_stats == null:
		_win_shown = true
		win_game()

## Survive to 20:00 AND slay what surfaces: the leviathan's death is the win.
func _on_leviathan_killed(_stats) -> void:
	if _win_shown or is_game_over:
		return
	_win_shown = true
	win_game()
		
func _on_player_died():
	if is_game_over: return # Prevent this from running twice
	
	is_game_over = true
	Logs.add_message("GAME OVER - YOU LOSE")
	
	# We can create a simple game over screen later.
	# For now, we'll just pause the tree.
	get_tree().paused = true

func win_game():
	Logs.add_message("VICTORY - YOU SURVIVED!")
	# The tree pause halts EVERYTHING -- including the spawner's pulse Timer, which the old
	# set_physics_process(false) never touched (that was the "enemies keep spawning at 20:00" bug;
	# physics-process off only froze the director's clock, not its spawn timer).
	level_up_ui.show_win_screen()

## The player chose to keep going: the clock and spawns resume, and the director's infinite
## scaling (a mild exponential past win_time) takes over where the authored curve ends.
func go_infinite():
	is_infinite = true
	Logs.add_message("GOING INFINITE - the depths keep rising")

## Applies visual changes based on the selected biome.
func _apply_biome_visuals():
	if CurrentRun.selected_biome and background_sprite:
		background_sprite.modulate = CurrentRun.selected_biome.background_color
	
