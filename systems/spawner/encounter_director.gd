## encounter_director.gd
## An "Encounter Director" that maintains the live enemy population at a difficulty target.
## The difficulty curve sets the TARGET on-screen threat (Challenge Rating) over time; the director
## tops up toward it, holds a hard count cap for performance, recycles stragglers to keep the fight
## local, and lets authored burst/boss events spike over the cap. Which enemies fill the slots is
## decided by the tag-weighting / biome / counter-spawn logic further down -- that is unchanged.
class_name EncounterDirector
extends Node

# --- CONFIGURATION ---
@export var enemy_scene: PackedScene
@export var difficulty_curve: Curve
@export var encounter_sets: Array[EncounterSet]
@export var spawn_radius: float = 1200.0
@export var encounter_config: EncounterConfig  ## Tag-based weighting (overrides biome config)

# --- POPULATION MODEL (bounded spawning) ---
# The difficulty curve defines the TARGET on-screen threat (total Challenge Rating), a setpoint the
# director maintains at all times -- not a spawn rate. This keeps the felt difficulty controlled and
# the object count bounded, the way Vampire Survivors does. Bursts/bosses are exempt (see below).
## Scales the curve into a target CR. The curve was authored as a rate (~1-40); this maps it to a
## sensible live-enemy count. Tune this (and the cap) to taste per platform.
@export var target_threat_scale: float = 6.0
## Hard ceiling on concurrent live enemies -- the performance backstop. Burst/boss events ignore it.
@export var max_active_enemies: int = 250
## Cap on normal top-up spawns per pulse, to smooth ramp-in. Burst/boss events ignore it.
@export var max_spawns_per_pulse: int = 40
## No single enemy in the top-up stream may cost more than this share of the current target CR --
## the director maintains a HORDE, not a duel. At 0.15 any target is filled by at least ~6-7 bodies,
## and pace is felt in bodies. Authored events/bosses bypass the pulse and stay exempt (big enemies
## are authored moments), and since the allowance is a share of a GROWING target, heavier enemies
## re-enter the stream naturally as the run progresses: early = chaff horde, late = mixed.
@export var max_enemy_budget_share: float = 0.15
## The field never idles below this many live enemies: when the CR budget is spent but the count is
## under the floor, the pulse tops up with the cheapest tier anyway (slight CR overshoot, still under
## the hard perf caps). This is Vampire Survivors' "minimum wave count" -- the half of its model the
## setpoint didn't take. Without it, a player kiting one tough-but-slow enemy freezes the game quiet:
## no kills, no budget freed, no spawns, no pace. Count-based on purpose.
@export var min_active_enemies: int = 6
## The floor GROWS across the run (VS's own minimums are per-wave and increase; our first import of
## the idea was static). Late-game the mix legitimately skews heavy -- time-gated sets author bigger
## enemies and the 15% per-enemy share re-admits them -- so bodies-per-CR falls and the game feels
## empty even at a full threat budget. Pace is felt in BODIES, not CR: the growing floor back-fills
## with the cheapest tier, adding count at trivial CR cost (bounded overshoot; perf caps absolute).
@export var min_active_enemies_late: int = 48
## Seconds over which the floor ramps from min_active_enemies to min_active_enemies_late.
@export var min_floor_ramp_time: float = 1200.0

## The count floor for the current run time: lerped between the start and late values.
func _current_min_active() -> int:
	if min_floor_ramp_time <= 0.0:
		return min_active_enemies
	var t: float = clampf(run_timer / min_floor_ramp_time, 0.0, 1.0)
	return roundi(lerpf(float(min_active_enemies), float(min_active_enemies_late), t))
## Enemies farther than this from the player are recycled onto the spawn ring, keeping the fight
## local and bounding cost (VS-style off-screen recycling). Must exceed spawn_radius. 0 disables it.
@export var despawn_radius: float = 1800.0
## How often (seconds) the director tops up population and recycles stragglers.
@export var spawn_pulse_interval: float = 0.25

## --- WALLED-SHARE CAP (armor) ---
## Armor is a flat per-hit subtraction, so an armored enemy can be LITERALLY undamageable by a build
## whose hits all land under the threshold (no DoT -- DoT ticks with 100% armor pen -- and no hit
## clearing armor after pen). That's intended: hard counters stay hard, and in HARD counter mode being
## walled is the player's own drafting mistake, answerable by tiering up (merge raises damage-per-hit).
## But a field the build cannot interact with is a gate, not a counter -- so the share of live enemies
## that are walls to the CURRENT build is capped. Design band 0.35-0.5.
## The cap self-disables the moment the build gains any armor answer (a DoT source, enough pen, a
## future chip artifact): nothing is walled, so every candidate passes untouched.
@export var max_walled_share: float = 0.4

## Counter STRENGTH: the exponent on effectiveness in the difficulty weighting -- weight x eff^k
## (FAVORING) or weight / eff^k (ADVERSARIAL). 0 = indifferent (counter modes stop mattering),
## 1 = the measured counter relationships as-is, >1 amplifies them. This is the dial the sweep
## pipeline anticipated: a lever for tiers above Abyssal, or for ramping counter pressure across a
## run, without ever touching the measured grid values.
@export var counter_strength: float = 1.0

@onready var spawn_pulse_timer: Timer = $Timer

# --- RUNTIME STATE ---
var run_timer: float = 0.0
## Total Challenge Rating of live enemies, counted once per enemy. This is the value we hold at the
## target (the ledger below double-counts multi-tag enemies, so it can't serve as the total).
var _active_threat_cr: float = 0.0
var player_node: Node2D
var active_biome: BiomeDefinition  ## Set from CurrentRun at start


# --- THREAT TRACKING ---
# Key: EnemyTags.Behavior enum value, Value: Total Challenge Rating on screen (float)
var current_threat: Dictionary = {}
# A list of all encounter sets, which will shrink as they are processed.
var pending_encounter_sets: Array[EncounterSet]

# --- METAPROGRESSION ---
var threat_level: float = 1.0 # This will later be fetched from GameData as a player unlocks/increases difficulty

# --- BUILD ANALYSIS (for counter-spawning) ---
var build_analyzer: BuildAnalyzer = null

func _ready():
	# Validate that we have everything we need to function.
	if not enemy_scene or not difficulty_curve or encounter_sets.is_empty():
		printerr("DynamicSpawner is not fully configured! Disabling.")
		set_physics_process(false)
		return

	player_node = get_tree().get_first_node_in_group("player")

	# Get biome from CurrentRun (if set)
	active_biome = CurrentRun.selected_biome

	# Get encounter config - priority: CurrentRun > @export override > biome default
	if CurrentRun.selected_encounter_config:
		encounter_config = CurrentRun.selected_encounter_config
	elif not encounter_config and active_biome and active_biome.encounter_config:
		encounter_config = active_biome.encounter_config

	if encounter_config:
		Logs.add_message("Encounter Config: %s" % encounter_config.display_name)

	# In the future, get this from GameData:
	# threat_level = GameData.data["permanent_stats"].get("threat_level", 1.0)
	spawn_pulse_timer.wait_time = spawn_pulse_interval
	spawn_pulse_timer.timeout.connect(_on_spawn_pulse_timer_timeout)
	# Sort the master list by time and create pending list.
	encounter_sets.sort_custom(func(a, b): return a.time_start < b.time_start)
	pending_encounter_sets = encounter_sets.duplicate()

	# Initialize build analysis for counter-spawning (only when a counter mode is active)
	if CurrentRun.counter_mode != CurrentRun.CounterMode.NEUTRAL:
		_update_build_analysis()
		# Re-analyze when player's build changes (weapons/upgrades/artifacts)
		if is_instance_valid(player_node) and player_node.has_signal("stats_changed"):
			player_node.stats_changed.connect(_update_build_analysis)
	
func _physics_process(delta: float):
	if not is_instance_valid(player_node): return

	run_timer += delta

	# Fire any one-time "override" events that are due. These are authored bursts/bosses and
	# deliberately bypass the population target and cap -- the VS "map event" spike -- so intensity
	# moments stay in your control instead of emerging as an accidental pile-up.
	# While loop handles multiple events triggering on the same frame.
	while not pending_encounter_sets.is_empty() and run_timer >= pending_encounter_sets[0].time_start:
		var event_to_check = pending_encounter_sets[0]

		if event_to_check.spawn_immediately_on_start:
			# It's a boss/burst event. Process it now, exempt from the cap.
			var event = pending_encounter_sets.pop_front() # Get and remove it from the list
			Logs.add_message("Director Override: Spawning immediate event '%s'" % event.resource_path)

			for enemy_stat in event.enemies:
				spawn_enemy(enemy_stat)
		else:
			# It's a normal, repeating set. Since the list is sorted,
			# we know no later "immediate" events are ready yet.
			break

## Maintains the live enemy population at the difficulty target: recycles stragglers, then tops up
## toward the target CR, bounded by the hard count cap and a per-pulse smoothing limit.
func _on_spawn_pulse_timer_timeout():
	# Keep the fight local first -- recycling brings distant enemies back around the player.
	_recycle_distant_enemies()

	var available_enemies = _get_currently_available_enemies()
	if available_enemies.is_empty(): return

	# The curve defines the TARGET on-screen threat (a setpoint), scaled and modified by run intensity.
	var target_cr: float = difficulty_curve.sample(run_timer) * threat_level \
		* CurrentRun.get_intensity_multiplier() * target_threat_scale

	# The walled-share cap needs the build's damage profile and the field's current composition.
	# Both are computed once per pulse and the counts tracked locally as we spawn.
	var build := _build_damage_profile()
	var field := _count_walled_field(build)

	# No single top-up enemy may cost more than this share of the target: a horde, not a duel.
	var per_enemy_budget: float = target_cr * max_enemy_budget_share

	# Top up toward the target. We stop at the target, the hard perf cap, or the per-pulse limit --
	# whichever comes first. A strong player who clears fast simply gets refilled to the target;
	# a struggling player is never buried past it. Either way the object count stays bounded.
	# The count FLOOR overrides the CR target (never the perf caps): when the field idles below
	# min_active_enemies -- a turtled fat enemy, a string of walls -- the screen still stays alive.
	var spawns := 0
	while spawns < max_spawns_per_pulse \
			and EntityRegistry.get_alive_enemy_count() < max_active_enemies \
			and (_active_threat_cr < target_cr \
				or EntityRegistry.get_alive_enemy_count() < _current_min_active()):
		var enemy_stats = _pick_theme_enemy(available_enemies, per_enemy_budget)
		# 15% of an early-game target can price out the entire pool; the cheapest tier is the honest
		# fallback (the cap exists to force many-and-small, and cheapest IS smallest).
		if not enemy_stats:
			enemy_stats = _pick_theme_enemy(available_enemies, _cheapest_cr(available_enemies))
		if not enemy_stats: break
		enemy_stats = _apply_walled_cap(
			enemy_stats, available_enemies, build, field["walled"], field["alive"], per_enemy_budget)
		spawn_enemy(enemy_stats)
		field["alive"] += 1
		if _is_walled_candidate(enemy_stats, build):
			field["walled"] += 1
		spawns += 1

## Repositions enemies that have fallen too far behind the player back onto the spawn ring. It moves
## the same node (no instantiate/free, so no churn) and leaves threat/count unchanged -- it just keeps
## the horde around the player, mirroring Vampire Survivors' off-screen recycling.
func _recycle_distant_enemies() -> void:
	if despawn_radius <= 0.0 or not is_instance_valid(player_node):
		return
	var ppos: Vector2 = player_node.global_position
	var max_dist_sq: float = despawn_radius * despawn_radius
	for enemy in EntityRegistry.get_enemy_candidates():
		if not is_instance_valid(enemy) or enemy.is_dying:
			continue
		if enemy.global_position.distance_squared_to(ppos) > max_dist_sq:
			var angle: float = randf_range(0, TAU)
			enemy.global_position = ppos + Vector2.RIGHT.rotated(angle) * spawn_radius


## Updates the cached build analysis when player's build changes.
func _update_build_analysis():
	if is_instance_valid(player_node):
		build_analyzer = BuildAnalyzer.analyze_player(player_node)

# --- Walled-share cap helpers ---

## The player's current damage fingerprint: every (damage, armor_pen, dot) source across equipped
## weapons, nested stats included (a fireball's explosion is where its pen lives). Artifacts are NOT
## counted -- their contributions aren't statically readable -- which errs toward judging the build
## LESS capable, i.e. spawning fewer walls. The safe direction.
func _build_damage_profile() -> Dictionary:
	var sources: Array = []
	var any_dot := false
	if is_instance_valid(player_node) and player_node.has_node("Equipment"):
		for weapon in player_node.get_node("Equipment").get_children():
			if weapon.has_method("get_damage_sources"):
				for s in weapon.get_damage_sources():
					sources.append(s)
					any_dot = any_dot or s["dot"]
	return {"sources": sources, "any_dot": any_dot}

## The wall test: true if this much armor zeroes the build's every hit.
func _armor_walls_build(armor: float, build: Dictionary) -> bool:
	# No armor never walls; DoT ignores armor entirely; an empty profile is a boot-order quirk, not
	# a wall.
	if armor <= 0.0 or build["any_dot"] or build["sources"].is_empty():
		return false
	for s in build["sources"]:
		if s["damage"] - armor * (1.0 - s["armor_pen"]) > 0.0:
			return false
	return true

## A candidate's WORST-case fielded armor: base armor times the largest size multiplier it can spawn
## at. Conservative on purpose -- a might-be-large enemy counts as a wall before it rolls large.
func _is_walled_candidate(stats: EnemyStats, build: Dictionary) -> bool:
	var mult := 1.0
	for size_tag in stats.size_tags:
		mult = maxf(mult, EnemyTags.get_size_multipliers(size_tag)["armor_mult"])
	return _armor_walls_build(stats.armor * mult, build)

## Counts the live field: enemies alive, and how many of those the build cannot damage. Live enemies
## carry final size-scaled stats, so no size multiplier here.
func _count_walled_field(build: Dictionary) -> Dictionary:
	# Nothing can be walled for this build -> skip the scan. (The zero counts are consistent: the
	# cap logic never reads them, because no candidate tests as walled either.)
	if build["any_dot"] or build["sources"].is_empty():
		return {"alive": 0, "walled": 0}
	var alive := 0
	var walled := 0
	for enemy in EntityRegistry.get_enemy_candidates():
		if not is_instance_valid(enemy) or enemy.is_dying \
				or not ("stats" in enemy) or enemy.stats == null:
			continue
		alive += 1
		if _armor_walls_build(enemy.stats.armor, build):
			walled += 1
	return {"alive": alive, "walled": walled}

## Enforces the cap at pick time: once the field is at the cap, a walled candidate is re-picked from
## the non-walled candidates (theme/biome/counter weights still apply within them, and the re-pick
## honours the same per-enemy budget). If EVERY available enemy is a wall, the candidate stands --
## a starved wave is worse than a walled one.
func _apply_walled_cap(candidate: EnemyStats, available: Array[EnemyStats], build: Dictionary,
		walled: int, alive: int, per_enemy_budget: float = INF) -> EnemyStats:
	if not _is_walled_candidate(candidate, build):
		return candidate
	if alive <= 0 or float(walled) / float(alive) < max_walled_share:
		return candidate
	var open: Array[EnemyStats] = []
	for es in available:
		if not _is_walled_candidate(es, build):
			open.append(es)
	if open.is_empty():
		return candidate
	var repick := _pick_theme_enemy(open, per_enemy_budget)
	if not repick:
		repick = _pick_theme_enemy(open, _cheapest_cr(open))
	return repick if repick else candidate

## The smallest challenge rating in the pool -- the budget that admits exactly the cheapest tier.
func _cheapest_cr(pool: Array[EnemyStats]) -> float:
	var cheapest := INF
	for es in pool:
		cheapest = minf(cheapest, es.challenge_rating)
	return cheapest

## Gathers all enemies from EncounterSets that are active at the current run_timer.
## If a biome is selected, filters to only enemies matching that biome.
func _get_currently_available_enemies() -> Array[EnemyStats]:
	var available: Array[EnemyStats] = []
	for encounter_set in encounter_sets:
		var is_active = run_timer >= encounter_set.time_start and \
						(encounter_set.time_end == -1 or run_timer < encounter_set.time_end)

		if is_active:
			available.append_array(encounter_set.enemies)

	# Biome no longer HARD-filters the pool -- it's a soft preference now. All time-active enemies stay
	# eligible; native enemies are simply weighted up in _pick_weighted_enemy (off-biome can still appear).
	return available

## Selects an enemy from the pool, weighted by EncounterConfig tags.
func _pick_theme_enemy(pool: Array[EnemyStats], budget: float) -> EnemyStats:
	var affordable_pool = pool.filter(func(es): return es.challenge_rating <= budget)
	if affordable_pool.is_empty(): return null

	# Always go through weighted selection -- it folds in the biome preference and the difficulty
	# countering even when there is no encounter_config.
	return _pick_weighted_enemy(affordable_pool)


## Picks an enemy from the pool using EncounterConfig tag weights.
## Applies difficulty-based effectiveness multipliers if in EASY/HARD mode.
func _pick_weighted_enemy(pool: Array[EnemyStats]) -> EnemyStats:
	if pool.is_empty(): return null

	# Weight = (config tag weight, or 1.0) x biome native-preference x difficulty countering.
	# The three factors compose, so a biome pulls toward its natives while HARD mode can still pull
	# toward the enemies that counter your build.
	var weighted_enemies: Array = []
	var total_weight = 0.0

	for enemy_stats in pool:
		var weight = encounter_config.calculate_enemy_weight(enemy_stats) if encounter_config else 1.0
		# Biome soft-preference: native enemies more likely (off-biome still possible).
		if active_biome:
			weight *= active_biome.get_native_multiplier(enemy_stats)
		# Adversarial difficulty countering (EASY/HARD).
		weight = _apply_difficulty_weight(weight, enemy_stats)

		total_weight += weight
		weighted_enemies.append({"stats": enemy_stats, "weight": weight})

	# If all weights are zero, fall back to random
	if total_weight <= 0:
		return pool.pick_random()

	# Weighted random selection
	var roll = randf() * total_weight
	var cumulative = 0.0
	for entry in weighted_enemies:
		cumulative += entry.weight
		if roll <= cumulative:
			return entry.stats

	return pool[0]

## Applies counter-mode weight adjustments using build analysis.
## EASY: Spawn more enemies the player counters (effectiveness > 1 = higher weight)
## HARD: Spawn more enemies that counter the player (effectiveness < 1 = higher weight)
func _apply_difficulty_weight(base_weight: float, enemy_stats: EnemyStats) -> float:
	# Skip when the ocean is indifferent ("Hard" tier: NEUTRAL = no counter adjustments)
	if CurrentRun.counter_mode == CurrentRun.CounterMode.NEUTRAL:
		return base_weight
	if not build_analyzer:
		return base_weight

	# Get average effectiveness vs this enemy's behaviors
	var total_effectiveness = 0.0
	var behavior_count = 0
	for behavior in enemy_stats.behavior_tags:
		total_effectiveness += build_analyzer.get_effectiveness_vs_behavior(behavior)
		behavior_count += 1

	if behavior_count == 0:
		return base_weight

	var avg_effectiveness = total_effectiveness / behavior_count

	match CurrentRun.counter_mode:
		CurrentRun.CounterMode.FAVORING:
			# Higher effectiveness = spawn more (player is strong against this).
			# counter_strength exponentiates: k=1 -> eff 1.5 = weight x1.5; k=2 = x2.25.
			return base_weight * pow(avg_effectiveness, counter_strength)
		CurrentRun.CounterMode.ADVERSARIAL:
			# Lower effectiveness = spawn more (player is weak against this).
			# Inverted and exponentiated: k=1 -> eff 0.5 = weight x2.0; k=2 = x4.0.
			if avg_effectiveness > 0:
				return base_weight / pow(avg_effectiveness, counter_strength)
			return base_weight

	return base_weight

## Instantiates and positions a single enemy.
## If `position_override` is given, spawns there; otherwise at a random point on the spawn ring.
func spawn_enemy(stats: EnemyStats, position_override = null):
	var enemy_instance = enemy_scene.instantiate()

	# Pick a random size from the enemy's allowed sizes and apply scaling
	var scaled_stats = _apply_size_scaling(stats)
	enemy_instance.stats = scaled_stats.stats
	enemy_instance.spawned_size = scaled_stats.size

	var spawn_position
	if position_override != null:
		spawn_position = position_override
	else:
		var random_angle = randf_range(0, TAU)
		var spawn_offset = Vector2.RIGHT.rotated(random_angle) * spawn_radius
		spawn_position = player_node.global_position + spawn_offset

	enemy_instance.global_position = spawn_position
	enemy_instance.scale *= scaled_stats.visual_scale
	get_tree().current_scene.add_child(enemy_instance)
	# Register with EntityRegistry for cached lookups
	EntityRegistry.register_enemy(enemy_instance)
	# Track threat with the enemy's ACTUAL (size-scaled) stats, so the increment here matches the
	# decrement on death (which emits the scaled stats). Increment the CR total once per enemy.
	enemy_instance.died.connect(_on_enemy_died)
	_update_threat_ledger(scaled_stats.stats, 1)
	_active_threat_cr += scaled_stats.stats.challenge_rating

## DEBUG: Immediately spawns `count` enemies clumped near the player, for perf testing.
## Invoked by the dev console `spawn` command.
func debug_spawn(count: int) -> void:
	if not is_instance_valid(player_node):
		player_node = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player_node):
		return
	# Gather any valid enemy stats from the configured encounter sets.
	var pool: Array = []
	for es in encounter_sets:
		pool.append_array(es.enemies)
	if pool.is_empty():
		return
	for i in count:
		var offset = Vector2.RIGHT.rotated(randf_range(0, TAU)) * randf_range(60.0, 280.0)
		spawn_enemy(pool.pick_random(), player_node.global_position + offset)

## Picks a size from the enemy's allowed sizes (weighted by EncounterConfig) and returns scaled stats.
## Returns a Dictionary with "stats" (duplicated & scaled), "size" (chosen size), "visual_scale" (float).
func _apply_size_scaling(base_stats: EnemyStats) -> Dictionary:
	# Pick size using EncounterConfig weights, or random if no config
	var chosen_size = EnemyTags.Size.MEDIUM
	if encounter_config:
		chosen_size = encounter_config.pick_weighted_size(base_stats)
	elif not base_stats.size_tags.is_empty():
		chosen_size = base_stats.size_tags.pick_random()

	var multipliers = EnemyTags.get_size_multipliers(chosen_size)

	# Duplicate stats to avoid modifying the shared resource
	var scaled_stats = base_stats.duplicate()

	# Apply multipliers
	scaled_stats.max_health = int(base_stats.max_health * multipliers.hp)
	scaled_stats.damage = int(base_stats.damage * multipliers.damage)
	scaled_stats.move_speed = base_stats.move_speed * multipliers.speed

	# Scale armor if enemy has any
	if base_stats.armor > 0:
		scaled_stats.armor = int(base_stats.armor * multipliers.armor_mult)

	# Scale challenge rating and XP based on size
	scaled_stats.challenge_rating = base_stats.challenge_rating * multipliers.xp

	return {
		"stats": scaled_stats,
		"size": chosen_size,
		"visual_scale": multipliers.scale
	}
	
## Signal handler for when any enemy dies.
func _on_enemy_died(enemy_stats: EnemyStats):
	_update_threat_ledger(enemy_stats, -1)
	_active_threat_cr = max(0.0, _active_threat_cr - enemy_stats.challenge_rating)
	
## Helper function to modify our internal threat tally using behavior tags.
func _update_threat_ledger(enemy_stats: EnemyStats, multiplier: int):
	# Track threat by behavior tags
	for tag in enemy_stats.behavior_tags:
		var current_cr = current_threat.get(tag, 0.0)
		var cr_change = enemy_stats.challenge_rating * multiplier
		current_threat[tag] = max(0.0, current_cr + cr_change)

func _on_timer_timeout() -> void:
	pass # Replace with function body.
