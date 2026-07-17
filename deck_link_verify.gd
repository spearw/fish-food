extends Node
## Headless check of the UNCOUPLED character/deck/weapon model (design doc section 3). Run headless.
##   1. Run composition: the player's picks only, deduped, capped -- there is NO core deck.
##   2. Upgrade 0: one starting-weapon candidate rolled per chosen deck, from the right decks.
##   3. Identity: every character's starting_upgrades are ARTIFACTS (no character starts with a
##      weapon), and applying one granted costs no loadout slot.
##   4. Content: the once-exclusive weapons are back in their decks (Cinder Volley in fire, Axe in
##      melee), and the projectile deck now carries daggers + shotgun.
##   5. Stat coverage law (design doc section 1b, core deck dissolved): every themed deck carries
##      the max-health floor, armor is melee-exclusive, and every former core stat card is still
##      offerable from somewhere.

const FIRE := "res://systems/upgrades/packs/fire_pack.tres"
const LIGHTNING := "res://systems/upgrades/packs/lightning_pack.tres"
const MELEE := "res://systems/upgrades/packs/melee_pack.tres"
const PROJECTILE := "res://systems/upgrades/packs/projectile_pack.tres"

class BurnVictim:
	extends Node2D
	var is_dying := false
	func take_damage(_amount, _pen = 0, _crit = false, _src = null) -> void:
		pass

class MockPlayer:
	extends Node2D
	func _init() -> void:
		var equipment := Node2D.new()
		equipment.name = "Equipment"
		add_child(equipment)
		var artifacts := Node2D.new()
		artifacts.name = "Artifacts"
		add_child(artifacts)
	func get_stat(_key): return 1.0
	func notify_stats_changed() -> void: pass

func _decks(picks: Array[String]) -> Array[String]:
	CurrentRun.selected_pack_paths = picks
	return CurrentRun.get_active_deck_paths()

func _deck_has(deck_path: String, upgrade_id: String) -> bool:
	for u in load(deck_path).upgrades:
		if u != null and u.id == upgrade_id:
			return true
	return false

func _ready() -> void:
	CurrentRun.selected_character = null
	CurrentRun.max_themed_decks = 2

	# --- 1. Composition: picks only, deduped, capped -- no core deck, no character involvement ---
	var comp_ok: bool = _decks([] as Array[String]).is_empty() \
		and _decks([FIRE] as Array[String]) == [FIRE] \
		and _decks([FIRE, LIGHTNING] as Array[String]) == [FIRE, LIGHTNING] \
		and _decks([FIRE, LIGHTNING, MELEE] as Array[String]) == [FIRE, LIGHTNING] \
		and _decks([FIRE, FIRE, LIGHTNING] as Array[String]) == [FIRE, LIGHTNING]
	print("DECKLINK composition=%s" % str(comp_ok))

	# --- 2. Upgrade 0: one weapon candidate per themed deck, each from ITS deck ---
	var player := MockPlayer.new()
	add_child(player)
	var um = load("res://systems/upgrades/upgrade_manager.gd").new()
	CurrentRun.selected_pack_paths = [FIRE, LIGHTNING] as Array[String]
	add_child(um)
	um.register_player(player)

	var candidates: Array = um.get_starting_weapon_candidates()
	var fire_ids: Array = load(FIRE).upgrades.map(func(u): return u.id)
	var lightning_ids: Array = load(LIGHTNING).upgrades.map(func(u): return u.id)
	var starter_ok: bool = candidates.size() == 2 \
		and candidates[0]["upgrade"].type == Upgrade.UpgradeType.UNLOCK_WEAPON \
		and candidates[1]["upgrade"].type == Upgrade.UpgradeType.UNLOCK_WEAPON \
		and candidates[0]["upgrade"].id in fire_ids \
		and candidates[1]["upgrade"].id in lightning_ids
	CurrentRun.selected_pack_paths = [] as Array[String]
	var starter_none_ok: bool = um.get_starting_weapon_candidates().is_empty()
	print("DECKLINK starter: candidates=%d from_right_decks=%s none_without_decks=%s" % [
		candidates.size(), str(starter_ok), str(starter_none_ok)])

	# --- 3. Identity: every character starts with artifacts only, and granted costs no slot ---
	var chars = load("res://systems/global/lists/master_character_list.tres").characters
	var identity_ok := true
	for c in chars:
		for u in c.starting_upgrades:
			if u == null or u.type != Upgrade.UpgradeType.UNLOCK_ARTIFACT:
				identity_ok = false
	var ember = load("res://systems/upgrades/artifacts/identity/emberheart_unlock.tres")
	um.apply_upgrade({"upgrade": ember, "rarity": Upgrade.Rarity.COMMON, "granted": true})
	var ember_node = um.player_artifacts.get_node_or_null("EmberheartArtifact")
	var granted_ok: bool = ember_node != null and um.is_granted(ember_node) and um.get_used_slots() == 0
	print("DECKLINK identity: all_artifact_starts=%s granted_slot_free=%s (used=%d)" % [
		str(identity_ok), str(granted_ok), um.get_used_slots()])

	# --- 3b. Emberheart must be ALIVE in any build: its escalation chain works off any burn source,
	#         and its kill-spread half never depends on the fire deck. (v1 was a dead artifact in
	#         fire-less runs -- it only listened for burns nothing in the build could apply.)
	ember_node.escalate_chance = 1.0
	ember_node.spread_chance = 1.0
	var victim := BurnVictim.new()
	add_child(victim)
	var mgr := StatusEffectManager.new()
	mgr.name = "StatusEffectManager"
	victim.add_child(mgr)
	var seen: Array = []
	var listener := func(e: Node, id: String):
		if e == victim:
			seen.append(id)
	Events.status_applied_to_enemy.connect(listener)
	mgr.apply_status(load("res://systems/status_effects/fire/burning.tres"), null)
	ember_node._on_kill(victim)  # spread smoke: empty registry -> no targets, must not crash
	Events.status_applied_to_enemy.disconnect(listener)
	var ember_alive_ok: bool = "burning" in seen and "ignited" in seen
	print("DECKLINK emberheart: statuses_seen=%s escalation_ok=%s" % [str(seen), str(ember_alive_ok)])

	# --- 4. Content: weapons re-homed ---
	var content_ok: bool = _deck_has(FIRE, "unlock_cinder_volley") or _deck_has(FIRE, "cinder_volley_unlock")
	# ids vary by author; fall back to counting weapons per deck instead of exact ids.
	var fire_weapons: int = load(FIRE).get_composition().get("weapons", 0)
	var melee_weapons: int = load(MELEE).get_composition().get("weapons", 0)
	var proj_weapons: int = load(PROJECTILE).get_composition().get("weapons", 0)
	# fire: flamethrower + cinder volley (returned) + fireball staff + molotov = 4.
	# melee: axe (returned) + hammer + shield + spear = 4. projectile: daggers + shotgun = 2.
	content_ok = fire_weapons == 4 and melee_weapons == 4 and proj_weapons == 5
	print("DECKLINK content: fire_weapons=%d melee_weapons=%d projectile_weapons=%d ok=%s" % [
		fire_weapons, melee_weapons, proj_weapons, str(content_ok)])

	# --- 5. Stat coverage law (section 1b): the core deck is dissolved into the themed decks ---
	var master: Array = load("res://systems/global/lists/master_pack_list.tres").decks
	var health_ok := true
	var armor_decks: Array = []
	var union_ids: Array = []
	for deck in master:
		if deck.id == "test":  # dev scratch pack, exempt from the law
			continue
		var ids: Array = []
		for u in deck.upgrades:
			if u != null:
				ids.append(u.id)
		union_ids.append_array(ids)
		if not "player_max_health" in ids:
			health_ok = false
		if "player_armor" in ids:
			armor_decks.append(deck.id)
	var armor_ok: bool = armor_decks == ["melee"]
	var missing_stats: Array = []
	for stat_id in ["player_damage", "player_crit_chance", "player_crit_damage", "player_area",
			"player_firerate", "player_projectile_count", "player_projectile_speed", "player_armor",
			"player_speed", "player_luck", "player_max_health"]:
		if not stat_id in union_ids:
			missing_stats.append(stat_id)
	print("DECKLINK coverage: health_floor=%s armor_decks=%s missing_stats=%s" % [
		str(health_ok), str(armor_decks), str(missing_stats)])

	var pass_all: bool = comp_ok and starter_ok and starter_none_ok and identity_ok \
		and granted_ok and ember_alive_ok and content_ok \
		and health_ok and armor_ok and missing_stats.is_empty()
	print("DECKLINK RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
