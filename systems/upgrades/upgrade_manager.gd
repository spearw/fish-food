## upgrade_manager.gd
## Manages the pool of available upgrades, filters them based on player inventory,
## and applies selected upgrades.
extends Node

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
		Upgrade.UpgradeType.UNLOCK_WEAPON, Upgrade.UpgradeType.UNLOCK_ARTIFACT, \
		Upgrade.UpgradeType.TRANSFORMATION:
			# These are drawn at exactly their own rarity.
			_unlock_buckets[upgrade.rarity].append(upgrade)
		Upgrade.UpgradeType.UPGRADE:
			# Stat upgrades scale with rarity, so they can appear in every tier they define a value for.
			for rarity_idx in range(upgrade.rarity_values.size()):
				_upgrade_buckets[rarity_idx].append(upgrade)

## Folds the character's exclusive cards into the pool. They're credited to the character's primary
## deck: a Magic Man drafting a Cinder Volley evolution is investing in fire like any other fire card,
## and combo gates should count it as such.
func _add_character_exclusives() -> void:
	var character: PlayerStats = CurrentRun.selected_character
	if not character or character.exclusive_upgrades.is_empty():
		return

	var primary_id: String = character.primary_deck.id if character.primary_deck else ""
	for upgrade in character.exclusive_upgrades:
		if upgrade == null:
			continue
		active_upgrade_pool.append(upgrade)
		_upgrade_deck_ids[upgrade] = primary_id
		_bucket_upgrade(upgrade)

	Logs.add_message(["Character exclusives added:", character.exclusive_upgrades.size()])

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

## Returns a specified number of valid, random upgrade choices.
func get_upgrade_choices(count: int) -> Array[Dictionary]:
	Logs.add_message("Getting upgrade choices")
	# --- Filter the pool for currently valid upgrades ---
	var inventory = get_player_inventory_names_and_transformed_item_list()
	var player_inventory = inventory[0]
	var transformed_item_list = inventory[1]
	var filtered_pool: Array[Upgrade] = []
	for upgrade in active_upgrade_pool:
		var target_name = upgrade.target_class_name
		match upgrade.type:
			Upgrade.UpgradeType.UNLOCK_WEAPON, Upgrade.UpgradeType.UNLOCK_ARTIFACT:
				if not target_name in player_inventory:
					filtered_pool.append(upgrade)
			Upgrade.UpgradeType.UPGRADE:
				# Upgrades are stats buffs or they modify something in the inventory.
				if target_name == "Player" or target_name in player_inventory:
					filtered_pool.append(upgrade)
			Upgrade.UpgradeType.TRANSFORMATION:
				# Only list tranformations if player has the weapon and it has not been transformed.
				if target_name in player_inventory and target_name not in transformed_item_list:
					filtered_pool.append(upgrade)

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
				if upg in filtered_pool:
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

## Applies the logic for a given upgrade.
func apply_upgrade(upgrade_package: Dictionary) -> void:
	var upgrade: Upgrade = upgrade_package["upgrade"]
	var chosen_rarity_enum: Upgrade.Rarity = upgrade_package["rarity"]
	if not player_equipment or not player_artifacts:
		printerr("UpgradeManager: Cannot apply upgrade, player has not been registered.")
		return

	match upgrade.type:
		Upgrade.UpgradeType.UNLOCK_WEAPON:
			if upgrade.scene_to_unlock:
				var new_weapon = create_weapon(upgrade.scene_to_unlock.instantiate(), upgrade)
				player_equipment.add_child(new_weapon)
			else:
				printerr("Unlock upgrade '%s' is missing a scene!" % upgrade.id)

		Upgrade.UpgradeType.UNLOCK_ARTIFACT:
			if upgrade.scene_to_unlock:
				var new_artifact = create_artifact(upgrade.scene_to_unlock.instantiate(), upgrade)
				if "user" in new_artifact:
					new_artifact.user = self.player
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
					Upgrade.ModifierType.MULTIPLICATIVE, Upgrade.ModifierType.ADDITIVE:
						# It's a standard stat bonus. Call the player's bonus function.
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
			
func create_weapon(weapon, upgrade):
	weapon.name = upgrade.target_class_name
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
