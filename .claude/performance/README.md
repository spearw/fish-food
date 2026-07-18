# Performance — first-class concern

Fish Food is a bullet-heaven survivors game. The whole genre lives or dies on being able to
put a horde on screen and keep the frame smooth. **Performance is a design constraint here, not
an afterthought.** The reference target is a **2020 Intel MacBook Pro** — modest hardware — and
the game must stay smooth there, not just on a fast dev PC.

This folder is the durable record of the performance work and the decisions behind it, so they
survive refactors and don't get silently reverted by a well-meaning "cleanup."

## Read this before you touch

Anything that runs per-entity per-frame or spawns objects at high frequency:

- Spawning / difficulty — `systems/spawner/encounter_director.gd`
- Object pools — `systems/global/projectile_pool.gd`, `systems/global/damage_number_pool.gd`
- Projectiles — `systems/projectiles/projectile.gd`, `items/weapons/spark/spark_projectile.gd`
- Enemies — `actors/enemies/enemy.gd`, `actors/enemies/enemy.tscn`, the AI under `actors/enemies/behaviors/`
- Entity queries — `systems/global/entity_registry.gd`

## The docs

- **[architecture.md](architecture.md)** — how the performance-critical systems work and *why* they're
  built this way. The rationale is the point: it's what stops a naive change from undoing a fix.
- **[benchmarking.md](benchmarking.md)** — the benchmark harness, how to run it, the measurement
  methodology, and the traps that produce misleading numbers.

## Load-bearing invariants

These are tuned against real measurements. **Changing them is allowed — but only with a benchmark
that shows the new value is fine on the target hardware.** Do not change them "because a bigger number
sounds better." Each has a reason and a measurement; see architecture.md for the full story.

| Setting | File | Value | Why it's this value |
|---|---|---|---|
| Spawn model | `encounter_director.gd` | population/target | Difficulty = *target on-screen threat*, not a spawn rate. Bounds the live enemy count (and thus cost) by design. **Do not revert to a budget/flow model** — that's what caused the unbounded pile-up. |
| `max_active_enemies` | `encounter_director.gd` | `250` | Hard cap on concurrent live enemies. Climax (~114 enemies) runs at 0.47 ms; the cap holds even when the difficulty target is cranked past it. |
| `MAX_POOL_SIZE` | `projectile_pool.gd` / `damage_number_pool.gd` | `2000` | Undersized pools (was 100 / 200) caused a **pool-churn runaway** (instantiate/free feedback loop). Raising the ceiling fixed 200 enemies from 101 ms → 2.6 ms. |
| `max_active_sparks` | `projectile_pool.gd` | `800` (safety) | Sparks run **off the broadphase** (`SparkProjectile.use_spatial_hits = true`), so this is a runaway backstop, **not** a gameplay clip — spark builds self-limit by lifespan (~400–465 concurrent). Do **not** re-lower it to clip builds; see architecture §5. |
| `MAX_ACTIVE_GENERIC` | `projectile_pool.gd` | `300` | Bounds concurrent generic projectiles (daggers etc.) so hundreds of Area2Ds can't detonate the broadphase. |
| `MAX_ACTIVE` (damage numbers) | `damage_number_pool.gd` | `150` | Bounds on-screen numbers. Numbers themselves are cheap (~1 ms / 150); this cap is what *keeps* them cheap under any hit volume. |
| Enemy `collision_mask` | `enemy.tscn` | `1` | Enemies collide with the player only, **not each other** — enemy-enemy collision is O(n²) broadphase for no gameplay benefit. |
| Spatial hash | `entity_registry.gd` | `CELL_SIZE=256` | Targeting/proximity queries are O(local density), not O(all enemies). |
| Console echo | `logs.gd` | verbose-gated | **One `print()`/`printerr()` costs ~8 ms on a Windows console** (measured Jul 2026). `Logs.add_message` echoes only under `--verbose`; history always records. The level-up screen's 4 routine log lines were a 40–60 ms freeze, and one unknown-stat `printerr` firing per projectile hit dropped frames game-wide. **Never print in a per-hit or per-frame path**; `printerr` is for genuinely rare error states. Regression gate: `levelup_profile_verify.tscn` (present path < 8 ms warm). |

## The one meta-rule

**Measure in isolation before you optimize.** More than once, a cost was misattributed because it was
read off a noisy benchmark. If you think system X is slow, run (or build) a bench that exercises *only*
X — don't infer its cost from a benchmark where something noisier dominates. See benchmarking.md.
