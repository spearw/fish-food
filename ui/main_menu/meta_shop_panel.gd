## meta_shop_panel.gd
## Controller for the meta shop panel with tabs for Stats, Characters, and Packs.
extends PanelContainer

signal back_pressed

@export var character_list: CharacterList
@export var pack_list: DeckList
@export var meta_upgrades: Array[MetaUpgrade]
@export var unlock_button_scene: PackedScene
@export var meta_upgrade_button_scene: PackedScene

# Tab buttons
@onready var stats_tab_button: Button = $MarginContainer/VBoxContainer/TabBar/StatsButton
@onready var characters_tab_button: Button = $MarginContainer/VBoxContainer/TabBar/CharactersButton
@onready var packs_tab_button: Button = $MarginContainer/VBoxContainer/TabBar/PacksButton

# Content containers
@onready var stats_content: VBoxContainer = $MarginContainer/VBoxContainer/StatsContent
@onready var characters_content: VBoxContainer = $MarginContainer/VBoxContainer/CharactersContent
@onready var packs_content: VBoxContainer = $MarginContainer/VBoxContainer/PacksContent

# Grids for each tab (inside ScrollContainers)
@onready var stats_grid: GridContainer = $MarginContainer/VBoxContainer/StatsContent/ScrollContainer/GridContainer
@onready var characters_grid: GridContainer = $MarginContainer/VBoxContainer/CharactersContent/ScrollContainer/GridContainer
@onready var packs_grid: GridContainer = $MarginContainer/VBoxContainer/PacksContent/ScrollContainer/GridContainer

# Souls labels for each tab (now in HeaderContainer)
@onready var stats_souls_label: Label = $MarginContainer/VBoxContainer/StatsContent/HeaderContainer/SoulsCount
@onready var characters_souls_label: Label = $MarginContainer/VBoxContainer/CharactersContent/HeaderContainer/SoulsCount
@onready var packs_souls_label: Label = $MarginContainer/VBoxContainer/PacksContent/HeaderContainer/SoulsCount

# Back buttons
@onready var stats_back_button: Button = $MarginContainer/VBoxContainer/StatsContent/BackButton
@onready var characters_back_button: Button = $MarginContainer/VBoxContainer/CharactersContent/BackButton
@onready var packs_back_button: Button = $MarginContainer/VBoxContainer/PacksContent/BackButton

func _ready():
	# Connect tab buttons
	stats_tab_button.pressed.connect(_on_stats_tab_pressed)
	characters_tab_button.pressed.connect(_on_characters_tab_pressed)
	packs_tab_button.pressed.connect(_on_packs_tab_pressed)

	# Connect back buttons
	stats_back_button.pressed.connect(_on_back_button_pressed)
	characters_back_button.pressed.connect(_on_back_button_pressed)
	packs_back_button.pressed.connect(_on_back_button_pressed)

	# Connect to GameData signals for refreshing
	GameData.unlocked_characters_changed.connect(_refresh_characters)
	GameData.unlocked_packs_changed.connect(_refresh_packs)
	GameData.souls_changed.connect(_on_souls_changed)

	# Show stats tab by default
	_on_stats_tab_pressed()

func _on_visibility_changed():
	if visible:
		refresh_all()

func refresh_all():
	_populate_stats()
	_populate_characters()
	_populate_packs()
	_update_souls_display()

func _update_souls_display():
	var souls_text = "Souls: %d" % GameData.data["total_souls"]
	stats_souls_label.text = souls_text
	characters_souls_label.text = souls_text
	packs_souls_label.text = souls_text

# --- Tab Switching ---
func _show_tab(tab_name: String):
	stats_content.hide()
	characters_content.hide()
	packs_content.hide()

	# Update toggle button states
	stats_tab_button.button_pressed = (tab_name == "stats")
	characters_tab_button.button_pressed = (tab_name == "characters")
	packs_tab_button.button_pressed = (tab_name == "packs")

	match tab_name:
		"stats":
			stats_content.show()
		"characters":
			characters_content.show()
		"packs":
			packs_content.show()

func _on_stats_tab_pressed():
	_show_tab("stats")
	_populate_stats()
	_update_souls_display()

func _on_characters_tab_pressed():
	_show_tab("characters")
	_populate_characters()
	_update_souls_display()

func _on_packs_tab_pressed():
	_show_tab("packs")
	_populate_packs()
	_update_souls_display()

func _on_back_button_pressed():
	back_pressed.emit()

# --- Population Functions ---
func _clear_grid(grid: GridContainer):
	for child in grid.get_children():
		child.queue_free()

func _populate_stats():
	_clear_grid(stats_grid)

	if not meta_upgrade_button_scene:
		return

	for upgrade_data in meta_upgrades:
		if not upgrade_data:
			continue
		var button_instance = meta_upgrade_button_scene.instantiate()
		stats_grid.add_child(button_instance)
		button_instance.set_upgrade_data(upgrade_data)
		button_instance.purchased_upgrade.connect(_on_purchase_made)

func _populate_characters():
	_clear_grid(characters_grid)

	if not unlock_button_scene or not character_list:
		return

	var unlocked_chars = GameData.data["unlocked_character_paths"]

	for char_data in character_list.characters:
		# Only show locked characters
		if char_data.resource_path in unlocked_chars:
			continue

		var button = unlock_button_scene.instantiate()
		characters_grid.add_child(button)
		button.set_unlock_data(char_data)
		button.unlock_purchased.connect(_on_character_unlocked)

func _populate_packs():
	_clear_grid(packs_grid)

	if not unlock_button_scene or not pack_list:
		return

	var unlocked_packs = GameData.data["unlocked_pack_paths"]

	for pack_data in pack_list.decks:
		# Only show locked packs
		if pack_data.resource_path in unlocked_packs:
			continue

		var button = unlock_button_scene.instantiate()
		packs_grid.add_child(button)
		button.set_unlock_data(pack_data)
		button.unlock_purchased.connect(_on_pack_unlocked)

# --- Purchase Handlers ---
func _on_purchase_made():
	_update_souls_display()
	# Refresh all buttons to update their affordability state
	_refresh_all_buttons()

func _on_character_unlocked(path: String):
	GameData.unlock_character(path)
	_update_souls_display()

func _on_pack_unlocked(path: String):
	GameData.unlock_pack(path)
	_update_souls_display()

func _refresh_characters():
	_populate_characters()

func _refresh_packs():
	_populate_packs()

func _on_souls_changed(_new_total: int):
	_update_souls_display()
	_refresh_all_buttons()

func _refresh_all_buttons():
	# Update affordability on all visible buttons
	for button in stats_grid.get_children():
		if button.has_method("update_display"):
			button.update_display()
	for button in characters_grid.get_children():
		if button.has_method("update_button_state"):
			button.update_button_state()
	for button in packs_grid.get_children():
		if button.has_method("update_button_state"):
			button.update_button_state()
