extends Node
## Headless check of the two-layer stat model: additive within a layer, multiplicative across layers
## (the shape HoT / VS / PoE converge on -- .claude/balance/methods.md section 4). Boots the real
## world and applies real cards through the real pipeline. Run with --headless.
##   1. MULTIPLICATIVE cards compound: three +10% damage = x1.331, not +30%.
##   2. ADDITIVE flat cards sum in in_run_bonuses and never touch the multiplier bucket -- including
##      the reassigned flat-count cards (projectile count), where x-per-copy would have been a bomb.
##   3. The layers compose: (1 + permanent + sum_increased) * product_more.
##   4. Inverted stats (firerate: lower is better): increased subtracts, "more" divides.

const DAMAGE_CARD := "res://systems/upgrades/upgrades/core/player_damage.tres"
const PROJ_COUNT_CARD := "res://systems/upgrades/upgrades/core/player_projectile_count.tres"
const FIRERATE_CARD := "res://systems/upgrades/upgrades/core/player_firerate.tres"

## False on the scene-root bootstrap; true on the probe that lives on the tree ROOT and survives the
## scene swap (change_scene_to_file frees the bootstrap -- the same trap every bench probe dodges).
var is_probe := false

var _booted := false
var _boot_frames := 0

func _ready() -> void:
	if is_probe:
		process_mode = Node.PROCESS_MODE_ALWAYS
		return
	CurrentRun.selected_character = load("res://actors/player/characters/test_character/test_character.tres")
	CurrentRun.selected_biome = load("res://systems/spawner/biomes/reef_biome.tres")
	CurrentRun.selected_pack_paths = []
	var probe = load("res://multiplicativity_verify.gd").new()
	probe.is_probe = true
	get_tree().root.add_child.call_deferred(probe)
	get_tree().change_scene_to_file.call_deferred("res://world/world.tscn")

func _process(_dt: float) -> void:
	if not is_probe:
		return
	get_tree().paused = false
	if _booted:
		return
	_boot_frames += 1
	if _boot_frames > 1500:
		print("MULTVERIFY ERROR: world never became ready")
		get_tree().quit()
		return
	var player = get_tree().get_first_node_in_group("player")
	var scene := get_tree().current_scene
	if not is_instance_valid(player) or scene == null:
		return
	var um = scene.find_child("UpgradeManager", true, false)
	if um == null or not is_instance_valid(um.player):
		return
	_booted = true
	_run_checks(player, um)

func _apply(um, card_path: String, rarity: int) -> void:
	um.apply_upgrade({"upgrade": load(card_path), "rarity": rarity})

func _run_checks(player, um) -> void:
	var perm_dmg: float = GameData.data["permanent_stats"].get("damage_increase", 0.0)
	var base_dmg: float = player.get_stat("damage_increase")

	# --- 1. Three MULTIPLICATIVE +10% cards -> x1.331 of the base, not +0.30 ---
	for i in range(3):
		_apply(um, DAMAGE_CARD, Upgrade.Rarity.COMMON)
	var after: float = player.get_stat("damage_increase")
	var mult_ok: bool = absf(after / base_dmg - pow(1.1, 3)) < 0.002
	print("MULTVERIFY more_layer: base=%.3f after_3x10%%=%.3f ratio=%.3f expected=%.3f ok=%s" % [
		base_dmg, after, after / base_dmg, pow(1.1, 3), str(mult_ok)])

	# --- 2. The reassigned flat card sums additively and stays out of the multiplier bucket ---
	_apply(um, PROJ_COUNT_CARD, Upgrade.Rarity.COMMON)  # +0.4, ADDITIVE now
	var flat_ok: bool = absf(player.in_run_bonuses.get("projectile_count_multiplier", 0.0) - 0.4) < 0.001 \
		and not player.in_run_multipliers.has("projectile_count_multiplier")
	print("MULTVERIFY additive_layer: proj_count bonus=%.2f in_mult_bucket=%s ok=%s" % [
		player.in_run_bonuses.get("projectile_count_multiplier", 0.0),
		str(player.in_run_multipliers.has("projectile_count_multiplier")), str(flat_ok)])

	# --- 3. Layers compose: (1 + perm + increased) * more ---
	player.add_bonus("damage_increase", 0.2)
	var expected: float = (1.0 + perm_dmg + 0.2) * pow(1.1, 3)
	var composed: float = player.get_stat("damage_increase")
	var compose_ok: bool = absf(composed - expected) < 0.002
	print("MULTVERIFY compose: got=%.4f expected=%.4f ok=%s" % [composed, expected, str(compose_ok)])

	# --- 4. Inverted stat: a "more" firerate card divides the wait multiplier ---
	var perm_fr: float = GameData.data["permanent_stats"].get("firerate", 0.0)
	_apply(um, FIRERATE_CARD, Upgrade.Rarity.COMMON)  # +0.1 MULTIPLICATIVE
	var fr: float = player.get_stat("firerate")
	var fr_expected: float = maxf(0.1, (1.0 - perm_fr) / 1.1)
	var invert_ok: bool = absf(fr - fr_expected) < 0.002
	print("MULTVERIFY inverted: firerate=%.4f expected=%.4f ok=%s" % [fr, fr_expected, str(invert_ok)])

	# --- 5. Unknown-flag regression: has_conductive must read 0 without the artifact. The unknown-key
	# fallback returns 1.0, which once made every weapon spark as if Conductive were held. ---
	var conductive_flag: float = player.get_stat("has_conductive")
	var conductive_ok: bool = conductive_flag == 0.0
	print("MULTVERIFY conductive_flag: value=%.1f ok=%s" % [conductive_flag, str(conductive_ok)])

	var pass_all: bool = mult_ok and flat_ok and compose_ok and invert_ok and conductive_ok
	print("MULTVERIFY RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
