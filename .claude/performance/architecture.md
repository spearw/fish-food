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
- `max_enemy_budget_share` (0.15) — no single top-up enemy may cost more than 15% of the current
  target CR. **Pace is felt in bodies, not CR**: without this, two fat enemies could eat the whole
  early budget, overshoot it, and freeze the stream (measured: run-start population of 2). The
  allowance grows with the target, so heavies re-enter the stream naturally late-game. If the share
  prices out the entire pool (tiny early targets), the cheapest tier is the fallback.
- `min_active_enemies` (6) — a count FLOOR: when the budget is spent but fewer than 6 enemies are
  alive, the pulse tops up with the cheapest tier anyway (slight CR overshoot; perf caps still
  absolute). This is the half of Vampire Survivors' model the setpoint didn't take — minimum wave
  counts. Without it, a player kiting one tough-but-slow enemy freezes the game quiet: no kills, no
  freed budget, no spawns, no pace. Also the guard against **walled-budget sequestration** (an
  armor-walled enemy the build can't kill parks its CR forever — see the walled-share cap below);
  if that ever bites harder, the escalation lever is aging an enemy's CR contribution down over
  time, which is designed but deliberately not built.

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

## 5. Sparks (chain lightning) — off the broadphase, not hard-clipped

**Files:** `items/weapons/spark/spark_projectile.gd`, spark handling in `systems/projectiles/projectile.gd`

**Principle: performance must not clip a build.** A spark build's power scales with spark count, so a
low hard cap (it was 200) directly limited that build — performance leaking into gameplay. Fixed by
taking sparks **off the physics broadphase**: `SparkProjectile.use_spatial_hits = true` (default)
disables the `Area2D` and detects hits via the `EntityRegistry` spatial hash in `_process` instead.

Consequences:
- **`max_active_sparks` (in `projectile_pool.gd`, 800) is now a SAFETY backstop, not a gameplay clip.**
  Sparks that land hits bounce out and die fast, so they **self-limit** by lifespan — in a dense field
  they settle around ~400–465 concurrent regardless of the cap. The cap only catches a runaway.
- **No broadphase collapse.** On-broadphase (Area2D) sparks degrade badly at high counts — at target
  500 they collapsed (couldn't sustain, ~33 ms). Off-broadphase they scale smoothly (~400 sparks
  ≈ 20 ms, stable).
- The spatial check also **fixes tunneling** — fast sparks no longer phase through enemies between
  physics frames — so hits are more reliable. This is a mild effective buff to spark builds; it's a
  gameplay change, so playtest the feel. To revert: `SparkProjectile.use_spatial_hits = false`.

### Honest caveat — this does NOT make high spark counts cheap

Measured fairly (matched hit counts), taking sparks off Area2D is only **~20 % faster** — because the
dominant cost at high counts is **the sheer work of thousands of bounces/hits/retargets in a dense
field**, not the broadphase. ~400 concurrent sparks is ~20 ms on the dev PC either way. So removing the
clip trades a *hard wall at 200* for a *smooth slowdown as you scale* — better feel, but not free
performance. (The `spark_bench` is also pessimistic: it uses immortal enemies, so sparks bounce
forever; in real play sparks kill enemies and thin their own target field.)

**If spark builds need to scale further/cheaper**, the levers are per-hit cost, not the broadphase:
avoid the health-bar redraw on every spark tick, cheaper bounce retargeting, and batched rendering
(`MultiMesh` with a glyph/sprite atlas) for the sprites. That's a larger project — do it only if the
Mac says spark builds actually lag.

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

## 7. Taking projectiles/zones off the broadphase is NOT a universal win

It's tempting to conclude from the spark change (§5) that *everything* should leave the physics
broadphase. It shouldn't. Godot's C++ Area2D broadphase is very efficient at low-to-moderate counts; a
GDScript spatial-hash check per object only wins when there are MANY objects in a DENSE cluster.

Measured evidence from this codebase:
- **Sparks** — high count, dense, self-cascading → off-broadphase wins (§5). Done.
- **Daggers / generic projectiles** — moderate count, spread out. Off-broadphase (the `use_spatial_hits`
  flag on `ProjectileStats`) **regressed** them: the per-projectile GDScript query cost more than the
  C++ broadphase at those counts. The flag exists but is deliberately **OFF** for daggers.
- **Damage zones** (fire pools / poison clouds / auras — `persistent_damage_effect.gd`) — only a handful
  are live at once, and they already cache their overlap set via `body_entered`/`body_exited` (no
  physics query per tick). Their broadphase cost is just infrequent enter/exit events. Taking them off
  would *replace* those cheap events with a per-tick spatial query over a large area — a likely loss.
  They **stay** on Area2D.

Rule: off-broadphase is a tool for the high-count, dense, cheap-per-hit case. For everything else,
measure before converting — and the default answer is "leave it on Area2D."

**Choosing the mode is a flag, not a reimplementation.** The hit-detection logic is not copied per
projectile:
- **Standard projectiles** `extends Projectile` and set **`use_spatial_hits`** on their
  `ProjectileStats` `.tres` (the flag is inherited by every `ProjectileStats` subclass). The
  Area2D-vs-spatial branching lives *once* in `Projectile` (`_initialize` / `_process` /
  `_check_spatial_hits`). Trail, exploding, multi-stage, and explosion projectiles all inherit it —
  adding another is a new `.tres` + `extends Projectile`, no hit code.
- **Special projectiles** that genuinely can't extend `Projectile` (e.g. `SparkProjectile`, whose
  bounce-by-retarget mechanic is fundamentally different) still call the **same shared scan**,
  `EntityRegistry.get_enemies_within(pos, radius)` — the one place the spatial query lives. They only
  write their own *hit handling* (pierce-through vs bounce), which is genuinely type-specific.

So the spatial scan exists in exactly one place, the mode is a data flag for the common case, and a new
projectile never re-derives this logic.

## 8. Status effects & damage zones (fire / poison / DOT / slow)

**Files:** `systems/status_effects/*`, `items/effects/persistent_damage_effect.gd`

Every enemy carries a `StatusEffectManager`, so anything per-manager runs hundreds of times. What keeps
it cheap:
- **Idle managers don't process.** The manager starts `set_physics_process(false)` and only enables
  per-frame processing while a `needs_processing` status (a DOT) is active, going idle again when none
  remain. Duration expiry uses one-shot `Timer`s, so a slow-only enemy never takes a frame. Do **not**
  add unconditional per-frame work to the manager.
- **DOT ticks use a float accumulator** (`dot_status_effect.gd`), not a Timer-per-tick. Keep it that way.
- **Damage zones cache overlap** and resolve each body's `StatusEffectManager` **once on entry**, not
  via `get_node("StatusEffectManager")` every tick per overlapping body.
- **Targeting uses bounded spatial queries** (`EntityRegistry.get_candidates_near`), never a full enemy
  scan + sort. (The melee spark path was fixed to match the projectile path.)

## 9. Optional cosmetics: GameSettings

**File:** `systems/global/game_settings.gd` (autoload)

Because gameplay cost is bounded by design, the remaining lever for a weak machine is *cosmetic*.
`GameSettings` exposes performance toggles (`show_damage_numbers`, `show_health_bars`,
`show_status_vfx`), all default ON, checked where each visual is created.
`GameSettings.set_performance_mode(true)` flips them as a preset (persisted to `user://settings.cfg`).
Health bars are a per-enemy `TextureProgressBar` and status VFX a per-enemy `AnimatedSprite2D`, so
hiding them scales the saving with enemy count. A settings UI to expose these to players is the next step.

## Appendix: things tried that did NOT work

Recorded so they aren't re-attempted:

- **Daggers via `use_spatial_hits`** (off-Area2D) — regressed the realistic range; flag left OFF.
- **Damage-number aggregation** — worse for the horde/spark case (see §6).
- **Manual enemy movement** (replacing `move_and_slide`) — no improvement; the broadphase tracks
  dense bodies regardless of the movement call.
- **Chasing the 400+ cliff with micro-optimizations** — it's architectural; the population model (§1)
  is the answer, not more per-object tuning.
