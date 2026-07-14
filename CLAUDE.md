# Fish Food

A bullet-heaven / Vampire-Survivors-like infinite-wave game. **Godot 4.4** (GDScript, "GL
Compatibility" renderer). Layout: `actors/`, `systems/`, `items/`, `world/`, `ui/`, `tests/`.

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
- **Object pools are sized `MAX_POOL_SIZE = 2000`** with **concurrent caps** that stop the pool-churn
  runaway (`MAX_ACTIVE_GENERIC = 300` projectiles, damage-number `MAX_ACTIVE = 150`). Callers handle
  `null` from a capped pool — keep that.
- **Sparks run off the physics broadphase** (`SparkProjectile.use_spatial_hits = true`, spatial-hash
  hit detection) so spark *count* isn't hard-clipped — a low cap would limit spark builds, i.e.
  performance clipping gameplay. `max_active_sparks` (800) is a safety backstop, not a gameplay limit;
  sparks self-limit by lifespan. Prefer bounding cost this way (off-broadphase, self-limiting) over a
  hard gameplay cap wherever possible.
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
