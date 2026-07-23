## main_menu.gd
extends Control

@onready var meta_shop_panel: PanelContainer = $MetaShopPanel
@onready var main_menu_buttons: VBoxContainer = $MainMenuButtons
@onready var character_select_panel: Control = $CharacterSelectPanel
@onready var logbook_panel: Control = $LogbookPanel

const Chrome := preload("res://systems/global/ui_chrome.gd")

func _ready():
	# Make sure the shop is hidden initially
	meta_shop_panel.hide()
	# Connect the back signal from the meta shop panel
	meta_shop_panel.back_pressed.connect(_on_back_button_pressed)
	logbook_panel.back_pressed.connect(func(): main_menu_buttons.show())
	# The shared chrome: title up, buttons as real cards.
	var title = main_menu_buttons.get_node_or_null("TitleLabel")
	if title:
		title.add_theme_font_size_override("font_size", 52)
	for button_name in ["StartRunButton", "MetaShopButton", "LogbookButton", "QuitButton"]:
		var b = main_menu_buttons.get_node_or_null(button_name)
		if b:
			b.custom_minimum_size = Vector2(280, 0)
			Chrome.card_style(b, Chrome.PANEL_BORDER, 18)

# --- Signal Handlers for Buttons ---
func _on_meta_shop_button_pressed():
	meta_shop_panel.refresh_all()
	meta_shop_panel.show()
	main_menu_buttons.hide()

func _on_back_button_pressed():
	meta_shop_panel.hide()
	main_menu_buttons.show()

func _on_start_run_button_pressed():
	character_select_panel.show()
	main_menu_buttons.hide()

func _on_logbook_button_pressed():
	logbook_panel.open()
	main_menu_buttons.hide()

func _on_quit_button_pressed():
	GameData.save_data()
	get_tree().quit()
