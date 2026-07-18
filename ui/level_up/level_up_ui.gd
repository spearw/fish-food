## level_up_ui.gd
## Manages the user interface for the level-up screen.
extends CanvasLayer

# An array to hold the upgrade choices currently being displayed.
var current_upgrades: Array[Dictionary]
# True while the current screen is a cross-deck combo choice (vs a normal level-up).
var _choosing_combo: bool = false
# True when reroll/banish apply to this screen: normal level-up drafts only. The combo choice and
# the starting-weapon roll are one-shot offers, not drafts -- no manipulation there.
var _manipulation_allowed: bool = false
# True while showing the 20-minute victory screen (Go Infinite / Main Menu).
var _win_screen: bool = false

# Card-manipulation bar (built in code -- see _build_manipulation_bar).
var _manip_bar: HBoxContainer
var _banish_buttons: Array[Button] = []
var _reroll_button: Button
# Owned-pair merge row (rebuilt each refresh -- pairs change as the loadout does).
var _merge_bar: HBoxContainer
# Build summary block above the cards: slots, loadout with tiers, key stats, draft progress. The
# draft decision needs this context -- without it the player can't tell what their build is doing.
var _summary: RichTextLabel
# Summary tabs: [Build] plus one per owned weapon -- per-weapon damage/crit are otherwise invisible
# behind the global multipliers. -1 = the build overview; >= 0 indexes into the equipment children.
var _summary_tabs: HBoxContainer
var _summary_tab: int = -1
const BuildSummary := preload("res://systems/global/build_summary.gd")

# signal to announce when choice has been made
signal upgrade_chosen

@onready var stats_panel: CanvasLayer = get_tree().get_root().get_node("World/StatsPanel") # Update path


# Reference to player.
var player_node: Node2D

# References to UI elements for easier access.
@onready var upgrade_manager: Node = get_tree().get_root().get_node("World/UpgradeManager")
@onready var upgrade_buttons: Array[Button] = [
	$BackgroundColor/MarginContainer/VBoxContainer/UpgradeButton1,
	$BackgroundColor/MarginContainer/VBoxContainer/UpgradeButton2,
	$BackgroundColor/MarginContainer/VBoxContainer/UpgradeButton3
]

func _ready() -> void:
	self.hide()

	# Connect all button presses to a single handler.
	for i in range(upgrade_buttons.size()):
		# .bind(i) passes the index 'i' as an argument to the function.
		upgrade_buttons[i].pressed.connect(_on_upgrade_button_pressed.bind(i))
	Events.boss_reward_requested.connect(on_boss_reward_requested)
	Events.boss_killed.connect(_on_boss_killed)
	_build_manipulation_bar()
	# Upgrade 0: the starting-weapon roll. Deferred so the whole world (player registration included)
	# has finished assembling first.
	call_deferred("_offer_starting_weapon")

## Builds the reroll/banish row under the choice buttons, in code -- the scene keeps its simple
## 3-button structure and the bar can grow without scene surgery.
func _build_manipulation_bar() -> void:
	var vbox := upgrade_buttons[0].get_parent()
	_summary_tabs = HBoxContainer.new()
	_summary_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_summary_tabs)
	vbox.move_child(_summary_tabs, 0)
	_summary = RichTextLabel.new()
	_summary.bbcode_enabled = true
	_summary.fit_content = true
	_summary.custom_minimum_size = Vector2(0, 0)
	vbox.add_child(_summary)
	vbox.move_child(_summary, 1)  # tabs, then summary, then the cards
	_merge_bar = HBoxContainer.new()
	_merge_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_merge_bar.add_theme_constant_override("separation", 16)
	vbox.add_child(_merge_bar)
	_manip_bar = HBoxContainer.new()
	_manip_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_manip_bar.add_theme_constant_override("separation", 16)
	for i in range(upgrade_buttons.size()):
		var b := Button.new()
		b.pressed.connect(_on_banish_pressed.bind(i))
		_manip_bar.add_child(b)
		_banish_buttons.append(b)
	_reroll_button = Button.new()
	_reroll_button.pressed.connect(_on_reroll_pressed)
	_manip_bar.add_child(_reroll_button)
	vbox.add_child(_manip_bar)

func _refresh_manipulation_bar() -> void:
	if not _manip_bar:
		return
	_manip_bar.visible = _manipulation_allowed
	if not _manipulation_allowed:
		return
	_reroll_button.text = "Reroll (%d)" % CurrentRun.rerolls_remaining
	_reroll_button.disabled = CurrentRun.rerolls_remaining <= 0
	for i in range(_banish_buttons.size()):
		_banish_buttons[i].visible = i < current_upgrades.size()
		_banish_buttons[i].text = "Banish #%d (%d)" % [i + 1, CurrentRun.banishes_remaining]
		_banish_buttons[i].disabled = CurrentRun.banishes_remaining <= 0

## Rebuilds the owned-pair merge row: one button per same-type same-tier pair. Same surface as
## reroll/banish (normal drafts only), so build management happens in one place.
func _refresh_merge_bar() -> void:
	if not _merge_bar:
		return
	for c in _merge_bar.get_children():
		c.queue_free()
	if not _manipulation_allowed:
		_merge_bar.visible = false
		return
	var pairs: Array[Dictionary] = upgrade_manager.get_mergeable_pairs()
	_merge_bar.visible = not pairs.is_empty()
	for pair in pairs:
		var b := Button.new()
		b.text = "Merge 2x %s %s > %s (frees a slot)" % [
			Upgrade.Rarity.keys()[pair["rarity"]].capitalize(),
			pair["weapon_type"],
			Upgrade.Rarity.keys()[pair["rarity"] + 1].capitalize()]
		b.pressed.connect(_on_merge_pair_pressed.bind(pair["weapon_type"], pair["rarity"]))
		_merge_bar.add_child(b)

## Consolidates a pair, then REDRAWS the choices: the freed slot changes what is legal to offer
## (weapons and artifacts hidden at a full loadout come back), so keeping the stale draw would
## undersell the merge. Not a free reroll -- it costs a pair, and two copies out-damage the merge.
func _on_merge_pair_pressed(weapon_type: String, rarity: int) -> void:
	if not upgrade_manager.merge_owned_pair(weapon_type, rarity):
		return
	var fresh: Array[Dictionary] = upgrade_manager.get_upgrade_choices(3)
	if not fresh.is_empty():
		current_upgrades = fresh
	_present()

## Redraws all current choices for a charge. Refunds if the pool comes back empty -- an empty paused
## screen would be a softlock, and a refunded charge beats one.
func _on_reroll_pressed() -> void:
	if not upgrade_manager.try_spend_reroll():
		return
	var fresh: Array[Dictionary] = upgrade_manager.get_upgrade_choices(3)
	if fresh.is_empty():
		CurrentRun.rerolls_remaining += 1
		return
	current_upgrades = fresh
	_present()

## Banishes the card in slot i from this run's pool and refills the slot (or drops it when the pool
## is too thin to offer anything new).
func _on_banish_pressed(i: int) -> void:
	if i >= current_upgrades.size():
		return
	if not upgrade_manager.try_banish(current_upgrades[i]["upgrade"]):
		return
	var exclude: Array = current_upgrades.map(func(c): return c["upgrade"])
	var replacement: Dictionary = upgrade_manager.redraw_choice(exclude)
	if replacement.is_empty():
		current_upgrades.remove_at(i)
	else:
		current_upgrades[i] = replacement
	# Banished the last card with nothing left to draw: close out as a skip rather than softlock.
	if current_upgrades.is_empty():
		upgrade_chosen.emit()
		self.hide()
		get_tree().paused = false
		return
	_present()

## Upgrade 0 (design doc section 3): one weapon candidate rolled from EACH chosen deck; pick one.
## The first decision of the run is a fork between your themes, and the pick is the damage floor --
## a run can never start weaponless. Skips silently when no themed decks are selected (benches, test
## setups), which also keeps every headless probe working.
func _offer_starting_weapon() -> void:
	if CurrentRun.starting_weapon_chosen:
		return
	var candidates: Array[Dictionary] = upgrade_manager.get_starting_weapon_candidates()
	if candidates.is_empty():
		return
	CurrentRun.starting_weapon_chosen = true
	current_upgrades = candidates
	_choosing_combo = false
	_manipulation_allowed = false
	_present()
	
## Called by the global 'boss_reward_requested' signal.
func on_boss_reward_requested():
	Logs.add_message(["UI received boss reward request. Granting free level-ups."])
	# For now, we'll just show the level up screen 3 times in a row.
	# A better system might have a dedicated multi-choice UI.
	# We need to use a loop that waits for the player to choose before showing the next.
	_show_reward_sequence(3)

func _on_show_stats_button_pressed():
	if stats_panel:
		stats_panel.toggle_visibility()

## Asynchronously shows the level-up screen multiple times.
func _show_reward_sequence(count: int):
	for i in range(count):
		# Manually trigger the level-up display logic.
		show_upgrade_screen()

		# Wait for signal that reward was chosen
		await self.upgrade_chosen
		await get_tree().process_frame
	
## Herald down: the combo choice fires on the spot when the draft gate is met. When it isn't yet,
## nothing happens here -- the level-up checks below keep asking should_offer_combo, so the offer
## lands at the first level-up where the gate is met (deferral without extra state).
func _on_boss_killed(_stats) -> void:
	if visible:
		return  # a choice screen is already up; the next level-up carries the offer
	if ComboManager.should_offer_combo(0):
		show_combo_screen()

## Called when the player levels up. Fetches and displays upgrade choices.
func on_player_leveled_up(new_level: int):
	Logs.add_message(["Player leveled up. New level:", new_level])
	# At the unlock event, if a cross-deck combo is available, offer it instead of a normal upgrade.
	if ComboManager.should_offer_combo(new_level):
		show_combo_screen()
	else:
		show_upgrade_screen()

func show_upgrade_screen():
	current_upgrades = upgrade_manager.get_upgrade_choices(3)
	_choosing_combo = false
	_manipulation_allowed = true
	_present()

## Shows the cross-deck combo choice: the currently-eligible synergies. Pick ONE (one combo per run).
func show_combo_screen():
	current_upgrades = []
	for syn in ComboManager.get_eligible_synergies():
		# Granted, not drafted -- a combo doesn't spend a loadout slot. It was already paid for by the
		# two-deck investment gate, and by the time it's offered the loadout is usually full, which
		# would otherwise make the reward impossible to accept.
		current_upgrades.append({"upgrade": syn, "rarity": Upgrade.Rarity.COMMON, "granted": true})
	_choosing_combo = true
	_manipulation_allowed = false
	_present()

## The 20-minute victory screen, riding this screen's modal machinery: pause, the final build as
## the summary, and two choices -- keep going (infinite: the director's exponential takes over) or
## back to the menu. Survival deserved more than a frozen timer and a comment saying "later".
func show_win_screen() -> void:
	_win_screen = true
	_manipulation_allowed = false
	_summary_tab = -1
	current_upgrades = []
	get_tree().paused = true
	self.show()
	_refresh_summary()
	_summary.text = "[center][b]YOU WIN! 20:00 SURVIVED[/b][/center]\n" + _summary.text
	_refresh_manipulation_bar()
	_refresh_merge_bar()
	upgrade_buttons[0].text = "GO INFINITE\nThe depths keep rising -- how long can you last?"
	upgrade_buttons[0].modulate = Color.ORANGE_RED
	upgrade_buttons[0].visible = true
	upgrade_buttons[1].text = "MAIN MENU\nSurface with your victory."
	upgrade_buttons[1].modulate = Color.WHITE
	upgrade_buttons[1].visible = true
	upgrade_buttons[2].visible = false

## Pauses, shows the screen, and populates the buttons from current_upgrades.
func _present():
	get_tree().paused = true
	self.show()
	_refresh_summary()
	_refresh_manipulation_bar()
	_refresh_merge_bar()

## The build-at-a-glance block: what you own (with tiers), what it's doing (stats), what you've
## invested where (draft counts feed the combo gate). Refreshed on every present, so merges,
## replacements and picks show their effect immediately.
func _refresh_summary() -> void:
	if not _summary:
		return
	var player = upgrade_manager.player
	if not is_instance_valid(player):
		_summary.text = ""
		return

	# Tabs: [Build] + one per weapon. Rebuilt every present -- the loadout changes under merges.
	for c in _summary_tabs.get_children():
		c.queue_free()
	var weapons: Array = []
	if is_instance_valid(upgrade_manager.player_equipment):
		for w in upgrade_manager.player_equipment.get_children():
			if "rarity" in w:
				weapons.append(w)
	if _summary_tab >= weapons.size():
		_summary_tab = -1
	var build_btn := Button.new()
	build_btn.text = "Build"
	build_btn.disabled = _summary_tab == -1
	build_btn.pressed.connect(func(): _summary_tab = -1; _refresh_summary())
	_summary_tabs.add_child(build_btn)
	for i in range(weapons.size()):
		var b := Button.new()
		b.text = BuildSummary._pretty_name(String(weapons[i].get_meta("weapon_type", weapons[i].name)))
		b.disabled = _summary_tab == i
		b.pressed.connect(func(): _summary_tab = i; _refresh_summary())
		_summary_tabs.add_child(b)

	# Content: the build overview, or one weapon's live numbers.
	if _summary_tab >= 0:
		_summary.text = "[center]%s[/center]" % BuildSummary.weapon_detail_line(weapons[_summary_tab], player)
		return
	var lines: Array = []
	lines.append("[b]%s[/b]   %s" % [
		BuildSummary.slot_line(upgrade_manager), BuildSummary.loadout_line(upgrade_manager)])
	lines.append(BuildSummary.compact_stat_line(player))
	var drafted: String = BuildSummary.draft_line()
	if drafted != "":
		lines.append(drafted)
	var dealt: String = BuildSummary.damage_report_line()
	if dealt != "":
		lines.append(dealt)
	_summary.text = "[center]%s[/center]" % "\n".join(lines)
	for i in range(upgrade_buttons.size()):
		var button = upgrade_buttons[i]
		if i < current_upgrades.size():
			var upgrade_package = current_upgrades[i]
			var upgrade: Upgrade = upgrade_package["upgrade"]
			var rarity_enum: Upgrade.Rarity = upgrade_package["rarity"]
			
			# Every card names its deck (combo-gate progress is a draft-time read) and stat cards
			# show delta AND resulting total via the one formatter that shares apply_upgrade's
			# routing -- the old inline branches printed raw values ("+0.15" for a percent card)
			# and never said where you'd land.
			var deck_tag: String = upgrade_manager.deck_tag(upgrade)
			if upgrade.rarity_values.size() > 0:
				button.text = "%s%s\n%s\n%s" % [upgrade.display_name, deck_tag,
					upgrade.description,
					BuildSummary.stat_card_preview(player_node, upgrade, rarity_enum)]
			elif upgrade.type == Upgrade.UpgradeType.UNLOCK_WEAPON:
				# Name the tier in text (Brotato conveys tier by colour alone and players report not
				# being able to read it), AND what taking the card does -- a merge and an in-place
				# upgrade resolve differently from "new weapon", and the card is where that's learned.
				button.text = "%s (%s)%s%s\n%s" % [
					upgrade.display_name,
					Upgrade.Rarity.keys()[rarity_enum].capitalize(),
					deck_tag,
					upgrade_manager.describe_weapon_take(upgrade, rarity_enum),
					upgrade.description]
			else:
				button.text = "%s%s\n%s" % [upgrade.display_name, deck_tag, upgrade.description]
				
			match rarity_enum:
				Upgrade.Rarity.COMMON:
					button.modulate = Color.WHITE
				Upgrade.Rarity.RARE:
					button.modulate = Color.BLUE
				Upgrade.Rarity.EPIC:
					button.modulate = Color.PURPLE
				Upgrade.Rarity.LEGENDARY:
					button.modulate = Color.YELLOW
				Upgrade.Rarity.MYTHIC:
					button.modulate = Color.ORANGE_RED
			button.visible = true
		else:
			button.visible = false

## Called when any of the upgrade buttons are pressed.
## @param choice_index: int - The index of the button that was pressed.
func _on_upgrade_button_pressed(choice_index: int) -> void:
	# The win screen's two choices resolve here, before any upgrade logic.
	if _win_screen:
		_win_screen = false
		self.hide()
		get_tree().paused = false
		if choice_index == 0:
			var world = get_tree().current_scene
			if world and world.has_method("go_infinite"):
				world.go_infinite()
		else:
			get_tree().change_scene_to_file("res://ui/main_menu/main_menu.tscn")
		return

	var choice = current_upgrades[choice_index]
	Logs.add_message(["Player chose upgrade:", choice.upgrade.id, "Rarity:", Upgrade.Rarity.keys()[choice.rarity]])
	# Apply the selected upgrade.
	upgrade_manager.apply_upgrade(current_upgrades[choice_index])
	# If this was a cross-deck combo choice, lock the run's combo (one per run).
	if _choosing_combo:
		CurrentRun.combo_taken = true
		_choosing_combo = false
	upgrade_chosen.emit()
		
	# Hide the UI and unpause the game.
	self.hide()
	get_tree().paused = false
