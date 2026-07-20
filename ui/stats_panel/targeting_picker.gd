## targeting_picker.gd
## A pop-up that lets the player choose a targeting mode for a weapon: a centered titled panel,
## one row per mode, the weapon's CURRENT mode marked. (It used to be a bare button stack stranded
## in the screen corner with no context.)
extends PanelContainer

signal targeting_mode_selected(new_mode_enum)

const Chrome := preload("res://systems/global/ui_chrome.gd")
const BuildSummary := preload("res://systems/global/build_summary.gd")

@onready var button_container: VBoxContainer = $MarginContainer/VBoxContainer

var weapon_node: Node
var _title: Label

func _ready() -> void:
	Chrome.panel_style(self)

## Opens the picker and populates it with choices for a specific weapon.
func open_for_weapon(target_weapon: Node):
	self.weapon_node = target_weapon
	if not is_instance_valid(weapon_node):
		close()
		return

	_populate_buttons()
	self.show()

func _populate_buttons():
	for child in button_container.get_children(): child.queue_free()

	_title = Label.new()
	_title.text = "Targeting: %s" % BuildSummary._pretty_name(
		String(weapon_node.get_meta("weapon_type", weapon_node.name)))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Chrome.header_style(_title, 18)
	button_container.add_child(_title)

	var targeting_comp = weapon_node.get_node_or_null("TargetingComponent")
	var current_mode: int = targeting_comp.targeting_mode if targeting_comp else -1

	for mode_name in TargetingComponent.TargetingMode.keys():
		var button = Button.new()
		var mode_enum = TargetingComponent.TargetingMode[mode_name]
		button.text = mode_name.capitalize()
		if mode_enum == current_mode:
			button.text += "  (current)"
			Chrome.card_style(button, Chrome.HEADER_COLOR, 14)
		else:
			Chrome.card_style(button, Color(0.35, 0.4, 0.5), 14)
		button.pressed.connect(_on_mode_button_pressed.bind(mode_enum))
		button_container.add_child(button)

func _on_mode_button_pressed(new_mode_enum: TargetingComponent.TargetingMode):
	var targeting_comp = weapon_node.get_node_or_null("TargetingComponent")
	if targeting_comp:
		targeting_comp.targeting_mode = new_mode_enum
		Logs.add_message(["Set %s targeting to %s" % [weapon_node.name, TargetingComponent.TargetingMode.keys()[new_mode_enum]]])
	
	close()

func close():
	self.hide()
