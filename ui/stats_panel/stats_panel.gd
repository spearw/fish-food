## stats_panel.gd
## Displays the player's current stats, weapons, and artifacts.
extends CanvasLayer

# --- Node References ---
@onready var weapons_grid: GridContainer = $PanelContainer/MarginContainer/HBoxContainer/ItemsContainer/WeaponsGridContainer
@onready var artifacts_grid: GridContainer = $PanelContainer/MarginContainer/HBoxContainer/ItemsContainer/ArtifactsGridContainer
@export var weapon_button_scene: PackedScene;
# Labels
@onready var move_speed_label: Label = $PanelContainer/MarginContainer/HBoxContainer/StatsContainer/MoveSpeedLabel
@onready var luck_label: Label = $PanelContainer/MarginContainer/HBoxContainer/StatsContainer/LuckLabel
@onready var pickup_radius_label: Label = $PanelContainer/MarginContainer/HBoxContainer/StatsContainer/PickupRadiusLabel
@onready var critical_chance_label: Label = $PanelContainer/MarginContainer/HBoxContainer/StatsContainer/CriticalChanceLabel
@onready var critical_damage_label: Label = $PanelContainer/MarginContainer/HBoxContainer/StatsContainer/CriticalDamageLabel
@onready var damage_increase_label: Label = $PanelContainer/MarginContainer/HBoxContainer/StatsContainer/DamageMultiplierLabel
@onready var firerate_label: Label = $PanelContainer/MarginContainer/HBoxContainer/StatsContainer/FirerateLabel
@onready var projectile_speed_label: Label = $PanelContainer/MarginContainer/HBoxContainer/StatsContainer/ProjectileSpeedLabel
@onready var area_size_label: Label = $PanelContainer/MarginContainer/HBoxContainer/StatsContainer/AreaSizeLabel
@onready var armor_label: Label = $PanelContainer/MarginContainer/HBoxContainer/StatsContainer/ArmorLabel
# Targeting Picker
@onready var targeting_picker: PanelContainer = $TargetingPicker

var player: Node
var is_open: bool = false

func _ready():
	targeting_picker.hide()

func _unhandled_input(event: InputEvent):
	# The toggle can be handled here because this panel will be in the World scene.
	if event.is_action_pressed("ui_inventory"):
		# This panel only exists in the game world, so we can get the player.
		player = get_tree().get_first_node_in_group("player")
		# Connect to the player's signal to know when to refresh if we're already open.
		# Guarded: re-connecting an already-connected signal is an error, and this ran on EVERY open.
		if is_instance_valid(player) and not player.stats_changed.is_connected(refresh_all_stats):
			player.stats_changed.connect(refresh_all_stats)
		toggle_visibility()
		get_viewport().set_input_as_handled()

func toggle_visibility():
	is_open = not is_open
	visible = is_open
	get_tree().paused = is_open
	if is_open:
		refresh_all_stats()

## Fetches all current data from the player and updates the entire UI.
func refresh_all_stats():
	if not is_instance_valid(player): return
	
	_refresh_player_stats()
	_refresh_weapon_icons()
	_refresh_artifact_icons()

## Every value comes from BuildSummary -- the ONE formatter both this panel and the level-up screen
## consume, so the two can never disagree. (The old inline version had drifted: the projectile-speed
## label was overwritten by a projectile-count line, pickup radius displayed area size, and firerate
## showed a raw wait-multiplier as a percentage.)
const BuildSummary := preload("res://systems/global/build_summary.gd")

# Run context (slots, loadout, combo-gate progress) and the stats the fixed labels don't cover
# (max health, status duration, sparks) -- both created in code, both fed by BuildSummary.
var _run_context_label: Label
var _extras_label: Label

func _refresh_player_stats():
	var stats_container: Node = move_speed_label.get_parent()
	if not _run_context_label:
		_run_context_label = Label.new()
		_run_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats_container.add_child(_run_context_label)
		stats_container.move_child(_run_context_label, 0)
		_extras_label = Label.new()
		_extras_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats_container.add_child(_extras_label)
	var um: Node = player.upgrade_manager if "upgrade_manager" in player else null
	var context_parts: Array = []
	if is_instance_valid(um):
		context_parts.append("%s   %s" % [BuildSummary.slot_line(um), BuildSummary.loadout_line(um)])
	var drafted: String = BuildSummary.draft_line()
	if drafted != "":
		context_parts.append(drafted)
	_run_context_label.text = "\n".join(context_parts)
	_extras_label.text = BuildSummary.extras_line(player)

	var m: Dictionary = BuildSummary.stat_map(player)
	move_speed_label.text = m["move_speed"]
	luck_label.text = m["luck"]
	pickup_radius_label.text = m["pickup"]
	critical_chance_label.text = m["crit_chance"]
	critical_damage_label.text = m["crit_damage"]
	damage_increase_label.text = m["damage"]
	firerate_label.text = m["attack_speed"]
	projectile_speed_label.text = "%s   %s" % [m["projectile_speed"], m["projectile_count"]]
	area_size_label.text = "%s   %s   %s" % [m["area"], m["dot"], m["status_chance"]]
	armor_label.text = m["armor"]

# Shows the clicked weapon's live numbers. Created on first use (no scene surgery).
var _weapon_detail_label: Label

func _refresh_weapon_icons():
	for child in weapons_grid.get_children(): child.queue_free()

	var equipment = player.get_node("Equipment")
	for weapon in equipment.get_children():

		# Create targeting button for each weapon
		var button = weapon_button_scene.instantiate()
		button.weapon_node = weapon
		# The buttons collapsed to ~zero size (icons are TODO, so they were empty) and piled onto
		# one spot -- unclickable. A minimum size and a NAME (with tier) make them a real row.
		button.custom_minimum_size = Vector2(150, 44)
		if "rarity" in weapon:
			button.text = "%s (%s)%s" % [
				BuildSummary._pretty_name(String(weapon.get_meta("weapon_type", weapon.name))),
				Upgrade.Rarity.keys()[weapon.rarity].capitalize(),
				"*" if weapon.is_transformed else ""]
		var icon_rect = button.get_node("Icon")
		if weapon.projectile_stats:
			icon_rect.texture = weapon.projectile_stats.texture

		# Pass the weapon node reference directly with the signal.
		button.pressed.connect(_on_weapon_button_pressed.bind(weapon))
		# Clicking also shows the weapon's ACTUAL numbers (player multipliers applied).
		button.pressed.connect(func(): _show_weapon_detail(weapon))

		weapons_grid.add_child(button)

func _show_weapon_detail(weapon: Node) -> void:
	if not _weapon_detail_label:
		_weapon_detail_label = Label.new()
		_weapon_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		weapons_grid.get_parent().add_child(_weapon_detail_label)
	_weapon_detail_label.text = BuildSummary.weapon_detail_line(weapon, player)

func _refresh_artifact_icons():
	for child in artifacts_grid.get_children(): child.queue_free()

	# NAMES, not empty rectangles -- identity artifacts, combo synergies, and every drafted
	# artifact were literally invisible here (the old loop added blank TextureRects; icons are
	# still TODO). Node names are "EmberheartArtifact"-style.
	var artifacts = player.get_node("Artifacts")
	for artifact in artifacts.get_children():
		var label := Label.new()
		label.text = BuildSummary._pretty_name(String(artifact.name).replace("Artifact", ""))
		label.custom_minimum_size = Vector2(150, 24)
		artifacts_grid.add_child(label)
		
## Called when any weapon button in the grid is clicked.
func _on_weapon_button_pressed(weapon_node: Node):
	Logs.add_message(["Player clicked on weapon: ", weapon_node.name])
	# Tell the picker to open and configure itself for the selected weapon.
	targeting_picker.open_for_weapon(weapon_node)
