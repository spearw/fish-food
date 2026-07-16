# Fish Food

A bullet-heaven / Vampire-Survivors-like infinite-wave game. **Godot 4.4** (GDScript, "GL
Compatibility" renderer). Layout: `actors/`, `systems/`, `items/`, `world/`, `ui/`, `tests/`.

## Balance is a first-class concern

**Adding a weapon, artifact or upgrade? Read [`.claude/balance/`](.claude/balance/README.md) first**,
and follow [`workflow.md`](.claude/balance/workflow.md) to ballpark it.

The short version: **feel is law** — bullet heavens are built on the rush of feeling overpowered at the
end, so a build that's behind on a spreadsheet but feels incredible is *correct*. There is no formula
to look balance up in (the research is in [`methods.md`](.claude/balance/methods.md)); the state of the
art is to **simulate**, which is what `balance_bench.tscn` is for. And keep **transitive** (rarity
tiers → price them) apart from **intransitive** (weapon vs weapon → counter-play, don't price them).

## Performance is a first-class constraint

This is a horde game: the frame must stay smooth with a screen full of enemies and projectiles, on
**modest hardware** (the reference target is a 2020 Intel MacBook Pro, not a fast dev PC). Treat
performance as a design constraint, not a later cleanup.

**Before changing anything that runs per-entity per-frame or spawns objects at high frequency —
spawning, object pools, projectiles, enemy scripts/AI, or the entity registry — read
[`.claude/performance/`](.claude/performance/README.md).** It records the decisions and the
benchmark numbers behind them so they don't get silently reverted.

### Load-bearing invariants (don't change without a benchmark on target hardware)

- **Spawning is a population model**, not a spawn-rate model (`systems/spawner/encounter_director.gd`):
  the difficulty curve is the *target on-screen threat*, capped by `max_active_enemies` (250). Do not
  revert to a budget/flow spawner — that reintroduces the unbounded enemy pile-up.
  Two pace guards sit on top (Jul 2026, playtest-driven): **`max_enemy_budget_share` (0.15)** — no
  single top-up enemy may cost more than 15% of the target, so the field is a horde, not a duel
  (before: two fatties could eat the whole early budget, overshoot it, and freeze the stream at 2
  enemies); and **`min_active_enemies` (6) ramping to `min_active_enemies_late` (48) over 1200 s** —
  the count floor that keeps spawning when nothing dies AND keeps the late game full of bodies (VS's
  wave minimums GROW across the run; our static floor stopped mattering after minute one — late-game
  the mix skews heavy, so bodies-per-CR falls and a met threat budget still feels empty). Authored
  events/bosses bypass both. Measured: run-start pop 2 → 10-11 at identical CR; late-game healthy.
- **Object pools are sized `MAX_POOL_SIZE = 2000`** with **concurrent caps** that stop the pool-churn
  runaway (`MAX_ACTIVE_GENERIC = 300` projectiles, damage-number `MAX_ACTIVE = 150`). Callers handle
  `null` from a capped pool — keep that.
- **Sparks run off the physics broadphase** (`SparkProjectile.use_spatial_hits = true`, spatial-hash
  hit detection) so spark *count* isn't hard-clipped — a low cap would limit spark builds, i.e.
  performance clipping gameplay. `max_active_sparks` (800) is a safety backstop, not a gameplay limit;
  sparks self-limit by lifespan. Prefer bounding cost this way (off-broadphase, self-limiting) over a
  hard gameplay cap wherever possible — but off-broadphase is **not** a universal win: it's only for the
  high-count, dense, cheap-per-hit case. Daggers regressed off-broadphase and damage zones use cached
  overlap, so both stay on Area2D. Measure before converting (architecture.md §7).
- **Enemies don't collide with each other** (`enemy.tscn` `collision_mask = 1`); proximity detectors
  are opt-in. Don't make either always-on.
- **Proximity/targeting queries go through the `EntityRegistry` spatial hash** (`get_enemies_near` /
  `get_candidates_near`), never a loop over all enemies.
- **Damage numbers stay** — they're cheap (~1 ms/150) and core game feel; the pool cap bounds them.

Full rationale in [`.claude/performance/architecture.md`](.claude/performance/architecture.md);
benchmark harness and methodology in
[`.claude/performance/benchmarking.md`](.claude/performance/benchmarking.md).

## Verifying performance changes

Don't trust a change by eye — run the relevant benchmark scene (`nat_bench`, `spark_bench`,
`dmgnum_bench`, `full_bench`) and compare wall-clock frame time. See the benchmarking doc for commands
and the measurement traps (the dev PC is ~60–80× faster than the Mac, so use relative frame time and
object counts, not absolute FPS).
