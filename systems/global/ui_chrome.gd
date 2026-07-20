## ui_chrome.gd -- the one look every UI surface shares: dark panels, accent borders, white text.
## Accents (rarity, selection, gold) live in borders and name colors, NEVER as filters over text
## (whole-control modulate turned Rare cards dark-blue-on-black once; see BuildSummary).
## Preload pattern: const Chrome := preload("res://systems/global/ui_chrome.gd")
extends RefCounted

const PANEL_BG := Color(0.09, 0.1, 0.13, 0.97)
const PANEL_BORDER := Color(0.5, 0.65, 0.85, 0.9)
const HEADER_COLOR := Color(0.65, 0.8, 1.0)

## Card/button chrome: dark panel, accent border, white readable text.
static func card_style(button: Button, accent: Color, font_size: int = 15) -> void:
	button.modulate = Color.WHITE
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	var sb_hover: StyleBoxFlat = sb.duplicate()
	sb_hover.bg_color = Color(0.15, 0.17, 0.22, 0.98)
	sb_hover.set_border_width_all(3)
	button.add_theme_stylebox_override("normal", sb)
	button.add_theme_stylebox_override("hover", sb_hover)
	button.add_theme_stylebox_override("pressed", sb_hover)
	button.add_theme_stylebox_override("focus", sb_hover)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", font_size)

## Panel chrome for PanelContainers (the pause sheet, pickers, select screens).
static func panel_style(panel: Control, border: Color = PANEL_BORDER) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)

## Section-header treatment.
static func header_style(label: Label, size: int = 20) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", HEADER_COLOR)
