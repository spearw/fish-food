extends Node
## Headless check of universal crit composition (decision July 2026, research-backed -- see
## .claude/balance/README.md "Crit composition"). Run with --headless.
##   1. Weapon path: chance = (base + flat) x cards, damage = (1 + base + flat cd) x cd cards;
##      enemy-fired sources keep raw authored numbers.
##   2. Universal: a DoT tick (ZERO base crit) crits for a flat-crit player, never without flat,
##      never for enemy sources -- and the crit tick credits its rolled damage.
##   3. Bushido momentum: rolling-window stacks on game time -- grant, cap-refresh, expiry.

class CritPlayer:
	extends Node2D
	var stat_values := {
		"damage_increase": 1.0, "crit_flat": 0.10, "critical_hit_rate": 2.0,
		"crit_damage_flat": 0.50, "critical_hit_damage": 1.0, "dot_damage_bonus": 1.0,
	}
	func _init() -> void:
		add_to_group("player")
	func get_stat(key): return stat_values.get(key, 1.0)

func _ready() -> void:
	CurrentRun.reset_run_state()
	var p := CritPlayer.new()
	add_child(p)

	# --- 1. Weapon path composition + enemy path untouched ---
	var s: Dictionary = DamageUtils.scale_damage_stats(10.0, 0.05, 1.5, p)
	var weapon_ok: bool = absf(s.crit_rate - (0.05 + 0.10) * 2.0) < 0.0001 \
		and absf(s.crit_damage - (1.0 + 1.5 + 0.5) * 1.0) < 0.0001
	var enemy := Node2D.new()
	add_child(enemy)
	var e: Dictionary = DamageUtils.scale_damage_stats(10.0, 0.05, 1.5, enemy)
	var enemy_ok: bool = e.crit_rate == 0.05 and e.crit_damage == 1.5
	print("CRIT weapon: rate=%.3f (want 0.300) dmg=%.2f (want 3.00) enemy_raw=%s" % [
		s.crit_rate, s.crit_damage, str(enemy_ok)])

	# --- 2. Universal ticks (0 base crit) ---
	var host = load("res://actors/entity.gd").new()
	host.stats = load("res://bench_dummies/dummy_baseline.tres").duplicate()
	add_child(host)
	var mgr := StatusEffectManager.new()
	mgr.name = "StatusEffectManager"
	host.add_child(mgr)
	var burn: DotStatusEffect = load("res://systems/status_effects/fire/burning.tres").duplicate(true)
	burn.attribution_key = "CritTest"

	p.stat_values["crit_flat"] = 1.0        # guaranteed crit
	p.stat_values["critical_hit_rate"] = 1.0
	var hp0: int = host.current_health
	burn._do_damage_tick(mgr, p)            # tick 2 x (1 + 0.5 + 0.5) = 4
	var crit_tick: int = hp0 - host.current_health
	var credited: int = CurrentRun.damage_by_source.get("CritTest", 0)

	p.stat_values["crit_flat"] = 0.0        # no flat -> a tick can never crit
	var hp1: int = host.current_health
	burn._do_damage_tick(mgr, p)
	var plain_tick: int = hp1 - host.current_health

	var hp2: int = host.current_health
	burn._do_damage_tick(mgr, null)         # enemy/no source -> plain
	var sourceless_tick: int = hp2 - host.current_health

	var tick_ok: bool = crit_tick == 4 and credited == 4 and plain_tick == 2 \
		and sourceless_tick == 2
	print("CRIT ticks: crit=%d (want 4, credited %d) flatless=%d sourceless=%d ok=%s" % [
		crit_tick, credited, plain_tick, sourceless_tick, str(tick_ok)])

	# --- 3. Bushido momentum window ---
	var bushido = load("res://items/artifacts/identity/bushido/bushido_artifact.gd").new()
	bushido.set_physics_process(false)  # drive the clock by hand
	add_child(bushido)
	bushido.crit_per_stack = 0.01
	bushido.window_seconds = 10.0
	bushido.max_stacks = 2
	bushido._on_kill(null)
	bushido._on_kill(null)
	var two: float = bushido.get_crit_flat_bonus()       # 2 stacks -> 0.02
	bushido._on_kill(null)                                # at cap -> refresh, still 2
	var capped: float = bushido.get_crit_flat_bonus()
	bushido._clock += 10.5                                # window rolls off
	var cooled: float = bushido.get_crit_flat_bonus()
	bushido._on_kill(null)
	var rekindled: float = bushido.get_crit_flat_bonus()  # momentum restarts -> 0.01
	var bushido_ok: bool = absf(two - 0.02) < 0.0001 and absf(capped - 0.02) < 0.0001 \
		and cooled == 0.0 and absf(rekindled - 0.01) < 0.0001
	print("CRIT bushido: two=%.2f capped=%.2f cooled=%.2f rekindled=%.2f ok=%s" % [
		two, capped, cooled, rekindled, str(bushido_ok)])

	CurrentRun.reset_run_state()
	var pass_all: bool = weapon_ok and enemy_ok and tick_ok and bushido_ok
	print("CRIT RESULT=%s" % ("PASS" if pass_all else "FAIL"))
	get_tree().quit()
