## logbook_panel.gd -- the Logbook: everything the game has shown you, browsable between runs.
## BESTIARY: every creature wired into world.tscn. A swarm enemy stays "???" until you have killed
## one. Bosses go by the HP-bar rule: MET (named silhouette) once the bar has shown you the name,
## full entry once beaten -- and the secret keeps even its shape to itself until it is found.
## CARDS: every card in every deck with its full rules text and keyword definitions -- the reading
## room level-up pressure never gives you. Counts come from LogbookData; roster from the master
## bestiary list (verifier-locked to world.tscn's wiring).
extends Control

signal back_pressed

const Chrome := preload("res://systems/global/ui_chrome.gd")
const Glossary := preload("res://systems/global/glossary.gd")
const BuildSummary := preload("res://systems/global/build_summary.gd")

const BOOK_PATH := "res://systems/global/lists/master_bestiary_list.tres"
const PACKS_PATH := "res://systems/global/lists/master_pack_list.tres"

enum { HIDDEN, SEEN, KNOWN }

const GRAY := "#8a919e"
const HEADER_HEX := "#a6ccff"
const GOLD := "#ffd27f"

## Index order matches Upgrade.UpgradeType.
const TYPE_NAMES := ["Weapon", "Artifact", "Upgrade", "Evolution"]

## One line per behavior tag: what the tag means when it is coming at you.
const BEHAVIOR_NOTES := {
	EnemyTags.Behavior.SWARM: "Comes straight at you.",
	EnemyTags.Behavior.RANGED: "Keeps its distance and shoots.",
	EnemyTags.Behavior.ARMORED: "Flat soak per hit. Many small hits feed it; big ones punch through.",
	EnemyTags.Behavior.FAST: "Faster than you are.",
	EnemyTags.Behavior.HORDE: "Gathers with its kind before committing.",
	EnemyTags.Behavior.EVASIVE: "Hard to pin down.",
	EnemyTags.Behavior.REGENERATOR: "Heals constantly. Damage over time races it; direct hits beat it.",
}

## Per-section hints: an undiscovered entry teaches the clock instead of showing stats.
const SECTION_HINTS := {
	"swarm": "Kill one in a run and it takes its place here.",
	"heralds": "One of three surfaces at 8:00. Kill it inside its welcome and your decks cross.",
	"leviathans": "The run's final exam, drawn at the start and named in your build summary. It arrives at 20:00; its death is the win.",
	"secret": "Prove your run before the depths take notice, and a light appears far out in the dark. Three proofs open the way; any one is enough.",
}

var _book: BestiaryList
var _decks: Array = []

var _progress_label: Label
var _tab_buttons := {}
var _scrolls := {}
var _detail_portrait: TextureRect
var _detail: RichTextLabel
var _tab := "bestiary"
var _entries := {"bestiary": [], "cards": []}
var _reading := -1

func _ready() -> void:
	_book = load(BOOK_PATH)
	var pack_list = load(PACKS_PATH)
	for deck in pack_list.decks:
		if deck != null and not deck.id in ["test", "npc"]:
			_decks.append(deck)
	_build_chrome()

## Populates both tabs from the current records and shows the screen.
func open() -> void:
	_populate_bestiary()
	_populate_cards()
	_select_tab(_tab)
	show()

# --- Chrome (built once) ---

func _build_chrome() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1660, 940)
	Chrome.panel_style(panel)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)
	var title := Label.new()
	title.text = "LOGBOOK"
	Chrome.header_style(title, 30)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 15)
	_progress_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	header.add_child(_progress_label)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	vbox.add_child(tabs)
	for tab in [["bestiary", "Bestiary"], ["cards", "Cards"]]:
		var b := Button.new()
		b.text = tab[1]
		b.custom_minimum_size = Vector2(190, 44)
		b.pressed.connect(_select_tab.bind(tab[0]))
		tabs.add_child(b)
		_tab_buttons[tab[0]] = b

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body)

	for tab_key in ["bestiary", "cards"]:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(1030, 0)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.visible = false
		body.add_child(scroll)
		var list := VBoxContainer.new()
		list.name = "List"
		list.add_theme_constant_override("separation", 14)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		_scrolls[tab_key] = scroll

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)

	var portrait_frame := CenterContainer.new()
	right.add_child(portrait_frame)
	_detail_portrait = TextureRect.new()
	_detail_portrait.custom_minimum_size = Vector2(150, 150)
	_detail_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_frame.add_child(_detail_portrait)

	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_theme_font_size_override("normal_font_size", 15)
	_detail.add_theme_font_size_override("bold_font_size", 16)
	right.add_child(_detail)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	vbox.add_child(footer)
	var hint := Label.new()
	hint.text = "Hover any card for its keyword definitions."
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.45, 0.5, 0.58))
	footer.add_child(hint)
	var fspacer := Control.new()
	fspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(fspacer)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(150, 44)
	Chrome.card_style(back, Color(0.35, 0.4, 0.5), 16)
	back.pressed.connect(func():
		hide()
		back_pressed.emit())
	footer.add_child(back)

# --- Population ---

func _populate_bestiary() -> void:
	var list: VBoxContainer = _scrolls["bestiary"].get_node("List")
	for child in list.get_children():
		child.queue_free()
	_entries["bestiary"] = []

	var sections := [
		{"key": "swarm", "title": "THE SWARM", "entries": _book.swarm_entries()},
		{"key": "heralds", "title": "HERALDS",
			"entries": _book.heralds.map(func(s): return {"stats": s, "from_time": -1})},
		{"key": "leviathans", "title": "LEVIATHANS",
			"entries": _book.leviathans.map(func(s): return {"stats": s, "from_time": -1})},
		{"key": "secret", "title": "THE DEEP",
			"entries": [{"stats": _book.secret, "from_time": -1}]},
	]
	for section in sections:
		var found := 0
		var tiles: Array = []
		for entry in section["entries"]:
			var stats: EnemyStats = entry["stats"]
			var state := _bestiary_state(section["key"], stats)
			if state != HIDDEN:
				found += 1
			var index: int = _entries["bestiary"].size()
			var tile := _bestiary_tile(stats, state, section["key"])
			tile.pressed.connect(_set_reading.bind("bestiary", index))
			tiles.append(tile)
			_entries["bestiary"].append({
				"tile": tile, "stats": stats, "state": state,
				"section": section["key"], "from_time": entry["from_time"],
			})
		var header := Label.new()
		header.text = "%s   %d / %d" % [section["title"], found, section["entries"].size()]
		Chrome.header_style(header, 18)
		list.add_child(header)
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		list.add_child(grid)
		for tile in tiles:
			grid.add_child(tile)

func _populate_cards() -> void:
	var list: VBoxContainer = _scrolls["cards"].get_node("List")
	for child in list.get_children():
		child.queue_free()
	_entries["cards"] = []

	for deck in _decks:
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 10)
		list.add_child(header)
		if deck.deck_icon != null:
			var icon := TextureRect.new()
			icon.texture = deck.deck_icon
			icon.custom_minimum_size = Vector2(26, 26)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			header.add_child(icon)
		var name_label := Label.new()
		name_label.text = "%s   %d cards" % [deck.deck_name.to_upper(), deck.upgrades.size()]
		Chrome.header_style(name_label, 18)
		header.add_child(name_label)

		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		list.add_child(grid)
		for upgrade in deck.upgrades:
			if upgrade == null:
				continue
			var index: int = _entries["cards"].size()
			var tile := _card_tile(upgrade)
			tile.pressed.connect(_set_reading.bind("cards", index))
			grid.add_child(tile)
			_entries["cards"].append({"tile": tile, "upgrade": upgrade, "deck": deck})

# --- Tiles ---

func _bestiary_state(section: String, stats: EnemyStats) -> int:
	if stats == null:
		return HIDDEN
	if section == "swarm":
		return KNOWN if LogbookData.enemy_discovered(stats.display_name) else HIDDEN
	if LogbookData.boss_defeats(stats.display_name) > 0:
		return KNOWN
	if LogbookData.boss_seen(stats.display_name):
		return SEEN
	return HIDDEN

func _bestiary_tile(stats: EnemyStats, state: int, section: String) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(156, 168)
	tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	tile.expand_icon = true
	tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.clip_text = true
	Chrome.card_style(tile, Color(0.3, 0.34, 0.42), 13)

	var secret_hidden: bool = section == "secret" and state == HIDDEN
	if not secret_hidden:
		tile.icon = _portrait(stats)
	match state:
		HIDDEN:
			# The unknown-entry treatment: black shape on a lifted slate, or a bare "?" for the
			# secret (even the outline is a spoiler down there).
			tile.text = "?" if secret_hidden else "???"
			if secret_hidden:
				tile.add_theme_font_size_override("font_size", 34)
			for sb_name in ["normal", "hover", "pressed", "focus"]:
				var sb: StyleBoxFlat = tile.get_theme_stylebox(sb_name).duplicate()
				sb.bg_color = Color(0.17, 0.19, 0.24)
				tile.add_theme_stylebox_override(sb_name, sb)
			for icon_state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
				tile.add_theme_color_override(icon_state, Color(0.02, 0.02, 0.05))
			tile.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
			tile.add_theme_color_override("font_hover_color", Color(0.7, 0.75, 0.82))
			tile.tooltip_text = SECTION_HINTS[section]
		SEEN:
			tile.text = "%s\nMet" % stats.display_name
			for icon_state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
				tile.add_theme_color_override(icon_state, Color(0.02, 0.02, 0.05))
			tile.tooltip_text = "Met, not yet beaten."
		KNOWN:
			var count: int = LogbookData.boss_defeats(stats.display_name) if section != "swarm" \
				else LogbookData.kills(stats.display_name)
			tile.text = "%s\nx%s" % [stats.display_name, BuildSummary.fmt_int(count)]
	return tile

func _card_tile(upgrade: Upgrade) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(192, 104)
	tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.clip_text = true
	var taken: int = LogbookData.card_count(upgrade.id)
	tile.text = "%s\n%s%s" % [upgrade.display_name, _card_kind(upgrade),
		"  ·  x%d" % taken if taken > 0 else ""]
	Chrome.card_style(tile, BuildSummary.rarity_color(upgrade.rarity), 13)
	if taken == 0:
		tile.add_theme_color_override("font_color", Color(0.72, 0.75, 0.8))
	tile.tooltip_text = Glossary.tooltip_for(upgrade.description, upgrade.effects)
	return tile

## "Weapon", "Artifact", "Evolution" -- or, for UPGRADE-type cards, the stat/mechanic split the
## deck manifest already draws (shared stat cards follow the "player_" id convention).
func _card_kind(upgrade: Upgrade) -> String:
	if upgrade.type == Upgrade.UpgradeType.UPGRADE:
		return "Stat" if upgrade.id.begins_with("player_") else "Mechanic"
	return TYPE_NAMES[upgrade.type]

# --- Selection / detail ---

func _select_tab(tab: String) -> void:
	_tab = tab
	for key in _scrolls:
		_scrolls[key].visible = key == tab
		Chrome.card_style(_tab_buttons[key],
			Chrome.HEADER_COLOR if key == tab else Color(0.3, 0.34, 0.42), 16)
		if key != tab:
			_tab_buttons[key].add_theme_color_override("font_color", Color(0.6, 0.65, 0.72))
	_update_progress()
	# Default the reading to the first discovered entry, so opening the book lands on something.
	var first := 0
	for i in _entries[tab].size():
		if tab == "cards" or _entries[tab][i]["state"] != HIDDEN:
			first = i
			break
	_set_reading(tab, first)

func _set_reading(tab: String, index: int) -> void:
	if tab != _tab or index >= _entries[tab].size():
		return
	_reading = index
	for i in _entries[tab].size():
		var entry: Dictionary = _entries[tab][i]
		var reading: bool = i == index
		var accent: Color
		if tab == "cards":
			# Rarity KEEPS the border: a header-blue selection border was a dead ringer for Rare.
			# Selection lifts the tile's background instead.
			accent = BuildSummary.rarity_color(entry["upgrade"].rarity)
		else:
			accent = Chrome.HEADER_COLOR if reading else Color(0.3, 0.34, 0.42)
		for sb_name in ["normal", "hover", "pressed", "focus"]:
			var box: StyleBoxFlat = entry["tile"].get_theme_stylebox(sb_name)
			if box is StyleBoxFlat:
				box.border_color = accent
				box.set_border_width_all(3 if reading else 2)
				if tab == "cards" and sb_name == "normal":
					box.bg_color = Color(0.2, 0.23, 0.3) if reading else Chrome.PANEL_BG
	if tab == "cards":
		_show_card_detail(_entries[tab][index])
	else:
		_show_bestiary_detail(_entries[tab][index])

func _update_progress() -> void:
	var found := 0
	for entry in _entries["bestiary"]:
		if entry["state"] != HIDDEN:
			found += 1
	var taken := 0
	for entry in _entries["cards"]:
		if LogbookData.card_count(entry["upgrade"].id) > 0:
			taken += 1
	_progress_label.text = "Bestiary %d / %d   ·   Cards taken %d / %d" % [
		found, _entries["bestiary"].size(), taken, _entries["cards"].size()]

func _show_bestiary_detail(entry: Dictionary) -> void:
	var stats: EnemyStats = entry["stats"]
	var state: int = entry["state"]
	var secret_hidden: bool = entry["section"] == "secret" and state == HIDDEN
	_detail_portrait.texture = null if secret_hidden else _portrait(stats)
	_detail_portrait.modulate = Color(0.02, 0.02, 0.05) if state != KNOWN else Color.WHITE

	if state == HIDDEN:
		_detail.text = "[b][color=%s]???[/color][/b]\n\n[color=%s]%s[/color]" % [
			HEADER_HEX, GRAY, SECTION_HINTS[entry["section"]]]
		return

	var lines: Array = []
	lines.append("[b][color=%s]%s[/color][/b]" % [HEADER_HEX, stats.display_name])
	lines.append("[color=%s]%s[/color]" % [GRAY, _role_line(entry)])
	lines.append("")
	lines.append("HP %s   ·   Damage %d   ·   Speed %d" % [
		BuildSummary.fmt_int(stats.max_health), stats.damage, int(stats.move_speed)])
	if stats.armor > 0:
		lines.append("Armor %d — %s" % [stats.armor, Glossary.KEYWORDS["Armor"]])
	if stats.regen_per_sec > 0.0:
		lines.append("Regeneration %s/s — %s" % [
			_trim_float(stats.regen_per_sec), Glossary.KEYWORDS["Regeneration"]])
	lines.append("Threat rating %s" % _trim_float(stats.challenge_rating))
	var tags := _tag_row(stats)
	if tags != "":
		lines.append("")
		lines.append(tags)
	for behavior in stats.behavior_tags:
		if BEHAVIOR_NOTES.has(behavior):
			lines.append("[color=%s]%s[/color]" % [GRAY, BEHAVIOR_NOTES[behavior]])
	if not stats.size_tags.is_empty() and entry["section"] == "swarm":
		lines.append("[color=%s]Comes in sizes: %s[/color]" % [GRAY, _sizes_line(stats)])
	lines.append("")
	if entry["section"] == "swarm":
		lines.append("[color=%s]x%s killed[/color]" % [GOLD, BuildSummary.fmt_int(LogbookData.kills(stats.display_name))])
	elif state == SEEN:
		lines.append("[color=%s]Met, not yet beaten.[/color]" % GOLD)
	else:
		lines.append("[color=%s]Beaten x%d[/color]" % [GOLD, LogbookData.boss_defeats(stats.display_name)])
	_detail.text = "\n".join(lines)

## The one-line role: where and when this creature enters a run.
func _role_line(entry: Dictionary) -> String:
	match entry["section"]:
		"swarm":
			var t: int = entry["from_time"]
			return "In the water from the start" if t <= 0 else "Joins the water at %d:%02d" % [t / 60, t % 60]
		"heralds":
			return "Herald — one of three surfaces at 8:00. Its death opens the cross-deck combo."
		"leviathans":
			return "Leviathan — the run's drawn exam. Arrives at 20:00; its death is the win."
		_:
			return "Found only by its own false light."

func _tag_row(stats: EnemyStats) -> String:
	var labels: Array = []
	for tag in stats.biome_tags:
		labels.append(EnemyTags.Biome.keys()[tag].capitalize())
	for tag in stats.type_tags:
		labels.append(EnemyTags.Type.keys()[tag].capitalize())
	for tag in stats.behavior_tags:
		labels.append(EnemyTags.Behavior.keys()[tag].capitalize())
	if labels.is_empty():
		return ""
	return "[" + "] [".join(labels) + "]"

func _sizes_line(stats: EnemyStats) -> String:
	var names: Array = []
	for size in stats.size_tags:
		names.append(EnemyTags.Size.keys()[size].capitalize())
	return ", ".join(names)

func _show_card_detail(entry: Dictionary) -> void:
	var upgrade: Upgrade = entry["upgrade"]
	var deck: Deck = entry["deck"]
	_detail_portrait.texture = deck.deck_icon
	_detail_portrait.modulate = Color.WHITE

	var rarity_hex: String = BuildSummary.rarity_color(upgrade.rarity).to_html(false)
	var lines: Array = []
	lines.append("[b][color=#%s]%s[/color][/b]" % [rarity_hex, upgrade.display_name])
	lines.append("[color=%s]%s deck  ·  %s  ·  %s[/color]" % [
		GRAY, deck.deck_name, _card_kind(upgrade),
		Upgrade.Rarity.keys()[upgrade.rarity].capitalize()])
	var row := Glossary.keyword_row(upgrade.effects)
	if row != "":
		lines.append("[color=%s]%s[/color]" % [GRAY, row])
	lines.append("")
	# tooltip_for = description, blank line, then one definition per keyword touched. Bold the
	# keyword names so the definitions read as a glossary block.
	for line in Glossary.tooltip_for(upgrade.description, upgrade.effects).split("\n"):
		var sep := line.find(": ")
		if sep > 0 and sep < 20:
			lines.append("[b]%s[/b]%s" % [line.substr(0, sep + 1), line.substr(sep + 1)])
		else:
			lines.append(line)
	lines.append("")
	var taken: int = LogbookData.card_count(upgrade.id)
	if taken > 0:
		lines.append("[color=%s]Taken x%s across your runs[/color]" % [GOLD, BuildSummary.fmt_int(taken)])
	else:
		lines.append("[color=%s]Never taken[/color]" % GRAY)
	_detail.text = "\n".join(lines)

# --- Shared helpers ---

## First frame of the stats' SpriteFrames, for portraits. Static so the verifier can lean on it.
static func _portrait(stats: EnemyStats) -> Texture2D:
	if stats == null or stats.sprite_frames == null:
		return null
	var frames: SpriteFrames = stats.sprite_frames
	var names := frames.get_animation_names()
	if names.is_empty():
		return null
	var anim: String = "default" if frames.has_animation("default") else names[0]
	if frames.get_frame_count(anim) == 0:
		return null
	return frames.get_frame_texture(anim, 0)

static func _trim_float(value: float) -> String:
	var s := "%.1f" % value
	return s.trim_suffix(".0")
