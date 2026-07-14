# Performance architecture & rationale

How the performance-critical systems work, and *why*. The recurring theme: **bound everything.**
In a survivors game the input (enemies, projectiles, hits) is effectively unbounded, so every system
that scales with it must have a ceiling. Uncapped growth is the root cause of nearly every stall.

---

## 1. Spawning: a population model, not a spawn-rate model

**File:** `systems/spawner/encounter_director.gd`

The director treats the `difficulty_curve` as the **target on-screen threat** (total Challenge
Rating) at a given time — a setpoint it maintains — **not** a rate of enemies to emit.

Each pulse (every `spawn_pulse_interval`, 0.25 s) it tops up toward the target, bounded by:
- `max_active_enemies` (250) — a hard count cap, the performance backstop.
- `max_spawns_per_pulse` (40) — smooths ramp-in.

Plus **off-screen recycling**: enemies past `despawn_radius` (1800) are repositioned onto the spawn
ring (same node — no instantiate/free), keeping the fight local and bounded. **Burst/boss events
(`spawn_immediately_on_start`) are exempt** from the cap — the deliberate "overwhelm" spike, like
Vampire Survivors' map events.

### Why this exists / what NOT to do

The **old model was a flow model**: a budget accrued at the curve's rate and was spent to spawn
enemies, which then persisted until killed. On-screen count was therefore an *uncontrolled residue*
of (spawns − kills):
- A struggling player who couldn't keep up got **buried** — an unbounded pile-up that was *the* 400+
  enemy frame cliff (350 ms+). Same bug, two symptoms: bad game feel *and* the perf cliff.
- A strong player who cleared fast faced a near-empty screen.

**Do not revert to a budget/flow spawner.** The population model makes difficulty a controlled
setpoint *and* bounds the object count as a consequence. Verified on the dev PC: the 20-minute climax
(target 238 CR) holds a stable ~112–114 enemies at **0.47 ms/frame**; pushing the target 2× past the
cap clamps at exactly 250 enemies at 0.76 ms.

The enemy *selection* logic (tag weighting, biome filtering, EASY/HARD counter-spawning) is
orthogonal and untouched — it decides *which* enemies fill the slots, not *how many*.

---

## 2. Object pooling + concurrent caps

**Files:** `systems/global/projectile_pool.gd`, `systems/global/damage_number_pool.gd`

Two independent mechanisms, both required:

**Pool size (`MAX_POOL_SIZE = 2000`)** — the reservoir of reusable nodes. When it was too small
(100 projectiles / 200 damage numbers), a burst would overflow the pool → fall back to
instantiate/`queue_free` → the deferred-free queue piled up → the frame slowed → more pile-up. A
**self-reinforcing churn runaway** that bit slower hardware first (this was the original "20 fps at
60 enemies on the Mac" bug — *not* enemy movement). Raising the ceiling took 200 enemies from
**101 ms → 2.6 ms**.

**Concurrent caps** — a hard limit on how many of a thing can be *live at once*:
- `MAX_ACTIVE_SPARKS = 200`, `MAX_ACTIVE_GENERIC = 300` (projectiles), `MAX_ACTIVE = 150` (damage numbers).
- `get_*()` returns `null` when over the cap; **every caller must handle null** (they do — grep for
  `== null`). This is deliberate back-pressure: dropping a projectile/number is invisible; a stalled
  frame is not.

### What NOT to do

- Don't raise a concurrent cap because "more looks cooler" without a benchmark on target hardware.
  `MAX_ACTIVE_SPARKS` in particular sits just below a hard broadphase cliff (see §5).
- Don't remove the null-handling at call sites — that's what makes the cap safe.
- Pool size and concurrent cap are different levers: the pool prevents *churn*, the concurrent cap
  prevents *broadphase/render blowup*. You need both.

---

## 3. Enemies stay cheap per-entity

**Files:** `actors/enemies/enemy.tscn`, `actors/enemies/enemy.gd`, `actors/enemies/behaviors/ai/`

- **`collision_mask = 1`** — enemies collide with the player body only, **not each other**. Dense
  enemy-enemy collision is O(n²) broadphase pairs for no gameplay value.
- **Proximity `Area2D` is opt-in** (`enemy_ai.gd` disables it by default; `enable_ally_detection()`
  turns it on only for AIs that need it). An always-on detector per enemy is another O(n²) source.
- Off-screen enemies **pause their `AnimatedSprite2D`** (`speed_scale = 0`) and skip sprite-orientation
  work — see `_on_screen_exited()` / `_physics_process`.

**Do not** re-enable enemy-enemy collision or make the proximity detector always-on without
understanding the broadphase cost. Movement itself (`move_and_slide`) was investigated as the cliff
and ruled out — the cost is the *bodies existing in the broadphase*, not the movement call.

---

## 4. Spatial hash for local queries

**File:** `systems/global/entity_registry.gd`

`EntityRegistry` keeps a spatial hash (`CELL_SIZE = 256`, rebuilt each physics frame) so "find
enemies near X" is O(local density), not O(all enemies). Use `get_enemies_near()` /
`get_candidates_near()` for any proximity/targeting query. Spark bounce targeting
(`spark_projectile._find_next_target`) and chain/bounce weapons rely on it.

**Do not** write new targeting code that iterates every enemy (`get_tree().get_nodes_in_group(...)`
then loops all of them) — that's O(n) per query, O(n²) across all queriers.

---

## 5. Sparks (chain lightning) are Area2D-bound

**Files:** `items/weapons/spark/spark_projectile.gd`, spark handling in `systems/projectiles/projectile.gd`

Each spark is an `Area2D`. Their real cost is the **physics broadphase in a dense cluster**, which
cliffs hard: on the (deliberately over-clustered) `spark_bench`, 150 sparks ≈ 3 ms, 200 ≈ 10 ms,
250 ≈ 35 ms. `MAX_ACTIVE_SPARKS = 200` keeps a full lightning storm on screen while staying below the
cliff. Real play spreads sparks out, so it's cheaper than the bench — the cap is conservative.

**If spark builds ever lag on the target hardware,** the real fix is to take sparks off `Area2D` and
detect hits via the `EntityRegistry` spatial hash instead (the `use_spatial_hits` flag on
`ProjectileStats` is the existing off-Area2D path for generic projectiles — it would need porting to
`SparkProjectile`). Not done yet because the cap makes it unnecessary for now.

---

## 6. Damage numbers: cheap, keep them

**Files:** `ui/damage_number/damage_number.gd`, `systems/global/damage_number_pool.gd`

Damage numbers are **core game feel — do not remove or suppress them for performance.** Measured in
isolation (`dmgnum_bench`, no sparks) they cost **~1 ms per 150**, and the `MAX_ACTIVE = 150` pool cap
is what keeps that bounded under any hit volume. Numbers are shown for spark hits too.

### History / what NOT to repeat

- A cost of "~5.5 ms for damage numbers" was once read off the *spark* benchmark and used to justify
  suppressing spark damage numbers. That was **noise misattribution** — the spark bench's broadphase
  swings 5–15 ms run-to-run. The isolated bench proved numbers are cheap. Suppression was reverted.
- **Per-target aggregation** (merge rapid hits into one rising number) was tried and is **worse for
  this game**: chain lightning hits *many* enemies, so aggregation doesn't reduce the count — it just
  makes each number a bigger multi-digit total at larger scale = more glyphs to render. It only helps
  when *few* targets are hit repeatedly.
- A scale-instead-of-font-size rewrite measured within noise of the original *and* looked slightly
  blurrier — reverted. The original implementation is fine.

---

## Appendix: things tried that did NOT work

Recorded so they aren't re-attempted:

- **Daggers via `use_spatial_hits`** (off-Area2D) — regressed the realistic range; flag left OFF.
- **Damage-number aggregation** — worse for the horde/spark case (see §6).
- **Manual enemy movement** (replacing `move_and_slide`) — no improvement; the broadphase tracks
  dense bodies regardless of the movement call.
- **Chasing the 400+ cliff with micro-optimizations** — it's architectural; the population model (§1)
  is the answer, not more per-object tuning.
