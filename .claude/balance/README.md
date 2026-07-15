# Balance — first-class concern

How we decide what a weapon, artifact or upgrade is *worth*. Companion to
[`.claude/performance/`](../performance/README.md): that folder is about the frame staying smooth,
this one is about the numbers being right — and about knowing what "right" even means here.

This folder exists because the research (see [methods.md](methods.md)) turned up a genuinely
surprising result: **there is almost no established math for this.** One real framework exists, it's
a process rather than an equation, and every practitioner who has one says the same thing — the math
is a first draft, playtesting settles it. That's not an excuse to guess. It's a mandate to *measure*,
which is what [workflow.md](workflow.md) is for.

## The laws

Ranked. When they conflict, the higher one wins.

### 1. Feel is law

**Ultimately feel is the most important, so that is law.** Bullet heavens are built on the rush of
feeling overpowered at the end. A build that is 10% behind on a spreadsheet but feels incredible is
*correct*, and a build that is perfectly curved and feels like nothing is *wrong*.

This isn't a soft principle, it's the field's own conclusion:

- **Luca Galante** (Vampire Survivors) "didn't have a vision" for balance and "doesn't care for game
  balance that much" — because it's single-player, everything should feel viable and fun even if
  "completely broken." *The game that defined this genre was not balanced by any formula.*
- **Sid Meier**: *"2/1 is not equal to 20/10"* — Civ Revolution fudges odds under the hood because
  players misjudge them. Math lost to perception on purpose.
- **Josh Noh** (Overwatch): *"Perception of balance can be more impactful on the state of a game than
  the 'true' numerical balance."* And: *"A perfectly balanced game doesn't mean it will be fun.
  Design something fun and then balance it."*

**We are single-player.** The bar is *everything feels viable*, not *everything is equal*. Symmetry
is not a goal we owe anyone.

### 2. Simulate, don't derive

The most rigorous DPS tool in the industry (**SimulationCraft**) **abandons closed-form equations and
runs Monte Carlo simulation instead.** That is the state of the art for exactly the question we keep
asking — how do you compare a DoT weapon to an AoE weapon to a burst weapon.

We already have the harness. Numbers no published formula covers — the real two-copy multiplier, AoE
self-thinning, DoT overkill waste — are things to **measure**, not derive. See [workflow.md](workflow.md).

### 3. Being wrong is structural, not a failure

**Rosewater**: *"if nothing ever gets banned, we aren't doing our job properly. We're supposed to come
up to the line, which occasionally means we step over it."* Hearthstone's **Iksar** prefers to *"push
and miss on the high power side"* over playing mathematically safe.

Ship the ballpark, measure it, tune it. **Do not try to be right first.** An item that's never
overtuned is an item that was never exciting.

### 4. Keep transitive and intransitive apart

Schreiber's distinction, and the one place a wrong instinct will quietly wreck us:

- **Transitive** — strictly better/worse along one ladder. **Our rarity tiers.** Cost curves apply
  here. Price it.
- **Intransitive** — rock-paper-scissors, no dominant option. **Our weapon-vs-artifact-vs-weapon slot
  choice.** Balanced by counter-play, *not* by pricing.

**Do not try to price a Fire Staff against Goliath.** That's a counter-play problem and we already
have the machinery for it (`WeaponTags.COUNTER_MATRIX`, `BuildAnalyzer`, `CurrentRun.counter_mode`).
Conflating the two is the named cause of balance confusion.

### 5. Per-item curves, not one global curve

Brotato scales tiers **per weapon** on purpose — Fist doubles every tier (8/16/32/64), Wrench crawls
(12/16/20/24) — and its pierce falloff is a 50% default with per-weapon exceptions. That variation is
what makes merging worth chasing on some weapons and not on others. **A uniform curve flattens the
texture away.** This is why `Weapon.rarity_scaling` is `@export`ed per weapon.

### 6. Additive within a layer, multiplicative across layers

Not additive *versus* multiplicative — **both**, in two layers. Every relevant shipped game converges
on this shape (Halls of Torment, Vampire Survivors, Path of Exile — see [methods.md](methods.md)).

### 7. Hyperbolic for unbounded probabilities, linear for bounded magnitudes

Risk of Rain 2's rule: `1 − 1/(1 + a·x)` for anything chance-based that would otherwise reach 100%;
plain linear for flat magnitudes. **Applied selectively, not everywhere** — RoR2's Crowbar is
deliberately linear and non-diminishing.

## The docs

- **[methods.md](methods.md)** — what the field actually knows, with sources. Every claim marked
  **FINDING** (what the research says) vs **CONCLUSION** (what we decided). Read this before arguing
  with a law above.
- **[workflow.md](workflow.md)** — **the explicit workflow for ballparking a new item.** Follow it
  when adding any weapon, artifact or upgrade.

## Load-bearing decisions

Changeable — but change them knowingly, and read the rationale first.

- **`Weapon.rarity_scaling`** default `[1.0, 1.8, 3.2, 5.8, 10.5]` (geometric, 1.8×/tier). **The ratio
  vs 2.0 is the knob, not the absolute numbers**: two copies in two slots do ~2× damage, so a tier
  worth exactly 2× makes merging free, and anything under 2× makes it a trade — damage for a slot.
  1.8× = merging always costs ~10% damage and always returns a slot.
  **Caveat: the 2.0 baseline is an assumption, not a measurement** — see the two-copy multiplier in
  [workflow.md](workflow.md). It is probably wrong for AoE weapons, which overlap and overkill.
- **`CurrentRun.max_loadout_slots = 5`** — weapons and artifacts share it. The cap is what makes a
  pick cost something. Rationale in [`docs/deck_and_synergy_design.md`](../../docs/deck_and_synergy_design.md) §3.
- **Slot-cost exemptions** (granted combo synergies, the identity artifact, replacement-when-full).
  Each is individually justified; **the risk is what they sum to** — see the Lutri finding in
  [methods.md](methods.md).
- **Armor stays flat and hard** (`max(0, dmg − armor×(1−pen))`), and a walled build is a legitimate
  HARD-mode outcome — the outs are DoT (ignores armor), pen, and tiers (merge depth raises per-hit
  damage over any wall). The safety is systemic, not mechanical:
  **`EncounterDirector.max_walled_share` (0.4)** caps how much of the live field a build literally
  cannot damage, and self-disables once the build has any answer. Armor-interaction (break bars, chip
  floors) is **artifact content, never a formula change**. Full decision in
  [workflow.md](workflow.md).
