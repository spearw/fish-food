## character_select_panel.gd
extends Control


# Character Select
@export var character_list: CharacterList
@export var character_button_scene: PackedScene

const CONTENT_PATH = "CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer"

@onready var character_grid: GridContainer = get_node(CONTENT_PATH + "/CharactersContainer/GridContainer")
@onready var details_panel: VBoxContainer = get_node(CONTENT_PATH + "/CharactersContainer/VBoxContainer")
@onready var name_label: Label = get_node(CONTENT_PATH + "/CharactersContainer/VBoxContainer/NameLabel")
@onready var description_label: Label = get_node(CONTENT_PATH + "/CharactersContainer/VBoxContainer/DescriptionLabel")

# Navigation Buttons
@onready var back_button: Button = get_node(CONTENT_PATH + "/CharactersContainer/VBoxContainer/HBoxContainer/BackButton")
@onready var select_button: Button = get_node(CONTENT_PATH + "/CharactersContainer/VBoxContainer/HBoxContainer/SelectAndStartButton")

# Decks. The core deck joins every run automatically, so the grid offers only the themed decks --
# any character can pick any pair (identity lives in the granted artifact, not a deck link).
@export var all_packs: DeckList
@export var upgrade_pack_button_scene: PackedScene

@onready var pack_grid: GridContainer = get_node(CONTENT_PATH + "/PacksContainer/ScrollContainer/GridContainer")

# Biomes
@export var all_biomes: BiomeList
@export var biome_button_scene: PackedScene

@onready var biome_grid: GridContainer = get_node(CONTENT_PATH + "/BiomesContainer/ScrollContainer/GridContainer")

# Encounter Configs (randomly selected at run start)
@export var all_encounter_configs: EncounterConfigList

# Difficulty Grid
@onready var difficulty_grid: GridContainer = get_node(CONTENT_PATH + "/DifficultyContainer/GridRow/DifficultyGrid")
@onready var difficulty_description: Label = get_node(CONTENT_PATH + "/DifficultyContainer/DifficultyDescription")

# Background reference for biome color changes
@onready var background_rect: ColorRect = $Background

var selected_character: PlayerStats
var selected_character_button: CharacterButton = null
var selected_packs: Array[DeckButton] = []
var selected_biome_button: BiomeButton = null

# Difficulty selection (row = intensity, col = counter mode)
var selected_intensity: int = 1  # 0=Low, 1=Normal, 2=High
# Counter tiers: 0=Normal (favors your build -- the default experience), 1=Hard (indifferent),
# 2=Abyssal (the depths hunt your build). Default is column 0 on purpose: "Normal" IS favoring.
var selected_counter: int = 0
var difficulty_buttons: Array = []

const Chrome := preload("res://systems/global/ui_chrome.gd")

func _ready():
	GameData.unlocked_characters_changed.connect(populate_character_grid)
	populate_character_grid()

	GameData.unlocked_packs_changed.connect(populate_pack_grid)
	populate_pack_grid()

	# Select current character initially. Characters aren't linked to decks, so the deck grid is
	# character-independent -- any character can run any pair.
	var default_char_path = GameData.data["selected_character_path"]
	var default_char_data = load(default_char_path)
	_select_character_by_data(default_char_data)

	# Populate biomes
	populate_biome_grid()

	# Setup difficulty grid
	_setup_difficulty_grid()
	_apply_chrome()

## The shared look: a real panel, sized headers, readable difficulty cells with tooltips.
func _apply_chrome() -> void:
	Chrome.panel_style($CenterContainer/PanelContainer)
	var vbox = get_node("CenterContainer/PanelContainer/MarginContainer/VBoxContainer")
	var title = vbox.get_node_or_null("TitleLabel")
	if title:
		title.add_theme_font_size_override("font_size", 30)
	for section in ["CharactersContainer/VBoxContainer/SectionLabel", "PacksContainer/Label",
			"BiomesContainer/Label", "DifficultyContainer/Label"]:
		var label = get_node_or_null(CONTENT_PATH + "/" + section)
		if label and label is Label:
			Chrome.header_style(label, 18)
	if name_label:
		name_label.add_theme_font_size_override("font_size", 20)
	if select_button:
		Chrome.card_style(select_button, Color(0.5, 1.0, 0.6), 16)
	if back_button:
		Chrome.card_style(back_button, Color(0.35, 0.4, 0.5), 16)
	# The difficulty grid: readable cells, each explaining itself on hover. Rows are intensity
	# (how many), columns are the counter tiers (who gets sent) -- the description below echoes
	# the current pick, but the tooltip answers "what does THIS cell mean" before committing.
	var intensity_names := ["High", "Normal", "Low"]
	var counter_names := ["Normal", "Hard", "Abyssal"]
	for row in range(difficulty_buttons.size()):
		for col in range(difficulty_buttons[row].size()):
			var btn = difficulty_buttons[row][col]
			btn.custom_minimum_size = Vector2(52, 34)
			btn.tooltip_text = "%s intensity, %s" % [intensity_names[row], counter_names[col]]
	_update_difficulty_selection()
	var grid_row = get_node_or_null(CONTENT_PATH + "/DifficultyContainer/GridRow")
	if grid_row:
		var labels = grid_row.get_node_or_null("IntensityLabels")
		if labels:
			for i in range(mini(labels.get_child_count(), 3)):
				var l = labels.get_child(i)
				if l is Label:
					l.text = intensity_names[i]
	var counter_header = get_node_or_null(CONTENT_PATH + "/DifficultyContainer/CounterLabel")
	if counter_header:
		counter_header.text = "Normal / Hard / Abyssal"
	# The old single-letter column labels under the grid (E/N/H) predate the tier rename; the
	# header row above now carries the names, so these just say the same thing twice, wrong.
	var axis = get_node_or_null(CONTENT_PATH + "/DifficultyContainer/AxisLabels")
	if axis:
		axis.visible = false


func populate_character_grid():
	for child in character_grid.get_children():
		child.queue_free()
	selected_character_button = null

	var unlocked_paths = GameData.data["unlocked_character_paths"]
	for char_data in character_list.characters:
		var button: CharacterButton = character_button_scene.instantiate()
		var is_unlocked = char_data.resource_path in unlocked_paths
		button.set_character(char_data, is_unlocked)
		button.character_selected.connect(_on_character_selected)
		character_grid.add_child(button)

func _on_character_selected(char_data: PlayerStats):
	_select_character_by_data(char_data)

func _select_character_by_data(char_data: PlayerStats):
	# Update details panel
	self.selected_character = char_data
	self.name_label.text = char_data.display_name
	self.description_label.text = char_data.character_description

	# Update visual selection on buttons
	_update_character_selection_visuals(char_data)

func _update_character_selection_visuals(char_data: PlayerStats):
	# Deselect previous
	if selected_character_button:
		selected_character_button.set_selected(false)

	# Find and select new button
	for button in character_grid.get_children():
		if button is CharacterButton and button.character_data == char_data:
			button.set_selected(true)
			selected_character_button = button
			break

func update_details_panel(char_data: PlayerStats):
	# Legacy function for compatibility
	_select_character_by_data(char_data)

func _on_select_and_start_button_pressed():
	# Zero decks means an empty draft pool AND no starting weapon -- a dead run. The core deck used
	# to paper over this with stat cards; now that it's dissolved (design doc section 1b), picking
	# at least one deck is mandatory.
	if get_currently_selected_pack_paths_from_ui().is_empty():
		Logs.add_message("Pick at least one deck to start a run.")
		return

	# Fresh per-run state FIRST -- draft counts, combo/starter flags, manipulation charges, banishes.
	# Without this, run 2 in the same session inherits run 1's flags (no starter roll, no combo).
	CurrentRun.reset_run_state()

	# Save selected character to persisted data
	GameData.set_selected_character(selected_character.resource_path)

	# Populate current run data singleton
	CurrentRun.selected_character = self.selected_character
	CurrentRun.selected_pack_paths = get_currently_selected_pack_paths_from_ui()
	CurrentRun.selected_biome = get_selected_biome()

	# Set difficulty settings from grid selection
	# Intensity is inverted: row 0 = HIGH (2), row 1 = NORMAL (1), row 2 = LOW (0)
	var intensity_value = 2 - selected_intensity
	CurrentRun.spawn_intensity = intensity_value as CurrentRun.SpawnIntensity
	CurrentRun.counter_mode = selected_counter as CurrentRun.CounterMode

	# Use the BIOME's own encounter config (its native weighting), not a random one. Clearing any
	# prior value lets the director fall back to active_biome.encounter_config.
	CurrentRun.selected_encounter_config = null

	# Change scene to game world.
	get_tree().change_scene_to_file("res://world/world.tscn")

func _on_back_button_pressed():
	self.hide()
	get_parent().get_node("MainMenuButtons").show()

func populate_pack_grid():
	if not pack_grid:
		return

	for child in pack_grid.get_children():
		child.queue_free()
	selected_packs.clear()

	var unlocked_paths = GameData.data["unlocked_pack_paths"]
	var remembered: Array = GameData.data.get("selected_pack_paths", [])

	for pack_data in all_packs.decks:
		var button: DeckButton = upgrade_pack_button_scene.instantiate()
		var is_unlocked = pack_data.resource_path in unlocked_paths
		button.set_deck_data(pack_data, is_unlocked)
		button.selection_toggled.connect(_on_pack_selection_toggled)
		pack_grid.add_child(button)

		# Restore last run's picks, up to the run's themed-deck cap.
		if is_unlocked and pack_data.resource_path in remembered \
				and selected_packs.size() < CurrentRun.max_themed_decks:
			button.set_selected(true)
			selected_packs.append(button)

	_update_pool_preview()

func _on_pack_selection_toggled(button_instance: DeckButton):
	if button_instance.is_selected():
		# The button was just checked.
		if not button_instance in selected_packs:
			selected_packs.append(button_instance)

		# Enforce the two-themed-decks rule.
		while selected_packs.size() > CurrentRun.max_themed_decks:
			# Too many selected. Deselect the oldest one.
			var oldest_selection = selected_packs.pop_front()
			oldest_selection.set_selected(false)
	else:
		# The button was just unchecked.
		if button_instance in selected_packs:
			selected_packs.erase(button_instance)
	_update_pool_preview()

# The composed result of the current picks -- pool size and which stats the PAIR carries (missing
# ones dimmed). With the core deck dissolved the pick IS the run's stat economy, so the screen
# shows the contract you're signing, not just the parts (design doc section 1b).
var _pool_preview_label: RichTextLabel
const BuildSummary := preload("res://systems/global/build_summary.gd")

func _update_pool_preview() -> void:
	if not _pool_preview_label:
		_pool_preview_label = RichTextLabel.new()
		_pool_preview_label.bbcode_enabled = true
		_pool_preview_label.fit_content = true
		_pool_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_pool_preview_label.custom_minimum_size = Vector2(0, 44)
		# The grid lives in a ScrollContainer; the preview sits under the whole packs column.
		pack_grid.get_parent().get_parent().add_child(_pool_preview_label)
	var decks: Array = []
	for b in selected_packs:
		decks.append(b.deck_data)
	_pool_preview_label.text = BuildSummary.pool_preview(decks)

# Get the player's chosen decks (the core deck joins automatically at run composition).
func get_currently_selected_pack_paths_from_ui() -> Array[String]:
	var paths: Array[String] = []
	for button in selected_packs:
		paths.append(button.deck_data.resource_path)
	return paths

# --- Biome Selection ---

func populate_biome_grid():
	if not biome_grid or not all_biomes or not biome_button_scene:
		return

	for child in biome_grid.get_children():
		child.queue_free()

	# For now, all biomes are unlocked (can add unlock system later)
	for biome_data in all_biomes.biomes:
		var button: BiomeButton = biome_button_scene.instantiate()
		button.set_biome_data(biome_data, true)  # All unlocked for now
		button.biome_selected.connect(_on_biome_selected)
		biome_grid.add_child(button)

		# Select first biome by default
		if selected_biome_button == null:
			_select_biome_button(button)

func _on_biome_selected(button_instance: BiomeButton):
	_select_biome_button(button_instance)

func _select_biome_button(button: BiomeButton):
	# Deselect previous
	if selected_biome_button:
		selected_biome_button.set_selected(false)

	# Select new
	selected_biome_button = button
	selected_biome_button.set_selected(true)

	# Update background color to match biome
	_update_background_for_biome(button.biome_data)

func _update_background_for_biome(biome: BiomeDefinition):
	if not is_instance_valid(background_rect) or not biome:
		return
	# Smoothly transition the background color
	var tween = create_tween()
	tween.tween_property(background_rect, "color", biome.background_color, 0.3)

func get_selected_biome() -> BiomeDefinition:
	if selected_biome_button:
		return selected_biome_button.biome_data
	return null

# --- Difficulty Grid ---

func _setup_difficulty_grid():
	if not difficulty_grid:
		return

	# Cache buttons and connect signals
	# Grid is 3x3: rows = intensity (Low/Normal/High), cols = counter (Easy/Normal/Hard)
	difficulty_buttons.clear()
	for row in range(3):
		var row_buttons: Array = []
		for col in range(3):
			var btn_name = "Btn_%d_%d" % [row, col]
			var btn = difficulty_grid.get_node_or_null(btn_name)
			if btn:
				row_buttons.append(btn)
				btn.pressed.connect(_on_difficulty_button_pressed.bind(row, col))
		difficulty_buttons.append(row_buttons)

	# Update visuals for default selection (Normal intensity, Normal counter = 1,0)
	_update_difficulty_selection()

func _on_difficulty_button_pressed(intensity: int, counter: int):
	selected_intensity = intensity
	selected_counter = counter
	_update_difficulty_selection()

func _update_difficulty_selection():
	# Update button states -- the picked cell wears the bright accent, the rest stay dim.
	for row in range(3):
		for col in range(3):
			if row < difficulty_buttons.size() and col < difficulty_buttons[row].size():
				var btn = difficulty_buttons[row][col]
				var is_sel: bool = (row == selected_intensity and col == selected_counter)
				btn.button_pressed = is_sel
				Chrome.card_style(btn,
					Chrome.HEADER_COLOR if is_sel else Color(0.28, 0.32, 0.4), 12)

	# Update description label
	if difficulty_description:
		# Intensity is inverted: row 0 = High, row 1 = Normal, row 2 = Low
		var intensity_names = ["High", "Normal", "Low"]
		# The counter tiers ARE the difficulty names. Normal favors the player on purpose -- the
		# genre is built on feeling powerful -- and the top tier is themed to the ocean.
		var counter_desc = [
			"NORMAL -- the ocean favors your build",
			"HARD -- the ocean is indifferent",
			"ABYSSAL -- the depths hunt your build",
		]

		difficulty_description.text = "%s intensity\n%s" % [
			intensity_names[selected_intensity],
			counter_desc[selected_counter]
		]
