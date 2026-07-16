## upgrade_manager.gd
## Manages the pool of available upgrades, filters them based on player inventory,
## and applies selected upgrades.
extends Node

## Node metadata marking an item the player was GIVEN rather than drafted. Granted items don't spend a
## loadout slot: they're rewards already paid for elsewhere (a combo costs a deep two-deck investment),
## and they arrive late, when the loadout is usually full -- a level-20 reward you can't accept because
## your slots are full would be a feel-bomb.
const GRANTED_META := "granted_not_slotted"

const BuildSummary := preload("res://systems/global/build_summary.gd")

var active_upgrade_pool: Array[Upgrade] = []

# Pre-computed rarity buckets for O(1) rarity lookup
var _upgrade_buckets: Dictionary = {}  # rarity_enum -> Array of upgrades
var _unlock_buckets: Dictionary = {}  # rarity_enum -> Array of UNLOCK upgrades (exact rarity match)
# Maps each Upgrade resource -> the Deck.id it came from, so applying a card can credit its deck's
# draft count (which feeds cross-deck combo power gates).
var _upgrade_deck_ids: Dictionary = {}

var player_equipment: Node2D = null
var player_artifacts: Node2D = null
var player: Node2D = null

const RARITY_WEIGHTS = {
	Upgrade.Rarity.COMMON: 85,
	Upgrade.Rarity.RARE: 40,
	Upgrade.Rarity.EPIC: 25,
	Upgrade.Rarity.LEGENDARY: 15,
	Upgrade.Rarity.MYTHIC: 5
}

func _ready():
	# Build pool from chosen upgrade packs.
	_build_active_upgrade_pool()
	
func _build_active_upgrade_pool():
	# Clear any old data.
	active_upgrade_pool.clear()
	_upgrade_buckets.clear()
	_unlock_buckets.clear()
	_upgrade_deck_ids.clear()

	# Initialize buckets for each rarity
	for rarity_enum in Upgrade.Rarity.values():
		_upgrade_buckets[rarity_enum] = []
		_unlock_buckets[rarity_enum] = []

	# The run's decks: core + the character's linked primary + the player's picks, capped at the
	# two-themed-deck rule. CurrentRun owns that composition.
	var deck_names = []
	for pack_path in CurrentRun.get_active_deck_paths():
		var pack_resource: Deck = load(pack_path)
		if pack_resource:
			# Add all upgrades from this pack into our active pool for this run.
			active_upgrade_pool.append_array(pack_resource.upgrades)
			deck_names.append(pack_resource.deck_name)

			# Credit each card to its deck (for combo gates) and pre-compute rarity buckets.
			for upgrade in pack_resource.upgrades:
				_upgrade_deck_ids[upgrade] = pack_resource.id
				_bucket_upgrade(upgrade)
		else:
			printerr("Failed to load Deck at path: ", pack_path)

	_add_character_exclusives()

	Logs.add_message("UpgradeManager pool built for this run.")
	Logs.add_message(["Packs added:", deck_names])
	Logs.add_message(["Total upgrades available: ", active_upgrade_pool.size()])

## Files an upgrade into the rarity bucket(s) it can be drawn from, so choice-time lookup is O(1).
## Shared by every source of cards (decks, character exclusives) -- a new source only has to call it.
func _bucket_upgrade(upgrade: Upgrade) -> void:
	match upgrade.type:
		Upgrade.UpgradeType.UNLOCK_WEAPON:
			# A weapon can turn up at ANY rarity -- the rolled tier becomes that instance's rarity. So
			# luck is the "find a better one in the wild" lever, and merging is a path to a higher tier
			# rather than the only one. (Brotato likewise sells high tiers directly, gated on wave+Luck.)
			for rarity_idx in Upgrade.Rarity.values():
				_unlock_buckets[rarity_idx].append(upgrade)
		Upgrade.UpgradeType.UNLOCK_ARTIFACT, Upgrade.UpgradeType.TRANSFORMATION:
			# Artifacts and evolutions are rules rather than numbers -- they don't tier, so they're
			# drawn at exactly their own rarity.
			_unlock_buckets[upgrade.rarity].append(upgrade)
		Upgrade.UpgradeType.UPGRADE:
			# Stat upgrades scale with rarity, so they can appear in every tier they define a value for.
			for rarity_idx in range(upgrade.rarity_values.size()):
				_upgrade_buckets[rarity_idx].append(upgrade)

## Folds the character's exclusive cards into the pool. Credited to no deck -- characters aren't
## linked to decks anymore, so an exclusive card is identity investment, not theme investment.
func _add_character_exclusives() -> void:
	var character: PlayerStats = CurrentRun.selected_character
	if not character or character.exclusive_upgrades.is_empty():
		return

	for upgrade in character.exclusive_upgrades:
		if upgrade == null:
			continue
		active_upgrade_pool.append(upgrade)
		_upgrade_deck_ids[upgrade] = ""
		_bucket_upgrade(upgrade)

	Logs.add_message(["Character exclusives added:", character.exclusive_upgrades.size()])

## Upgrade 0: one starting-weapon candidate rolled from EACH themed deck this run holds. The player
## picks one -- the first decision is a fork between their chosen themes, and the pick doubles as the
## damage floor the shared slot pool relies on (a run can never have zero weapons).
func get_starting_weapon_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for path in CurrentRun.get_active_deck_paths():
		if path == CurrentRun.CORE_DECK_PATH:
			continue
		var deck: Deck = load(path)
		if not deck:
			continue
		var weapons: Array = deck.upgrades.filter(
			func(u): return u != null and u.type == Upgrade.UpgradeType.UNLOCK_WEAPON)
		if not weapons.is_empty():
			candidates.append({"upgrade": weapons.pick_random(), "rarity": Upgrade.Rarity.COMMON})
	return candidates

## Store reference to the player's equipment and artifacts.
## @param player: Node - The player node instance that is registering itself.
func register_player(player: Node) -> void:
	# Check if the player and its children are valid before storing them.
	if is_instance_valid(player) and player.has_node("Equipment") and player.has_node("Artifacts"):
		self.player = player
		self.player_equipment = player.get_node("Equipment")
		self.player_artifacts = player.get_node("Artifacts")
		Logs.add_message("UpgradeManager: Player registered successfully.")
	else:
		printerr("UpgradeManager: Failed to register player or find required child nodes (Equipment/Artifacts).")
		
# --- Weapon duplicates: copies, merges, in-place upgrades (design doc section 3) ---

## The player's live copies of a weapon type. Matches the weapon_type meta (set at creation), with
## the node name as fallback; anything without an instance rarity (mocks, non-weapons) is skipped.
func _owned_copies(weapon_type: String) -> Array:
	var copies: Array = []
	if not is_instance_valid(player_equipment):
		return copies
	for w in player_equipment.get_children():
		if String(w.get_meta("weapon_type", w.name)) == weapon_type and "rarity" in w:
			copies.append(w)
	return copies

## Any-tier gate: a weapon card stays in the pool while SOME tier of it could be taken. With a free
## slot every tier is a new copy; otherwise owning any copy below the top tier keeps it alive (that
## copy's own tier merges, and every tier above it replaces).
func _weapon_offerable_any_tier(upgrade: Upgrade) -> bool:
	if has_free_slot():
		return true
	for w in _owned_copies(upgrade.target_class_name):
		if w.rarity < Upgrade.Rarity.size() - 1:
			return true
	return false

## Tier gate: offerable iff SLOTTABLE (free slot -> new copy), MERGEABLE (a same-tier copy -> next
## tier) or UPGRADE-REPLACEABLE (a lower-tier copy -> this tier, in place). Otherwise the card is
## dead at this tier and must not be shown -- a dead option is a third of a 3-card choice.
func _weapon_offerable_at(upgrade: Upgrade, rolled_rarity: int) -> bool:
	if has_free_slot():
		return true
	var top := Upgrade.Rarity.size() - 1
	for w in _owned_copies(upgrade.target_class_name):
		if w.rarity == rolled_rarity and rolled_rarity < top:
			return true
		if w.rarity < rolled_rarity:
			return true
	return false

## The action suffix for a weapon card's button text: "" for a new copy, otherwise it names the merge
## or the in-place upgrade. The card is where the player learns the rule.
func describe_weapon_take(upgrade: Upgrade, rolled_rarity: int) -> String:
	if has_free_slot():
		return ""
	var owned := _owned_copies(upgrade.target_class_name)
	var top := Upgrade.Rarity.size() - 1
	for w in owned:
		if w.rarity == rolled_rarity and rolled_rarity < top:
			# Concrete numbers on the card: "what is the value of this upgrade" must be answerable
			# from the button (playtest finding, Jul 2026).
			return " > merges into %s%s" % [
				Upgrade.Rarity.keys()[rolled_rarity + 1].capitalize(),
				_tier_change_numbers(w, rolled_rarity + 1)]
	var lowest = null
	for w in owned:
		if w.rarity < rolled_rarity and (lowest == null or w.rarity < lowest.rarity):
			lowest = w
	if lowest != null:
		return " > upgrades your %s%s" % [
			Upgrade.Rarity.keys()[lowest.rarity].capitalize(),
			_tier_change_numbers(lowest, rolled_rarity)]
	return ""

## "(18>32 dmg, 2.0>4.5 tick)" -- the owned copy's CURRENT numbers against what set_rarity would
## make them, using the weapon's own per-kind rarity weights: a gas cloud's merge grows its poison
## harder than its slap, and the preview shows exactly that.
func _tier_change_numbers(weapon, new_rarity: int) -> String:
	var curve: Array = weapon.rarity_scaling
	if curve.is_empty() or new_rarity >= curve.size():
		return ""
	var ratio: float = curve[new_rarity] / weapon.get_rarity_multiplier()
	var now: Dictionary = BuildSummary.weapon_numbers(weapon)
	var bits: Array = []
	if now["dmg"] > 0:
		bits.append("%d>%d dmg" % [roundi(now["dmg"]),
			roundi(now["dmg"] * pow(ratio, weapon.direct_rarity_weight))])
	if now["tick"] > 0:
		bits.append("%.1f>%.1f tick" % [now["tick"],
			now["tick"] * pow(ratio, weapon.status_rarity_weight)])
	return (" (%s)" % ", ".join(bits)) if not bits.is_empty() else ""

## Resolves a taken weapon card.
## Free slot (or granted): a NEW COPY at the rolled tier -- never a merge, because two copies in two
## slots out-damage one merged copy (+1/N), so merging with room to spare would always be a mistake.
## Full loadout: MERGE with a same-tier copy (it goes up a tier -- the pick costs no slot), else
## UPGRADE the lowest lower-tier copy in place. Both go through Weapon.set_rarity, so the node -- and
## its transformations -- survives.
func _take_weapon_card(upgrade: Upgrade, rolled_rarity: int, granted: bool) -> void:
	if granted or has_free_slot():
		var new_weapon = create_weapon(upgrade.scene_to_unlock.instantiate(), upgrade, rolled_rarity)
		if granted:
			mark_granted(new_weapon)
		# Copies need distinct node names or add_child mangles them. The FIRST copy keeps the
		# canonical name so upgrade/transformation lookups (get_node by target name) keep working.
		if player_equipment.has_node(NodePath(String(new_weapon.name))):
			var n := 2
			while player_equipment.has_node(NodePath("%s_%d" % [upgrade.target_class_name, n])):
				n += 1
			new_weapon.name = "%s_%d" % [upgrade.target_class_name, n]
		player_equipment.add_child(new_weapon)
		return

	var owned := _owned_copies(upgrade.target_class_name)
	var top := Upgrade.Rarity.size() - 1
	if rolled_rarity < top:
		for w in owned:
			if w.rarity == rolled_rarity:
				w.set_rarity(rolled_rarity + 1)  # merge: strictly pairwise, no cascade
				return
	var lowest = null
	for w in owned:
		if w.rarity < rolled_rarity and (lowest == null or w.rarity < lowest.rarity):
			lowest = w
	if lowest:
		lowest.set_rarity(rolled_rarity)  # replace: the biggest in-place upgrade available
		return
	# The offer filter should have hidden this card. Land it as a copy (soft cap violation) rather
	# than eat the player's pick, and say so.
	printerr("Weapon card '%s' had no legal action at a full loadout -- offer-filter bug?" % upgrade.id)
	player_equipment.add_child(create_weapon(upgrade.scene_to_unlock.instantiate(), upgrade, rolled_rarity))

## Marks an item as granted: earned rather than drafted, so it doesn't spend a loadout slot.
func mark_granted(item: Node) -> void:
	item.set_meta(GRANTED_META, true)

## True if this item was granted rather than drafted.
func is_granted(item: Node) -> bool:
	return item.get_meta(GRANTED_META, false)

## How many loadout slots the player has spent. Weapons and artifacts share one pool (see
## CurrentRun.max_loadout_slots) -- granted items are excluded, they were never a pick.
func get_used_slots() -> int:
	if not is_instance_valid(player_equipment) or not is_instance_valid(player_artifacts):
		return 0
	var used := 0
	for item in player_equipment.get_children() + player_artifacts.get_children():
		if not is_granted(item):
			used += 1
	return used

## Whether the player has room to draft another weapon or artifact.
func has_free_slot() -> bool:
	return get_used_slots() < CurrentRun.max_loadout_slots

## Gathers the names of all items the player currently has.
## @return: Array[String] - An array of items names.
func get_player_inventory_names_and_transformed_item_list() -> Array[Array]:
	var inventory: Array[String] = []
	var transformed_items: Array[String] = []
	for item in player_equipment.get_children():
		inventory.append(item.name)
		if item.is_transformed:
			transformed_items.append(item.name)
	for item in player_artifacts.get_children():
		inventory.append(item.name)
	return [inventory, transformed_items]

## The cards that are legal to offer right now -- the ones the player could actually use.
## Offering a card the player can't use is worse than offering nothing: in a 3-choice draw, a dead
## option is a third of the decision gone.
func get_offerable_upgrades() -> Array[Upgrade]:
	var inventory = get_player_inventory_names_and_transformed_item_list()
	var player_inventory = inventory[0]
	var transformed_item_list = inventory[1]
	# A weapon or artifact needs a slot to live in, so a full loadout stops them being offered at all.
	# That refusal IS the design: it's what makes a pick cost something instead of just deferring it.
	var slot_free := has_free_slot()

	var offerable: Array[Upgrade] = []
	for upgrade in active_upgrade_pool:
		# Banished this run: out of every draw until the next run starts.
		if upgrade in CurrentRun.banished_upgrades:
			continue
		var target_name = upgrade.target_class_name
		match upgrade.type:
			Upgrade.UpgradeType.UNLOCK_WEAPON:
				# Duplicates are LEGAL for weapons (copies, merges, in-place upgrades -- design doc
				# section 3), so "already owned" stopped being a disqualifier. This is the any-tier
				# gate; the exact tier is re-checked at roll time (_weapon_offerable_at).
				if _weapon_offerable_any_tier(upgrade):
					offerable.append(upgrade)
			Upgrade.UpgradeType.UNLOCK_ARTIFACT:
				# Artifacts are rules, not numbers: no tiers, no merging, one copy ever.
				if not target_name in player_inventory and slot_free:
					offerable.append(upgrade)
			Upgrade.UpgradeType.UPGRADE:
				# Upgrades are stats buffs or they modify something in the inventory.
				if target_name == "Player" or target_name in player_inventory:
					offerable.append(upgrade)
			Upgrade.UpgradeType.TRANSFORMATION:
				# Only list tranformations if player has the weapon and it has not been transformed.
				if target_name in player_inventory and target_name not in transformed_item_list:
					offerable.append(upgrade)
	return offerable

## Returns a specified number of valid, random upgrade choices.
func get_upgrade_choices(count: int) -> Array[Dictionary]:
	Logs.add_message("Getting upgrade choices")
	var filtered_pool: Array[Upgrade] = get_offerable_upgrades()

	var final_choices: Array[Dictionary] = []
	for i in range(count):
		if filtered_pool.is_empty(): break

		# --- Weighted Rarity Selection ---
		var chosen_rarity_enum = _get_random_rarity_tier()

		var potential_upgrades: Array = []
		# Loop until pool filled.
		var attempts = 0
		while potential_upgrades.is_empty() and attempts < 10:
			attempts += 1
			# Avoid infinite loop with empty upgrade pool.
			if filtered_pool.is_empty():
				break

			# Use pre-computed buckets for O(1) lookup, then filter by inventory
			var bucket_upgrades = _upgrade_buckets.get(chosen_rarity_enum, [])
			var bucket_unlocks = _unlock_buckets.get(chosen_rarity_enum, [])

			# Filter bucket results against current filtered_pool (inventory check)
			for upg in bucket_upgrades:
				if upg in filtered_pool:
					potential_upgrades.append(upg)
			for upg in bucket_unlocks:
				# Weapon cards are TIER-sensitive: the same card can be live at one rarity (merges
				# with your same-tier copy) and dead at another (lower than everything you own, at a
				# full loadout). Re-check at the rolled tier -- never show a card the player can't use.
				if upg.type == Upgrade.UpgradeType.UNLOCK_WEAPON:
					if upg in filtered_pool and _weapon_offerable_at(upg, chosen_rarity_enum):
						potential_upgrades.append(upg)
				elif upg in filtered_pool:
					potential_upgrades.append(upg)

			# If no more rarities of this tier exist, downgrade 1 and try again
			if potential_upgrades.is_empty():
				if chosen_rarity_enum != 0:
					chosen_rarity_enum -= 1
				else:
					# If common rarity and does not exist, reroll.
					chosen_rarity_enum = _get_random_rarity_tier()

		if potential_upgrades.is_empty():
			break

		var chosen_upgrade = potential_upgrades.pick_random()
		
		Logs.add_message(["Manager chose upgrade:", chosen_upgrade.id, "Rarity:", Upgrade.Rarity.keys()[chosen_rarity_enum]])

		
		# Package the results
		final_choices.append({
			"upgrade": chosen_upgrade,
			"rarity": chosen_rarity_enum
		})
		
		# Remove the choice from the pool for this round to avoid duplicates
		filtered_pool.erase(chosen_upgrade)
		
	return final_choices
	
## Helper function to perform a weighted random roll for a rarity tier.
func _get_random_rarity_tier() -> Upgrade.Rarity:
	var total_weight = 0
	var modified_weights = {}
	var luck = player.get_stat("luck")
	
	for rarity_enum in RARITY_WEIGHTS:
		var weight = RARITY_WEIGHTS[rarity_enum]
		# Modify weights for higher rarities based on player luck.
		if rarity_enum > Upgrade.Rarity.COMMON:
			weight *= luck
		modified_weights[rarity_enum] = weight
		total_weight += weight
		
	var roll = randf() * total_weight
	var cumulative_weight = 0
	for rarity_enum in modified_weights:
		cumulative_weight += modified_weights[rarity_enum]
		if roll < cumulative_weight:
			return rarity_enum
			
	# Fallback
	return Upgrade.Rarity.COMMON

## Owned same-type same-tier pairs that could consolidate (2 owned -> 1 next tier, freeing a slot).
## The slot-freeing half of the merge economy: the drafted-duplicate merge conserves slots, this one
## returns a slot -- the "draft copies -> merge up -> free slots -> draft rules" churn loop.
func get_mergeable_pairs() -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	if not is_instance_valid(player_equipment):
		return pairs
	var by_group: Dictionary = {}
	for w in player_equipment.get_children():
		if not ("rarity" in w):
			continue
		var key := "%s|%d" % [String(w.get_meta("weapon_type", w.name)), w.rarity]
		by_group[key] = by_group.get(key, 0) + 1
	var top := Upgrade.Rarity.size() - 1
	for key in by_group:
		if by_group[key] < 2:
			continue
		var parts: PackedStringArray = key.split("|")
		if int(parts[1]) >= top:
			continue  # nothing above the top tier to merge into
		pairs.append({"weapon_type": parts[0], "rarity": int(parts[1]), "count": by_group[key]})
	return pairs

## Consolidates an owned pair: one copy goes up a tier IN PLACE (transformations survive), the other
## is freed, returning its slot. The trade is deliberate: two copies out-damage the merged one (2x vs
## the ~1.8x tier ratio), so this buys a slot at ~10% damage.
func merge_owned_pair(weapon_type: String, rarity: int) -> bool:
	if rarity >= Upgrade.Rarity.size() - 1:
		return false
	var copies: Array = _owned_copies(weapon_type).filter(func(w): return w.rarity == rarity)
	if copies.size() < 2:
		return false
	# The transformed copy survives -- evolution investment is the state worth keeping.
	copies.sort_custom(func(a, b): return a.is_transformed and not b.is_transformed)
	var survivor = copies[0]
	var freed = copies[1]
	survivor.set_rarity(rarity + 1)
	player_equipment.remove_child(freed)
	freed.queue_free()
	if is_instance_valid(player):
		player.notify_stats_changed()
	return true

# --- Card manipulation (pre-commitment: acts on the OFFER, never on owned slots) ---

## Spends a reroll charge. The UI redraws all choices on true.
func try_spend_reroll() -> bool:
	if CurrentRun.rerolls_remaining <= 0:
		return false
	CurrentRun.rerolls_remaining -= 1
	return true

## Banishes a card from this run's pool permanently and spends a charge. Banishing a weapon card
## removes it at EVERY tier -- the card is one resource, the tiers are rolled at draw time.
func try_banish(upgrade: Upgrade) -> bool:
	if CurrentRun.banishes_remaining <= 0:
		return false
	CurrentRun.banishes_remaining -= 1
	CurrentRun.banished_upgrades.append(upgrade)
	return true

## One replacement choice for a banished slot, avoiding the cards already on screen. Returns {} when
## the pool is too thin to offer anything new -- the UI drops the slot rather than showing a twin.
func redraw_choice(exclude: Array) -> Dictionary:
	for attempt in range(8):
		var draw := get_upgrade_choices(1)
		if draw.is_empty():
			return {}
		if not draw[0]["upgrade"] in exclude:
			return draw[0]
	return {}

## Applies the logic for a given upgrade.
func apply_upgrade(upgrade_package: Dictionary) -> void:
	var upgrade: Upgrade = upgrade_package["upgrade"]
	var chosen_rarity_enum: Upgrade.Rarity = upgrade_package["rarity"]
	# Rewards the player earned rather than drafted (combo synergies, a character's identity artifact)
	# pass "granted": true, which exempts them from the loadout cap.
	var granted: bool = upgrade_package.get("granted", false)
	if not player_equipment or not player_artifacts:
		printerr("UpgradeManager: Cannot apply upgrade, player has not been registered.")
		return

	match upgrade.type:
		Upgrade.UpgradeType.UNLOCK_WEAPON:
			if upgrade.scene_to_unlock:
				# The rolled rarity IS the tier. What taking the card does depends on the loadout:
				# new copy with a free slot, merge or in-place upgrade at a full one.
				_take_weapon_card(upgrade, chosen_rarity_enum, granted)
			else:
				printerr("Unlock upgrade '%s' is missing a scene!" % upgrade.id)

		Upgrade.UpgradeType.UNLOCK_ARTIFACT:
			if upgrade.scene_to_unlock:
				var new_artifact = create_artifact(upgrade.scene_to_unlock.instantiate(), upgrade)
				if "user" in new_artifact:
					new_artifact.user = self.player
				if granted:
					mark_granted(new_artifact)
				player_artifacts.add_child(new_artifact)
				# Call on_equipped after artifact is in the tree and has user set
				if new_artifact.has_method("on_equipped"):
					new_artifact.on_equipped()
			else:
				printerr("Unlock upgrade '%s' is missing a scene!" % upgrade.id)
		Upgrade.UpgradeType.TRANSFORMATION:
			var target_weapon = player_equipment.get_node_or_null(upgrade.target_class_name)
			if target_weapon and target_weapon.has_method("apply_transformation"):
				target_weapon.apply_transformation(upgrade.key)
			else:
				printerr("Failed to apply transformation: could not find weapon '%s'" % upgrade.target_class_name)
		Upgrade.UpgradeType.UPGRADE:
			var target_item: Node = null
			# Get upgrade target
			if upgrade.target_class_name == "Player":
				target_item = self.player
			else:
				target_item = player_equipment.get_node_or_null(upgrade.target_class_name)
				if not target_item:
					target_item = player_artifacts.get_node_or_null(upgrade.target_class_name)
			# Apply upgrade
			if target_item:
				var value_from_rarity = upgrade.rarity_values[chosen_rarity_enum]
				
				match upgrade.modifier_type:
					Upgrade.ModifierType.POWERS:
						# It's a Power Upgrade. Call the player's powers function.
						player.add_power_level(upgrade.key, int(value_from_rarity))
					Upgrade.ModifierType.MULTIPLICATIVE:
						# The "more" layer: each copy multiplies. For percentage cards only --
						# a flat-count card marked multiplicative would turn "+1" into "x2".
						player.add_more_multiplier(upgrade.key, value_from_rarity)
					Upgrade.ModifierType.ADDITIVE:
						# The "increased" layer: copies sum (and diminish relative to the total).
						player.add_bonus(upgrade.key, value_from_rarity)
			else:
				printerr("Upgrade failed: Could not find target '%s'" % upgrade.target_class_name)
			
	# Credit this card to its deck's draft count (combo power gates read this).
	var card_deck_id: String = _upgrade_deck_ids.get(upgrade, "")
	if card_deck_id != "":
		CurrentRun.deck_draft_counts[card_deck_id] = CurrentRun.deck_draft_counts.get(card_deck_id, 0) + 1

	# Notify the player that stats may have changed.
	if is_instance_valid(player):
		player.notify_stats_changed()
			
## Builds a weapon instance at a given rarity tier.
## @param rarity: The tier this instance is. Must be applied before the weapon enters the tree --
##                Weapon._ready() bakes it into the stats it duplicates for itself.
func create_weapon(weapon, upgrade, rarity: int = Upgrade.Rarity.COMMON):
	weapon.name = upgrade.target_class_name
	# Duplicates get unique NODE names (below), so the type lives in metadata. Name stays the
	# fallback for tools/mocks that predate this.
	weapon.set_meta("weapon_type", upgrade.target_class_name)
	if "rarity" in weapon:
		weapon.rarity = rarity
	var stats_comp = weapon.get_node("WeaponStatsComponent")
	stats_comp.user = self.player
	var timer = weapon.get_node_or_null("FireRateTimer")
	if timer:
		# Set its base fire rate.
		timer.set_meta("base_wait_time", weapon.base_fire_rate)
		timer.wait_time = weapon.base_fire_rate
		# autostart starts timer the instant its in the world. 
		# start() does not work until after in the world.
		timer.autostart = true

	return weapon
	
func create_artifact(artifact, upgrade):
	artifact.name = upgrade.target_class_name
	return artifact

## Sets a property on an object, supporting nested paths like "resource/property".
## @param target_object: Object - The root object to modify (e.g., the weapon node).
## @param property_path: String - The path to the property (e.g., "projectile_stats/damage").
## @param value: Variant - The new value to set.
func set_nested_property(target_object: Object, property_path: String, value):
	# Split the path into parts. e.g., "projectile_stats/damage" becomes ["projectile_stats", "damage"]
	var path_parts = property_path.split("/")
	
	var current_object = target_object
	
	# Loop through the path parts, descending into nested objects.
	# We stop at the second-to-last part.
	for i in range(path_parts.size() - 1):
		var part = path_parts[i]
		if current_object.has_method("get") and current_object.get(part):
			current_object = current_object.get(part)
		else:
			printerr("Invalid path '%s' on object %s" % [property_path, target_object])
			return
			
	# The final part of the path is the property we want to set.
	var final_property = path_parts[path_parts.size() - 1]
	current_object.set(final_property, value)

## Gets a property from an object, supporting nested paths.
func get_nested_property(target_object: Object, property_path: String):
	var path_parts = property_path.split("/")
	var current_object = target_object
	
	for part in path_parts:
		if current_object and current_object.has_method("get") and current_object.get(part) != null:
			current_object = current_object.get(part)
		else:
			printerr("Invalid path part '%s' in '%s' on object %s" % [part, property_path, target_object])
			return null
			
	# After the loop, current_object holds the final value.
	return current_object
