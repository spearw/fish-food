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
## Granted by the character (it's their primary deck), so it's always in the run and can't be toggled.
var is_granted: bool = false
var _is_selected: bool = false

func _ready():
	update_display()
	select_button.pressed.connect(_on_button_pressed)

func set_deck_data(data: Deck, unlocked: bool):
	self.deck_data = data
	self.is_unlocked = unlocked

## Marks this deck as the character's primary: shown locked ON rather than offered as a choice.
func set_granted(value: bool) -> void:
	is_granted = value
	if value:
		_is_selected = true
	# Safe before the button enters the tree -- update_display() no-ops until its nodes exist, and
	# _ready() calls it again.
	update_display()

func update_display():
	if not is_instance_valid(name_label):
		return

	if not is_unlocked:
		name_label.text = "LOCKED"
		description_label.text = ""
	else:
		name_label.text = "%s (Primary)" % deck_data.deck_name if is_granted else deck_data.deck_name
		description_label.text = deck_data.deck_description

	if is_unlocked:
		icon_rect.texture = deck_data.deck_icon
		# Tint the granted deck so it reads as the character's, not as something you picked.
		self.modulate = Color(0.75, 0.9, 1.0) if is_granted else Color.WHITE
		select_button.disabled = is_granted
	else:
		icon_rect.texture = null
		self.modulate = Color.DARK_GRAY
		select_button.disabled = true

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
