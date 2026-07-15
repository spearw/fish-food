# Workflow — ballparking a new item

Follow this when adding **any** weapon, artifact or upgrade. It exists because there is no formula to
look the answer up in (see [methods.md](methods.md)); the state of the art is to **measure**.

The goal is a **ballpark**, not a verdict. Per README law 3, being wrong is structural — ship the
ballpark, then let play tell you. Per README law 1, if the bench and the feel disagree, **the feel
wins**.

---

## Step 0 — Classify it first: transitive or intransitive?

This decides whether the rest of the workflow even applies.

- **Transitive** (a ladder — strictly better/worse): rarity tiers of one weapon, a straight stat
  upgrade. → **Price it.** Continue to step 1.
- **Intransitive** (a real choice — no dominant option): this weapon vs that weapon, weapon vs
  artifact. → **Don't price it.** It's balanced by counter-play (`WeaponTags.COUNTER_MATRIX`,
  `BuildAnalyzer`, `CurrentRun.counter_mode`), not by matching a number. Ask "what beats it and what
  does it beat?", not "is its DPS right?".
  **Answer that with the archetype profile (step 2b) — it measures exactly this.**

Conflating these is the named cause of balance confusion. Most new *weapons* are intransitive against
each other and transitive against themselves — so a new weapon needs a **sane ballpark** (steps 1–3)
and a **counter-play answer** (step 0), not one number.

## Step 1 — Ballpark it on paper (Schreiber's isolation method)

Cheap, fast, and good enough to start. **Do not skip to the bench** — you want a prediction to falsify.

1. Pick an existing item you already believe is fair.
2. Find one that differs in **exactly one** attribute.
3. Set cost = benefit, subtract to isolate the price of that attribute.
4. Chain it: build up prices for pierce, DoT, area, projectile count.
5. Where isolation fails: *"educated guess, then trial and error"* — his words, not a cop-out.

Then plug the new item in and see how far off the curve it sits. **That number is a hypothesis.**

## Step 2 — Bench it

```bash
# Raw damage output. Low variance. Comparable. Nothing can be wasted, so this is a CEILING.
Godot_v4.4.1-stable_win64_console.exe --headless --path . res://balance_bench.tscn -- \
    --weapon=res://systems/upgrades/weapons/fire/fireball_staff/fireball_staff_unlock.tres \
    --rarity=0 --copies=1 --enemies=40 --secs=20 --immortal=1

# Real kills against the live population model. Captures overkill waste and AoE self-thinning --
# the costs no published formula covers. Noisier; run longer.
    ... --immortal=0 --secs=40
```

`--rarity=` 0=COMMON 1=RARE 2=EPIC 3=LEGENDARY 4=MYTHIC.

### Step 2b — Profile it across enemy archetypes (the important one)

A single DPS number is the *transitive* view. **A weapon's ratios across archetypes are the
*intransitive* view — what it beats and what beats it.** That's the shape
`WeaponTags.COUNTER_MATRIX` encodes from hand-authored guesses, and it's what the director uses to
counter a build. Measuring it closes the loop: **the profile is counter-matrix data.**

It also plays to the bench's strength. Cross-*weapon* DPS is shaky (the fixed ring flatters range);
a weapon's own ratios against itself across archetypes are **same-weapon comparisons**, which is
exactly what this bench is reliable for.

```bash
# One archetype per process (in-process teardown leaves dangling refs). Divide by "standard".
for a in standard swarm armored fast tank; do
  Godot_..._console.exe --headless --path . res://balance_bench.tscn -- \
      --weapon=<unlock.tres> --archetype=$a --secs=20
done
```

### Use the SYNTHETIC dummies for attribution

`bench_dummies/` holds clones of one base (`dummy_baseline.tres` = fish) with **exactly one stat
changed** each. That's the only way a ratio means anything.

| key | varies | use |
|---|---|---|
| `baseline` | — (the control) | normalise everything to this |
| `armor10` / `armor25` | `armor` only | the armor axis, two points |
| `fast` / `slow` | `move_speed` only | the speed axis *(broken — see below)* |
| `tanky` | `max_health` only | mortal mode; **doubles as the null test in immortal** |

**Why not real enemies: they're confounded by construction.** fish is HORDE at 90 speed, comb_jelly is
RANGED+ARMORED at 40, and garden_eel is a RANGED **skirmisher** whose behavior parks it despite a 250
speed stat. The first version of this table was built from stats without reading the AI, and every
label was wrong — `standard` was actually a HORDE enemy. The `real_*` keys still exist for sanity
checks (they're what the player faces, and what COUNTER_MATRIX is keyed on) but **never attribute a
`real_*` ratio to a cause.**

### How armor actually works — read this before interpreting any armor number

```gdscript
# DamageUtils.apply_armor
effective_armor = armor * (1.0 - clampf(armor_pen, 0.0, 1.0))
damage_taken    = max(0, int(damage - effective_armor))
```

**Flat subtraction, uncapped.** But three things that are easy to get wrong, and that I got wrong:

1. **DoT has 100% armor penetration — it ignores armor completely.** `DotStatusEffect._do_damage_tick`
   calls `take_damage(damage_per_tick * mult, 1, false)` — that `1` is `armor_pen = 1.0`, and the
   comment says so: *"100% armor pen, no chance to crit."*
   **So DoT is the ANSWER to armor, not countered by it.** The intuition that many-small-hits builds
   get hard-countered by flat armor is **wrong here** — it's true for direct hits, and false for the
   entire DoT half of the game.
2. **Size multiplies armor.** `SIZE_MULTIPLIERS[LARGE].armor_mult = 1.5`. The dummies are
   `size_tags = [3]` (LARGE), so **`armor10` actually fields 15 and `armor25` fields 37.5.**
   The names are the authored stat, not the fielded one.
3. **Crits are rolled BEFORE armor** (`roll_crit` then `apply_armor`), so a crit can punch through an
   armor value that fully absorbs a normal hit.

### Measured: armor (Jul 2026, fireball_staff, 10s, `--motion=frozen`)

| dummy | authored | **fielded** | dps | vs baseline |
|---|---|---|---|---|
| `baseline` | 0 | 0 | 26.7 | — |
| `armor10` | 10 | **15** | 20.0 | 0.75× |
| `armor25` | 25 | **37.5** | 9.8 | 0.37× |

**This is not the armor-counter number it looks like.** The staff's projectile does 25 damage, so at
37.5 fielded armor the direct hit is **fully absorbed** — the surviving 0.37× is the burn getting
through untouched (plus the odd crit). So the reading is really **a decomposition: ~37% of this
weapon's output is armor-immune DoT.**

That's genuinely useful — arguably more useful than the number I was trying to get — but it is **not**
"how much armor counters this weapon", and it does **not** validate `COUNTER_MATRIX`'s
`AOE vs ARMORED = 0.7`. That earlier claim is withdrawn.

### The armor model — predictive, and verified

Because armor is **flat**, a weapon's armor profile is decided by exactly three things:

1. **Damage per HIT** (not per second). Flat subtraction is brutal to small hits and shrugs off big
   ones. A 10-damage dagger into 15 armor does **zero** — not "reduced", *zero*.
2. **`armor_penetration`** on that damage source (`effective_armor = armor × (1 − pen)`).
3. **What fraction of output is DoT**, which bypasses armor entirely.

**Measured (Jul 2026, 10s, `--motion=frozen`, dummies field 15 / 37.5 armor after the LARGE 1.5×):**

| weapon | dmg/hit | pen | DoT | baseline | armor10 (15) | armor25 (37.5) |
|---|---|---|---|---|---|---|
| dagger | 10 | 0 | no | 7.0 | **0.0** | **0.0** |
| chain_lightning | 12 | 0 | no | 21.0 | **0.0** | **0.0** |
| storm_staff | 20 | 0 | no | 11.4 | 1.5 | **0.0** |
| flamethrower | 1 | 0.5 | **yes** | 8.9 | **5.1** | **5.1** |
| fireball_staff | 25 (boom) | **0.5** | yes | 26.7 | 20.2 | 11.4 |

**The model predicted every row.** dagger 10−15 → 0. chain_lightning 12−15 → 0. storm_staff 20−15 → 5
(a sliver), then 20−37.5 → 0. Fireball survives on its explosion's 50% pen. And the flamethrower is
**flat across armor10 and armor25 — identical to the decimal** — because its damage is essentially all
DoT and armor cannot touch it.

**So: DoT counters armor. AoE does not** — AoE spreads damage thin, and thin damage is what flat armor
eats. That's a real, shipped intransitivity, and it's the good kind: it's legible, it's a build
decision, and the counter is discoverable.

> ### ✅ DECIDED (Jul 2026): the wall stays — the system routes around it
>
> The formula is **untouched, deliberately**: hard counters staying hard is part of what makes the game
> feel unique, and in HARD counter mode being walled is the player's own drafting mistake. Three outs
> already exist without homogenizing decks: **DoT** (fire — ignores armor), **pen** (melee — baked in),
> and **tiers** (universal — per-hit rarity scaling means merge depth climbs over any wall). What
> changed instead:
>
> 1. **The director caps the walled share of the live field.** `EncounterDirector.max_walled_share`
>    (default **0.4**, design band 0.35–0.5): the share of live enemies the current build *literally
>    cannot damage* — no DoT, every hit zeroed after pen, judged via `Weapon.get_damage_sources()`
>    walking the full nested-stats tree — never exceeds the cap. Walls still spawn (pressure, flavor,
>    a reason to tier up); the majority of the field stays interactive. If *everything* available is
>    a wall, spawning proceeds anyway — a starved wave is worse than a walled one.
>    **The cap self-disables** the moment the build gains any armor answer (a DoT source, enough pen,
>    a chip artifact): nothing tests as walled, so it never triggers. Draft the answer, the training
>    wheels fall off, the director gets its full counter budget back.
> 2. **Armor-interaction mechanics are ARTIFACT design space, never formula changes.** Planned content:
>    an **armor-BREAK artifact** (your hits shred armor — turns fast weapons into can-openers) and a
>    **CHIP-floor artifact** (your hits always deal ≥X% of raw through armor — the enabler that makes a
>    million-hits lightning build *work* into heavy armor). Player-side verbs only: no artifact ever
>    changes the global rule, so `max(0, dmg − armor×(1−pen))` stays legible forever.
> 3. Still open (parked): blocked-hit feedback (a visible clink, so a wall reads as a rule rather than
>    a bug) and tuning early-biome armor bands so the first armored enemy teaches the check (~5
>    authored armor) rather than enforcing a Rare-tier check at Common tier.
>
> Watch-out, recorded for honesty: the walled test treats **exactly-zero** as walled but **1 damage per
> hit** as answered. A build chipping 1s into 200 HP is a wall in practice. If playtests surface that,
> the fix is a threshold ("walled unless some hit clears X% of the hit") — one line in
> `_armor_walls_build`.

### The null test — always run it first

**`tanky` vs `baseline` in immortal mode must read equal**: HP is overwritten to a huge pool, and
nothing else differs. Whatever gap you see IS the noise floor for that config.

Currently **1.03× (~3%)**. Discard any ratio inside that.

### Motion: the field orbits (`--motion=orbit`, default)

Each enemy sweeps around the player at **its own `move_speed`**, on a fixed timestep.

**Why not frozen:** a frozen dummy can't miss. Projectile speed, travel time and homing are real
contributors to damage, and every one of them is free against a stationary target. Freezing also made
`fast` identical to `standard` — a whole axis silently unmeasurable.

**Why orbit and not "let them chase":** a swarm collapsing onto the player rewrites the geometry
mid-window, which was the original ~2.5× swing. Orbiting keeps the aggregate geometry stationary while
restoring motion. Same trick SimulationCraft uses — scripted movement, not a static dummy.

**This is what made the bench deterministic.** Run-to-run is now **0%** (30.6 / 30.6 / 30.6, three
runs). The old ~20% residual was the "freeze" being `call_deferred`, so enemies drifted for a variable
number of frames before stopping. Driving positions explicitly removed it.

`--motion=frozen` still exists for isolating (it removes motion entirely).

## ⚠ Known limitations

### The speed axis is BROKEN. Don't use it.

Measured with the single-axis dummies (`--motion=orbit`, so `move_speed` is the only difference):

| dummy | dps | vs baseline |
|---|---|---|
| `baseline` (90 speed) | 30.6 | — |
| `slow` (30 speed) | 35.8 | 1.17× |
| `fast` (250 speed) | 34.4 | 1.12× |

**Non-monotonic** — slower *and* faster both take more damage than normal. That's not a weak signal,
it's an incoherent one, and it's the model's fault: orbiting is *tangential*, so enemies sweep across
the projectile stream instead of approaching down it. A density sweep acquits density as the cause
(the artifact is *stronger* when sparse: 1.55× at `--enemies=5` vs 1.24× at 40).

### The real AI doesn't run — the big one

**The bench overrides enemy AI and imposes motion. So behavior — the thing COUNTER_MATRIX is actually
keyed on — is not simulated at all.** This is why the speed axis fails: `move_speed` is a stat that the
*behavior* decides how to spend, and a skirmisher parks itself regardless of having 250 speed.

The fix is **chase-and-recycle**: let each enemy's real AI run, and respawn anything that reaches the
player back at the outer ring — a treadmill. Real approach vectors and real behaviors, with the
aggregate geometry still stationary. **Deferred, deliberately** (Jul 2026): the armor axis is
measurable without it, and it's the axis we need first.

**Until then: the bench measures stats, not behavior.**

### Other standing limits

- **Immortal mode erases HP**, so `tanky` can't show kill throughput — that needs mortal mode, which
  reintroduces the AI problem above.
- **Hold density constant.** Absolute DPS went 8.4 → 31.6 (nearly 4×) from `--enemies=5` to `40`.
  `--enemies` is a first-class variable: never compare numbers taken at different field sizes.
- **The fixed ring flatters range and punishes melee**, so cross-weapon absolutes are a ballpark.
  Same-weapon ratios are what this is for.

**Headless is correct here** — we're measuring damage, not frame time. (The opposite of the perf
benches in [`../performance/benchmarking.md`](../performance/benchmarking.md), which *must* run
windowed.)

**What each mode is for:**

| Question | Mode | Metric |
|---|---|---|
| Is this weapon in the right ballpark vs a reference? | immortal | `dps` |
| Does its rarity curve actually scale its damage? | immortal | `dps` across `--rarity=0,1,2` |
| **What's its real two-copy multiplier?** | **mortal** | `kills_per_sec` at `--copies=1` vs `2` |
| Does its AoE thin its own cluster? | mortal vs immortal | the gap between them |

## Step 3 — Set the rarity curve from the measured two-copy multiplier

`Weapon.rarity_scaling` is `@export`ed **per weapon** for a reason (README law 5).

The ratio between tiers is the knob:

- **Two copies in two slots deal roughly 2× damage**, so a tier ratio of exactly **2.0 makes merging
  free** (same damage, one slot back). Under 2.0 it's a **trade** — damage for a slot. Over 2.0 it's a
  no-brainer.
- Default is **1.8× geometric**: merging always costs ~10% and always returns a slot.

> **⚠ The 2.0 baseline is an ASSUMPTION, not a measurement.** Thornton's critique of point systems
> names exactly this failure — *"a unit of 20 ≠ 2 units of 10."* An AoE weapon's two copies overlap and
> overkill, so its real multiplier is **below** 2.0 — which means its break-even tier ratio is below
> 2.0 too. **Measure it in mortal mode and set the curve against the measured number, not 2.0.**

## Step 4 — Play it. Feel is law.

The bench cannot tell you whether merging feels like a reward or whether the build delivers the
end-of-run power rush the genre is built on. **Nothing here overrides that.** If it's 10% behind on
the bench and feels incredible, it's right.

---

## Honest limits of the bench (read before quoting a number)

**Status: v1. Useful for direction; not yet precise.**

- **Run-to-run variance is ~20% at `--secs=10`.** The field is seeded and frozen, which killed the
  original ~2.5× swing, but it is **not** fully deterministic yet. **Do not read a <20% difference as
  real.** Use longer windows and repeat runs until this is fixed.
- **Immortal mode is a ceiling, not throughput.** Nothing can be wasted, so two copies trivially
  measure ~2.0× there. **The two-copy multiplier is only meaningful in mortal mode.**
- **The dummy field is a fixed ring (80–260px).** This **flatters range and punishes melee**, so
  cross-weapon numbers are a ballpark only. Same-weapon comparisons (rarity, copies) are what it's for.
- **Known-good use:** comparing one weapon against itself. **Known-shaky:** comparing different weapon
  *shapes* against each other — which is also the intransitive case where you shouldn't be pricing
  anyway (step 0).
- Two `"Can't change this state while flushing queries"` errors per run are cosmetic and don't affect
  the numbers.

## Traps (these have already bitten us)

- **A unit test that checks the field you changed proves nothing about damage output.**
  `weapon_rarity_verify` passed while the fireball staff's damage barely moved — because that weapon
  keeps its damage in a **multistage sub-resource** and a separate `wall_of_fire_stats`, and the
  scaling only touched the root. **The bench caught what the unit test structurally couldn't.** If an
  item's numbers live in sub-resources, verify the *output*, not the field.
- **Don't assert on a random draw.** Assert on the offerable set / the measured aggregate.
- **Seed immediately before the thing you're measuring**, not at startup — booting the world consumes
  random numbers over a variable number of frames.
- **Time in physics frames, not wall-clock.** Headless `dt` is whatever the machine felt like.
- **Watch for confounders.** A previous benchmark mis-attributed 5.5ms to damage numbers; the real
  cause was 944 XP orbs piling up. Census the scene before believing a number.
