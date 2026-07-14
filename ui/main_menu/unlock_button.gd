## unlock_button.gd
## A button in the meta shop for unlocking content like characters or packs.
extends PanelContainer

signal unlock_purchased(resource_path: String)

var unlock_data: Resource
var unlock_cost: int = 100

@onready var icon_rect: TextureRect = $MarginContainer/VBoxContainer/TextureRect
@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var cost_label: Label = $MarginContainer/VBoxContainer/CostLabel
@onready var purchase_button: Button = $MarginContainer/VBoxContainer/PurchaseButton

func _ready():
	purchase_button.pressed.connect(_on_purchase_button_pressed)

func set_unlock_data(data: Resource):
	self.unlock_data = data

	if data is PlayerStats:
		name_label.text = data.character_name
		# Try to get the first frame of the idle animation as icon
		if data.character_sprite_frames and data.character_sprite_frames.has_animation("idle"):
			icon_rect.texture = data.character_sprite_frames.get_frame_texture("idle", 0)
		unlock_cost = data.unlock_cost
	elif data is Deck:
		name_label.text = data.deck_name
		icon_rect.texture = data.deck_icon
		unlock_cost = data.unlock_cost

	cost_label.text = "Cost: %d Souls" % unlock_cost
	update_button_state()

func update_button_state():
	var can_afford = GameData.data["total_souls"] >= unlock_cost
	purchase_button.disabled = not can_afford
	if can_afford:
		purchase_button.text = "Unlock"
	else:
		purchase_button.text = "Not enough souls"

func _on_purchase_button_pressed():
	if GameData.data["total_souls"] >= unlock_cost:
		GameData.data["total_souls"] -= unlock_cost
		GameData.save_data()
		unlock_purchased.emit(unlock_data.resource_path)
