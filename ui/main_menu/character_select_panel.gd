## character_select_panel.gd -- the run-selection screen, hub-and-overlay model (user spec, Jul
## 2026): the hub is the run AT A GLANCE (character, two deck slots -- visibly empty until picked
## -- biome, difficulty), and clicking any slot opens a full-size overlay: a grid of every option
## with a detail column on the right. Deck tiles distinguish "the one being read" (bright) from
## "the other one already selected" (faded). Confirm applies; Back abandons.
extends Control

const Chrome := preload("res://systems/global/ui_chrome.gd")
const BuildSummary := preload("res://systems/global/build_summary.gd")

@export var character_list: CharacterList
@export var deck_list: DeckList
@export var biome_list: BiomeList

# --- Hub nodes ---
@onready var character_slot: Button = $Hub/PanelContainer/MarginContainer/VBox/SlotsRow/CharacterSlot
@onready var deck1_slot: Button = $Hub/PanelContainer/MarginContainer/VBox/SlotsRow/Deck1Slot
@onready var deck2_slot: Button = $Hub/PanelContainer/MarginContainer/VBox/SlotsRow/Deck2Slot
@onready var biome_slot: Button = $Hub/PanelContainer/MarginContainer/VBox/SlotsRow/BiomeSlot
@onready var difficulty_slot: Button = $Hub/PanelContainer/MarginContainer/VBox/SlotsRow/DifficultySlot
@onready var back_button: Button = $Hub/PanelContainer/MarginContainer/VBox/ButtonsRow/BackButton
@onready var start_button: Button = $Hub/PanelContainer/MarginContainer/VBox/ButtonsRow/StartRunButton
@onready var hint_label: Label = $Hub/PanelContainer/MarginContainer/VBox/HintLabel

# --- Run picks (plain data; the start handler reads exactly these) ---
var selected_character: PlayerStats = null
var selected_deck_paths: Array[String] = []
var selected_biome: BiomeDefinition = null
var selected_intensity: int = 1  # display order: 0=High, 1=Normal, 2=Low
var selected_counter: int = 0    # 0=Normal, 1=Hard, 2=Abyssal

const INTENSITY_NAMES := ["High", "Normal", "Low"]
const COUNTER_NAMES := ["Normal", "Hard", "Abyssal"]
const COUNTER_DESC := [
	"NORMAL -- the ocean favors your build",
	"HARD -- the ocean is indifferent",
	"ABYSSAL -- the depths hunt your build",
]

# --- Overlay state (one generic overlay, reconfigured per slot) ---
var _overlay: Control = null
var _overlay_grid: GridContainer
var _overlay_detail: RichTextLabel
var _overlay_title: Label
var _overlay_confirm: Button
var _overlay_mode := ""
var _overlay_items: Array = []
var _overlay_tiles: Array = []
var _reading_index := -1
var _pending_deck_paths: Array[String] = []

func _ready():
	GameData.unlocked_characters_changed.connect(_refresh_hub)
	GameData.unlocked_packs_changed.connect(_refresh_hub)

	selected_character = load(GameData.data["selected_character_path"])
	var open_biomes := _unlocked_biomes()
	if not open_biomes.is_empty():
		selected_biome = open_biomes[0]

	character_slot.pressed.connect(_open_character_overlay)
	deck1_slot.pressed.connect(_open_deck_overlay)
	deck2_slot.pressed.connect(_open_deck_overlay)
	biome_slot.pressed.connect(_open_biome_overlay)
	difficulty_slot.pressed.connect(_open_difficulty_overlay)
	back_button.pressed.connect(_on_back_button_pressed)
	start_button.pressed.connect(_on_select_and_start_button_pressed)

	Chrome.panel_style($Hub/PanelContainer)
	$Hub/PanelContainer/MarginContainer/VBox/TitleLabel.add_theme_font_size_override("font_size", 30)
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.72))
	Chrome.card_style(back_button, Color(0.35, 0.4, 0.5), 16)
	Chrome.card_style(start_button, Color(0.5, 1.0, 0.6), 16)
	_build_overlay()
	_refresh_hub()

# =========================== THE HUB ===========================

## Each slot card: WHAT it is (header line), WHO holds it now, and a one-liner. Details live in
## the overlays -- the hub is the glance.
func _refresh_hub() -> void:
	_style_slot(character_slot, "CHARACTER",
		selected_character.display_name if selected_character else "(none)",
		_first_sentence(selected_character.character_description) if selected_character else "",
		Chrome.HEADER_COLOR, selected_character != null)
	var names := _selected_deck_names()
	_style_slot(deck1_slot, "DECK 1",
		names[0] if names.size() > 0 else "-- empty --",
		"", Color(0.5, 1.0, 0.6), names.size() > 0)
	_style_slot(deck2_slot, "DECK 2",
		names[1] if names.size() > 1 else "-- empty --",
		"", Color(0.5, 1.0, 0.6), names.size() > 1)
	_style_slot(biome_slot, "BIOME",
		selected_biome.display_name if selected_biome else "(none)",
		_first_sentence(selected_biome.description) if selected_biome else "",
		Color(0.55, 0.85, 1.0), selected_biome != null)
	_style_slot(difficulty_slot, "DIFFICULTY",
		COUNTER_NAMES[selected_counter],
		"%s intensity" % INTENSITY_NAMES[selected_intensity],
		Color(1.0, 0.7, 0.45), true)

func _style_slot(slot: Button, header: String, value: String, sub: String,
		accent: Color, filled: bool) -> void:
	slot.text = "%s\n\n%s" % [header, value]
	if sub != "":
		slot.text += "\n\n%s" % sub
	Chrome.card_style(slot, accent if filled else Color(0.3, 0.34, 0.42), 14)
	slot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot.clip_text = true

func _first_sentence(text: String) -> String:
	var idx := text.find(". ")
	return text.substr(0, idx + 1) if idx > 0 else text

func _selected_deck_names() -> Array:
	var names: Array = []
	for path in selected_deck_paths:
		var deck: Deck = load(path)
		if deck:
			names.append(deck.deck_name)
	return names

# =========================== THE OVERLAY ===========================

## One overlay for every slot: [grid of tiles] | [detail column + Back/Confirm]. Built once.
func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1240, 640)
	Chrome.panel_style(panel)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	margin.add_child(hbox)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	hbox.add_child(left)

	_overlay_title = Label.new()
	Chrome.header_style(_overlay_title, 22)
	left.add_child(_overlay_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 540)
	left.add_child(scroll)

	_overlay_grid = GridContainer.new()
	_overlay_grid.columns = 4
	_overlay_grid.add_theme_constant_override("h_separation", 12)
	_overlay_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_overlay_grid)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(right)

	_overlay_detail = RichTextLabel.new()
	_overlay_detail.bbcode_enabled = true
	_overlay_detail.custom_minimum_size = Vector2(400, 520)
	_overlay_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_overlay_detail.add_theme_font_size_override("normal_font_size", 14)
	_overlay_detail.add_theme_font_size_override("bold_font_size", 15)
	right.add_child(_overlay_detail)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 14)
	right.add_child(buttons)

	var overlay_back := Button.new()
	overlay_back.text = "Back"
	overlay_back.custom_minimum_size = Vector2(120, 0)
	Chrome.card_style(overlay_back, Color(0.35, 0.4, 0.5), 15)
	overlay_back.pressed.connect(func(): _overlay.visible = false)
	buttons.add_child(overlay_back)

	_overlay_confirm = Button.new()
	_overlay_confirm.text = "Confirm"
	_overlay_confirm.custom_minimum_size = Vector2(150, 0)
	Chrome.card_style(_overlay_confirm, Color(0.5, 1.0, 0.6), 15)
	_overlay_confirm.pressed.connect(_on_overlay_confirm)
	buttons.add_child(_overlay_confirm)

## Fills the overlay with tiles. Each item: {name, locked, selected, detail, icon?, data}.
func _open_overlay(mode: String, title: String, items: Array, reading: int) -> void:
	_overlay_mode = mode
	_overlay_items = items
	_overlay_title.text = title
	for child in _overlay_grid.get_children():
		child.queue_free()
	_overlay_tiles.clear()
	for i in range(items.size()):
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(172, 118)
		tile.text = items[i]["name"]
		tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tile.clip_text = true
		if items[i].get("icon") != null:
			tile.icon = items[i]["icon"]
			tile.expand_icon = true
			tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		tile.disabled = items[i].get("locked", false)
		tile.pressed.connect(_on_tile_pressed.bind(i))
		_overlay_grid.add_child(tile)
		_overlay_tiles.append(tile)
	_set_reading(reading)
	_overlay.visible = true

## Reading = the tile whose detail fills the right column (bright accent). A selected-but-not-
## reading deck fades. Locked tiles stay dim. The states ARE the interface.
func _set_reading(index: int) -> void:
	_reading_index = index
	for i in range(_overlay_tiles.size()):
		var tile: Button = _overlay_tiles[i]
		var item: Dictionary = _overlay_items[i]
		if item.get("locked", false):
			Chrome.card_style(tile, Color(0.22, 0.24, 0.3), 13)
			tile.add_theme_color_override("font_color", Color(0.45, 0.48, 0.55))
			continue
		if i == index:
			Chrome.card_style(tile, Chrome.HEADER_COLOR, 13)
		elif item.get("selected", false):
			Chrome.card_style(tile, Color(0.45, 0.6, 0.5, 0.8), 13)
			tile.add_theme_color_override("font_color", Color(0.75, 0.85, 0.78))
		else:
			Chrome.card_style(tile, Color(0.3, 0.34, 0.42), 13)
	if index >= 0 and index < _overlay_items.size():
		_overlay_detail.text = _overlay_items[index]["detail"]

func _on_tile_pressed(index: int) -> void:
	if _overlay_mode == "deck":
		_toggle_deck(index)
		return  # the deck overlay rebuilds itself with fresh selection states
	_set_reading(index)

# --- Character overlay ---

func _open_character_overlay() -> void:
	var unlocked: Array = GameData.data["unlocked_character_paths"]
	var items: Array = []
	var reading := 0
	for i in range(character_list.characters.size()):
		var c: PlayerStats = character_list.characters[i]
		var icon: Texture2D = null
		if c.sprite_frames and c.sprite_frames.has_animation("default"):
			icon = c.sprite_frames.get_frame_texture("default", 0)
		items.append({
			"name": c.display_name,
			"locked": not c.resource_path in unlocked,
			"detail": _character_detail(c),
			"icon": icon,
			"data": c,
		})
		if c == selected_character:
			reading = i
	_open_overlay("character", "Choose Your Character", items, reading)

## Stats plus the identity artifact IN FULL -- the artifact IS the character.
func _character_detail(c: PlayerStats) -> String:
	var lines: Array = []
	lines.append("[b]%s[/b]" % c.display_name)
	lines.append(c.character_description)
	lines.append("")
	lines.append("[b]Base stats[/b]")
	lines.append("Max Health: %d" % c.max_health)
	lines.append("Move Speed: %d" % roundi(c.move_speed))
	lines.append("Luck: %.2f" % c.luck)
	if c.critical_chance > 0.0:
		lines.append("Crit Chance: +%d%% base, on every damage source" % roundi(c.critical_chance * 100))
	if c.critical_damage > 0.0:
		lines.append("Crit Damage: +%d%%" % roundi(c.critical_damage * 100))
	if c.armor > 0:
		lines.append("Armor: %d" % c.armor)
	for upgrade in c.starting_upgrades:
		if upgrade == null:
			continue
		lines.append("")
		lines.append("[b]Identity: %s[/b] (granted, costs no slot)" % upgrade.display_name)
		lines.append(upgrade.description)
	return "\n".join(lines)

# --- Deck overlay ---

func _open_deck_overlay() -> void:
	_pending_deck_paths = selected_deck_paths.duplicate()
	_rebuild_deck_overlay(-1)

func _rebuild_deck_overlay(reading: int) -> void:
	var unlocked: Array = GameData.data["unlocked_pack_paths"]
	var items: Array = []
	var decks := _pickable_decks()
	for i in range(decks.size()):
		var deck: Deck = decks[i]
		items.append({
			"name": deck.deck_name,
			"locked": not deck.resource_path in unlocked,
			"selected": deck.resource_path in _pending_deck_paths,
			"detail": _deck_detail(deck),
			"data": deck,
		})
	if reading < 0:
		reading = 0
		for i in range(decks.size()):
			if decks[i].resource_path in _pending_deck_paths:
				reading = i
				break
	_open_overlay("deck", "Choose Decks (%d/%d selected)" % [_pending_deck_paths.size(),
		CurrentRun.max_themed_decks], items, reading)

func _pickable_decks() -> Array:
	var out: Array = []
	for deck in deck_list.decks:
		if deck != null and not deck.id in ["test", "npc"]:
			out.append(deck)
	return out

func _toggle_deck(index: int) -> void:
	var deck: Deck = _overlay_items[index]["data"]
	if deck.resource_path in _pending_deck_paths:
		_pending_deck_paths.erase(deck.resource_path)
	elif _pending_deck_paths.size() < CurrentRun.max_themed_decks:
		_pending_deck_paths.append(deck.resource_path)
	_rebuild_deck_overlay(index)

## Name, one-liner, the composition, and the FULL card manifest -- everything the pick commits to.
func _deck_detail(deck: Deck) -> String:
	var lines: Array = []
	lines.append("[b]%s[/b]" % deck.deck_name)
	lines.append(deck.deck_description)
	var comp: Dictionary = deck.get_composition()
	lines.append("%d weapons | %d evolutions | %d artifacts | %d stat cards" % [
		comp.get("weapons", 0), comp.get("evolutions", 0),
		comp.get("artifacts", 0), comp.get("upgrades", 0)])
	if deck.resource_path in _pending_deck_paths:
		lines.append("[i]Selected. Click again to deselect.[/i]")
	elif _pending_deck_paths.size() >= CurrentRun.max_themed_decks:
		lines.append("[i]Both slots full. Deselect a deck to make room.[/i]")
	lines.append("")
	lines.append_array(BuildSummary.deck_manifest_lines(deck))
	return "\n".join(lines)

# --- Biome overlay ---

func _open_biome_overlay() -> void:
	var items: Array = []
	var reading := 0
	var biomes := _biomes_with_lock_state()
	for i in range(biomes.size()):
		var entry: Dictionary = biomes[i]
		items.append({
			"name": entry["biome"].display_name if entry["unlocked"] else "LOCKED",
			"locked": not entry["unlocked"],
			"detail": "[b]%s[/b]\n%s" % [entry["biome"].display_name, entry["biome"].description],
			"data": entry["biome"],
		})
		if entry["biome"] == selected_biome:
			reading = i
	_open_overlay("biome", "Choose Your Biome", items, reading)

func _biomes_with_lock_state() -> Array:
	var unlocked: Array = GameData.data.get("unlocked_biome_paths", [])
	var out: Array = []
	for b in biome_list.biomes:
		if b == null:
			continue
		out.append({"biome": b,
			"unlocked": unlocked.is_empty() or b.resource_path in unlocked})
	return out

func _unlocked_biomes() -> Array:
	var out: Array = []
	for entry in _biomes_with_lock_state():
		if entry["unlocked"]:
			out.append(entry["biome"])
	return out

# --- Difficulty overlay ---

func _open_difficulty_overlay() -> void:
	var items: Array = []
	var reading := 0
	for row in range(3):
		for col in range(3):
			var idx := row * 3 + col
			items.append({
				"name": "%s intensity\n%s" % [INTENSITY_NAMES[row], COUNTER_NAMES[col]],
				"detail": "[b]%s intensity[/b]\n%s enemies on screen.\n\n[b]%s[/b]\n%s" % [
					INTENSITY_NAMES[row],
					["More", "The standard number of", "Fewer"][row],
					COUNTER_NAMES[col], COUNTER_DESC[col]],
				"data": [row, col],
			})
			if row == selected_intensity and col == selected_counter:
				reading = idx
	_open_overlay("difficulty", "Choose Your Difficulty", items, reading)

# --- Confirm ---

func _on_overlay_confirm() -> void:
	if _reading_index >= 0 and _reading_index < _overlay_items.size():
		var item: Dictionary = _overlay_items[_reading_index]
		match _overlay_mode:
			"character":
				if not item.get("locked", false):
					selected_character = item["data"]
			"biome":
				if not item.get("locked", false):
					selected_biome = item["data"]
			"difficulty":
				selected_intensity = item["data"][0]
				selected_counter = item["data"][1]
			"deck":
				selected_deck_paths = _pending_deck_paths.duplicate()
	_overlay.visible = false
	_refresh_hub()

# =========================== START ===========================

func _on_select_and_start_button_pressed():
	# Zero decks means an empty draft pool AND no starting weapon -- a dead run. Picking at least
	# one deck is mandatory (the core deck that papered over this is dissolved; doc section 1b).
	if selected_deck_paths.is_empty():
		hint_label.text = "Pick at least one deck to start."
		hint_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
		return

	# Fresh per-run state FIRST -- draft counts, combo/starter flags, manipulation charges,
	# banishes. Without this, run 2 in the same session inherits run 1's flags.
	CurrentRun.reset_run_state()

	GameData.set_selected_character(selected_character.resource_path)
	CurrentRun.selected_character = selected_character
	CurrentRun.selected_pack_paths = selected_deck_paths.duplicate()
	CurrentRun.selected_biome = selected_biome

	# Intensity is inverted into the enum: display row 0 = HIGH (2), 1 = NORMAL (1), 2 = LOW (0).
	CurrentRun.spawn_intensity = (2 - selected_intensity) as CurrentRun.SpawnIntensity
	CurrentRun.counter_mode = selected_counter as CurrentRun.CounterMode

	# Use the BIOME's own encounter config (its native weighting), not a random one.
	CurrentRun.selected_encounter_config = null

	get_tree().change_scene_to_file("res://world/world.tscn")

func _on_back_button_pressed():
	self.hide()
	get_parent().get_node("MainMenuButtons").show()
