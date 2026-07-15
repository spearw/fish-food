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
