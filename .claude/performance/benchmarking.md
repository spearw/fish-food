# Benchmarking

Performance claims in this repo are backed by measurement. This is how.

## The harness

Self-contained benchmark scenes in the repo root. Each boots a real run, sets up a controlled load,
measures **wall-clock frame time** over a window, prints one result line, and quits. They immortalize
the player and disable the level-up pause so the run doesn't end or stall mid-measurement.

| Scene | Measures | Key args | Output line |
|---|---|---|---|
| `nat_bench.tscn` | The **population model**: does the live enemy count self-bound at the target/cap? | `--sim=<seconds>` (force difficulty time), `--scale=<x>` (override `target_threat_scale`) | `NATBENCH` |
| `full_bench.tscn` | Forced-count **clumped worst case** (enemies stacked on the player) | `--count=<n>` | `FULLBENCH` |
| `spark_bench.tscn` | **Spark** runtime: a sustained live spark population bouncing through an enemy field | `--count=<enemies>`, `--sparks=<live>`, `--bounces=<n>`, `--nodmg=<0\|1>` | `SPARKBENCH` |
| `dmgnum_bench.tscn` | **Damage numbers** in isolation (no sparks): N hits/frame on an immortal field | `--count=<enemies>`, `--hits=<per frame>`, `--agg=<0\|1>` | `DMGBENCH` |
| `perf_bench.tscn` | Headless **movement-only** microbench | — | (headless) |

### Running one

```
<godot-console> --path <repo-root> res://<bench>.tscn -- <args>
```

- On Windows use the **`_console.exe`** Godot variant so `print()` reaches stdout
  (e.g. `Godot_v4.4.1-stable_win64_console.exe`). On macOS, the app's binary.
- Run **windowed — NOT `--headless`** — for anything rendering-dependent (all but `perf_bench`), so
  rendering is actually measured.
- Grep stdout for the output tag. Example:

```
Godot_v4.4.1-stable_win64_console.exe --path C:/dev/fish-food res://spark_bench.tscn -- --count=150 --sparks=200
# -> SPARKBENCH enemies=150 spark_target=200 spark_peak=200 ... frame_ms=9.7 objects=728
```

Leaked-RID `ERROR:` lines at exit are harmless (force-quit mid-frame), not gameplay errors.

## Methodology

- **The dev PC is ~60–80× faster than the target Mac.** Absolute FPS here means nothing for the Mac.
  Compare **relative frame time**, **object/draw counts**, and **whether a runaway is present** — those
  transfer across hardware; a raw FPS number does not.
- **Measure wall-clock frame time**, not the engine's script/physics monitors. Use
  `Time.get_ticks_usec()` deltas with **vsync disabled** (`DisplayServer.VSYNC_DISABLED`) and
  `Engine.max_fps = 0`. The `Performance.TIME_PROCESS` / `TIME_PHYSICS_PROCESS` monitors gave
  physically impossible values here (script 92 ms + physics 187 ms but frame 18 ms) — **do not trust
  them.**
- For per-physics-tick cost, set `Engine.max_physics_steps_per_frame = 1` so a slow frame isn't
  amplified by sub-step catch-up.
- A single **result line + object census** beats eyeballing the window.

## Traps that produce misleading numbers

Every one of these bit us at least once:

- **Spark-bench noise.** The dense-Area2D broadphase makes `spark_bench` swing **5–15 ms run-to-run**
  for the *same* config. It is far too noisy to measure any sub-cost (e.g. damage numbers). For those,
  use a dedicated isolated bench (`dmgnum_bench`). Take medians of several runs for spark numbers.
- **XP-orb / loot pile-up.** Fast kills drop XP orbs; a *stationary* bench player never magnets them,
  so they accumulate into the hundreds (once 944 of them) and tank the frame — a benchmark artifact,
  not the thing under test. Either make enemies immortal, or account for the orbs in the census.
- **Immortal-enemy damage-number flood.** Immortalizing enemies to stop loot means sparks/hits never
  stop → damage numbers pin at their cap. Fine if you *want* to measure that; misleading if you don't.
- **The level-up pause.** A real run hands out a level-up that calls `get_tree().paused = true`. Benches
  disconnect all `leveled_up` handlers; if you write a new bench, do the same or it hangs.
- **Over-clustering.** `spark_bench` spawns every spark onto the enemy ring — denser than real play, so
  it's a *pessimistic* upper bound. Good for finding cliffs, not for "typical" numbers.

## The rule

**Isolate before attributing.** If a change is supposed to speed up system X, prove it on a bench that
exercises *only* X. A cost read off a benchmark where something noisier dominates is a guess, not a
measurement — and we shipped a wrong "fix" once by doing exactly that.
