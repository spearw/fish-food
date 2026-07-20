## upgrade_pack_button.gd  (class: DeckButton)
## A button for selecting a Deck in the pre-run screen. (Formerly "UpgradePackButton".)
class_name DeckButton
extends PanelContainer

# Signal to notify the parent when the selection state changes.
# Passes itself as an argument so the parent knows which button was toggled.
signal selection_toggled(button_instance)

@onready var icon_rect: TextureRect = $MarginContainer/VBoxContainer/HeaderRow/IconRect
@onready var name_label: Label = $MarginContainer/VBoxContainer/HeaderRow/NameLabel
@onready var description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var select_button: Button = $SelectButton
@onready var selection_border: Panel = $SelectionBorder

var deck_data: Deck
var is_unlocked: bool = false
var _is_selected: bool = false

# The deck's contents, derived from its card data (BuildSummary.deck_manifest_lines) -- with the
# core deck dissolved, WHICH stats a deck carries is the pick's load-bearing information.
var _manifest_label: RichTextLabel
const BuildSummary := preload("res://systems/global/build_summary.gd")

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

func set_deck_data(data: Deck, unlocked: bool):
	self.deck_data = data
	self.is_unlocked = unlocked

func update_display():
	if not is_instance_valid(name_label):
		return

	# Locked decks stay READABLE (name, contents, and how to get them) -- a silhouette with its
	# unlock condition teaches the roster; a blank "LOCKED" tile teaches nothing.
	if is_unlocked:
		name_label.text = deck_data.deck_name
	else:
		name_label.text = "%s  (LOCKED -- %d souls)" % [deck_data.deck_name, deck_data.unlock_cost]
	description_label.text = deck_data.deck_description
	icon_rect.texture = deck_data.deck_icon
	self.modulate = Color.WHITE if is_unlocked else Color.DARK_GRAY
	select_button.disabled = not is_unlocked

	if not _manifest_label:
		_manifest_label = RichTextLabel.new()
		_manifest_label.bbcode_enabled = true
		_manifest_label.fit_content = true
		_manifest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Clicks must fall through to the full-tile SelectButton underneath.
		_manifest_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for font_key in ["normal_font_size", "bold_font_size", "italics_font_size"]:
			_manifest_label.add_theme_font_size_override(font_key, 12)
		$MarginContainer/VBoxContainer.add_child(_manifest_label)
	_manifest_label.text = "\n".join(BuildSummary.deck_manifest_lines(deck_data))

	_update_selection_visual()

## Public property to get the selection state.
func is_selected() -> bool:
	return _is_selected

## Public method to set the selection state from the parent.
func set_selected(value: bool):
	_is_selected = value
	_update_selection_visual()

func _update_selection_visual():
	if not is_instance_valid(selection_border):
		return
	selection_border.visible = _is_selected

## Internal signal handler - toggles selection on click.
func _on_button_pressed():
	if is_unlocked:
		_is_selected = not _is_selected
		_update_selection_visual()
		selection_toggled.emit(self)
