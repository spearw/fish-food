## biome_button.gd
## A button for selecting a BiomeDefinition in the pre-run screen.
class_name BiomeButton
extends PanelContainer

# Signal to notify the parent when this biome is selected.
signal biome_selected(button_instance)

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var select_button: Button = $SelectButton
@onready var selection_border: Panel = $SelectionBorder

var biome_data: BiomeDefinition
var is_unlocked: bool = false
var _is_selected: bool = false

const Chrome := preload("res://systems/global/ui_chrome.gd")

func _ready():
	Chrome.panel_style(self, Color(0.3, 0.36, 0.46, 0.9))
	if is_instance_valid(name_label):
		name_label.add_theme_font_size_override("font_size", 16)
	if is_instance_valid(description_label):
		description_label.add_theme_font_size_override("font_size", 12)
		description_label.add_theme_color_override("font_color", Color(0.78, 0.8, 0.85))
	update_display()
	select_button.pressed.connect(_on_button_pressed)

func set_biome_data(data: BiomeDefinition, unlocked: bool):
	self.biome_data = data
	self.is_unlocked = unlocked

func update_display():
	if not is_node_ready():
		return

	name_label.text = biome_data.display_name if is_unlocked else "LOCKED"
	description_label.text = biome_data.description if is_unlocked else ""

	if is_unlocked:
		self.modulate = Color.WHITE
		select_button.disabled = false
	else:
		self.modulate = Color.DARK_GRAY
		select_button.disabled = true

	_update_selected_visual()

## Public property to get the selection state.
func is_selected() -> bool:
	return _is_selected

## Public method to set the selection state from the parent.
func set_selected(value: bool):
	_is_selected = value
	_update_selected_visual()

func _update_selected_visual():
	if not is_instance_valid(selection_border):
		return
	selection_border.visible = _is_selected

## Internal signal handler.
func _on_button_pressed():
	if is_unlocked:
		biome_selected.emit(self)
