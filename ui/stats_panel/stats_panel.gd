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
	_wire_stat_tooltips()
	_apply_chrome()

## The pause sheet's look: a real panel (dark, bordered, centered by the scene) with readable type.
## The old sheet was a transparent top-left rectangle of default-size text on the game world.
func _apply_chrome() -> void:
	var panel: PanelContainer = $PanelContainer
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.1, 0.13, 0.97)
	sb.border_color = Color(0.5, 0.65, 0.85, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	# Section headers plus a size bump on every fixed stat row.
	var stats_container: Node = move_speed_label.get_parent()
	var stats_header := Label.new()
	stats_header.text = "BUILD"
	stats_header.add_theme_font_size_override("font_size", 22)
	stats_header.add_theme_color_override("font_color", Color(0.65, 0.8, 1.0))
	stats_container.add_child(stats_header)
	stats_container.move_child(stats_header, 0)
	stats_container.add_theme_constant_override("separation", 6)
	for label in [move_speed_label, luck_label, pickup_radius_label, critical_chance_label,
			critical_damage_label, damage_increase_label, firerate_label,
			projectile_speed_label, area_size_label, armor_label]:
		label.add_theme_font_size_override("font_size", 15)
	var items: Node = $PanelContainer/MarginContainer/HBoxContainer/ItemsContainer
	items.add_theme_constant_override("separation", 8)
	for header in [items.get_node("Weapons"), items.get_node("Artifacts")]:
		header.add_theme_font_size_override("font_size", 18)
		header.add_theme_color_override("font_color", Color(0.65, 0.8, 1.0))

## Hover definitions on the stat rows that have glossary entries -- the same one-place definitions
## the card tooltips use. Labels ignore the mouse by default, so opting in is part of the wiring.
func _wire_stat_tooltips() -> void:
	var map := {
		critical_chance_label: "Crit",
		critical_damage_label: "Crit",
		armor_label: "Armor",
	}
	for label in map:
		if label:
			label.mouse_filter = Control.MOUSE_FILTER_STOP
			label.tooltip_text = "%s: %s" % [map[label], Glossary.KEYWORDS[map[label]]]

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
const Glossary := preload("res://systems/global/glossary.gd")

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
	var dealt: String = BuildSummary.damage_report_line()
	if dealt != "":
		context_parts.append(dealt)
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

	# The run's top damage source gets the highlight -- one glance answers "what's carrying".
	var top_key := ""
	var top_dealt := 0
	for k in CurrentRun.damage_by_source:
		if CurrentRun.damage_by_source[k] > top_dealt:
			top_dealt = CurrentRun.damage_by_source[k]
			top_key = k

	var equipment = player.get_node("Equipment")
	for weapon in equipment.get_children():

		# Create targeting button for each weapon
		var button = weapon_button_scene.instantiate()
		button.weapon_node = weapon
		# The buttons collapsed to ~zero size (icons are TODO, so they were empty) and piled onto
		# one spot -- unclickable. A minimum size and a NAME (with tier) make them a real row.
		button.custom_minimum_size = Vector2(150, 44)
		var weapon_key := String(weapon.get_meta("weapon_type", weapon.name))
		# Text starts right of the icon slot instead of centering into it.
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var row_sb := StyleBoxFlat.new()
		row_sb.bg_color = Color(0.13, 0.15, 0.19, 0.9)
		row_sb.set_corner_radius_all(4)
		row_sb.set_content_margin_all(6)
		row_sb.content_margin_left = 44
		button.add_theme_stylebox_override("normal", row_sb)
		if "rarity" in weapon:
			button.text = "%s (%s)%s" % [
				BuildSummary._pretty_name(weapon_key),
				Upgrade.Rarity.keys()[weapon.rarity].capitalize(),
				"*" if weapon.is_transformed else ""]
			# The row wears the weapon's CURRENT tier -- reads from the live node every refresh,
			# so a merge recolors it the next time the sheet opens (user ask, Jul 2026).
			var tier_color: Color = BuildSummary.rarity_color(weapon.rarity)
			button.add_theme_color_override("font_color", tier_color)
			button.add_theme_color_override("font_hover_color", tier_color.lightened(0.25))
			button.add_theme_font_size_override("font_size", 15)
		var dealt: int = CurrentRun.damage_by_source.get(weapon_key, 0)
		if dealt > 0:
			button.text += "  %s dmg" % BuildSummary.fmt_int(dealt)
		if weapon_key == top_key and top_dealt > 0:
			# Top damage source: a gold border, not a gold tint (a tint would fight the tier color).
			var gold := StyleBoxFlat.new()
			gold.bg_color = Color(0.14, 0.13, 0.08, 0.9)
			gold.border_color = Color.GOLD
			gold.set_border_width_all(2)
			gold.set_corner_radius_all(4)
			gold.set_content_margin_all(6)
			gold.content_margin_left = 44
			button.add_theme_stylebox_override("normal", gold)
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
		# Name AND rule: an artifact IS its rule, so the sheet says it in full (stamped on the
		# node at creation; the node-name fallback covers artifacts from older paths).
		var display: String = artifact.get_meta("display_name",
			String(artifact.name).replace("Artifact", "").replace("_", " ").capitalize())
		var rule: String = artifact.get_meta("description", "")
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		var name_l := Label.new()
		name_l.text = display
		name_l.add_theme_font_size_override("font_size", 15)
		row.add_child(name_l)
		if rule != "":
			var rule_l := Label.new()
			rule_l.text = rule
			rule_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rule_l.custom_minimum_size = Vector2(300, 0)
			rule_l.add_theme_font_size_override("font_size", 12)
			rule_l.add_theme_color_override("font_color", Color(0.75, 0.78, 0.84))
			row.add_child(rule_l)
			name_l.mouse_filter = Control.MOUSE_FILTER_STOP
			name_l.tooltip_text = Glossary.tooltip_for(rule)
		artifacts_grid.add_child(row)
		
## Called when any weapon button in the grid is clicked.
func _on_weapon_button_pressed(weapon_node: Node):
	Logs.add_message(["Player clicked on weapon: ", weapon_node.name])
	# Tell the picker to open and configure itself for the selected weapon.
	targeting_picker.open_for_weapon(weapon_node)
