# Deck & Synergy System — Design

**Status:** locked, July 2026 (William + Jeff + Claude). The forward design for Fish Food's
progression: themed **decks** and cross-deck **synergies (combos)**. Builds on the existing engine —
weapons, artifacts, encounter director, armor (see `CLAUDE.md` for the map, `.claude/performance/`
for the perf-critical systems).

---

## 1. Decks (renamed from "packs")

The code currently calls these **packs** (`UpgradePack`). Rename to **decks** — same concept.

- **Core deck** — granted every run, base-stat upgrades only (no weapons), locked on.
- **Themed decks** — organized into slot categories:
  - ~3 weapons
  - ~2 evolution upgrades per weapon (a weapon's evolutions are alternatives — pick one per weapon per run)
  - ~3 deck-mechanic / synergy upgrades (the deck's core mechanic, e.g. fire: ignite chance / DOT damage / duration)
  - ~3 artifacts (gameplay-modifying)
- **Structure is COUNTED, not hard-enforced.** Decks may differ in size; the slot categories are for
  organization + validation/warnings, not a rigid 15-card cap.
- **Every deck has a stable `id`.** This is the anchor synergies key on — non-negotiable, add it in the
  packs→decks rename.

---

## 2. Characters ↔ Decks — identity, and how many decks a run gets

### Characters link to a deck

A character starts with a **linked primary deck** + a **character-exclusive weapon** (and its
evolutions). That link is the whole point of characters: a linked deck gives a character a **verb, not
a stat line** — "the fire mage" means *"I play the ignite game"*, not *"+10% burn"*. It's what makes
each character a different *game* rather than a different number.

**Design principle: lock the verb, free the sentence.** The character locks your PRIMARY (identity);
the player chooses everything after (agency). The failure mode to avoid is identity curdling into a
**straitjacket** — if the fire mage can only ever play fire, agency dies and replay value with it.
Every character must have several viable pairings.

### How many decks per run: **2 normally, 3 rarely. Never 4.** (LOCKED)

A run ends with **two** themed decks (+ core). A **third** is a rare, earned exception.

Why not 3–4 by default:

1. **The combo gate demands depth.** Combos gate on ≥N cards drafted from *both* decks (§4) — a
   deliberate reward for **depth**. Spread picks across 4 decks and you can't hit that gate on any
   pair: you dilute yourself out of your own payoff. Wide decks and the combo system actively fight
   each other; the combo system wins, because it's the more interesting mechanic.
2. **The pick-budget math.** A run is ~20–30 level-ups; decks are ~15 cards. With **2** themed decks
   (~30 cards) those picks can actually *fill* both — weapons, evolutions, enough mechanic-stacking to
   feel the theme, and clear the combo gate. With **4** (~60 cards) the same picks are butter over too
   much bread: you scratch each theme, evolve nothing, combo nothing. **Depth is picks-per-deck**, and
   the budget only funds ~2, maybe 3.
3. **Focus is the fun.** "I'm running fire + lightning and I just unlocked Thermal Shock" is a *build*.
   "A bit of fire, ice, lightning, and poison" is a *soup*. The entire reason to have curated decks +
   combos instead of a flat card pool is to make a run feel like *a specific thing*.

**Why a 3rd is allowed at all:** the secret-boss **second combo** (§4) *requires* it — a 2nd combo
needs a 2nd pair, which needs a 3rd deck (A+B+C → combo A+B *and* B+C). A 3rd deck isn't more soup;
it's the **key to the 2-combo chase**, which is exactly why it must stay rare and hard-earned.

### The escalation ladder (in-run deck acquisition)

Deck acquisition rides the same milestone rhythm as combos, so a run has an arc:

| When | What |
|---|---|
| Start | Character's **primary deck** (+ core). Focused mono-theme early game. |
| Early milestone (~level 5) | **Choose your secondary deck** → the dual-theme build you'll invest in. |
| Level 20 / mini-boss | **Combo unlocks** (enough runway to have hit the ≥N-each gate). |
| Rare, hard-earned (condition TBD) | **3rd deck + 2nd combo** — the "go wide" reward for exceptional runs. |

Each unlock is an **event**, reusing the milestone-reward pattern the combo trigger already
establishes.

### Current state (un-built)

Today characters carry `starting_upgrades` (a starting **weapon**, not a deck), and decks are chosen
**freely** at character-select (up to 3, character-agnostic). So the link, the ladder, and the count
rule are all still to build.

---

## 3. The weapon economy — breadth vs depth

**The problem.** Taking a new weapon is always the best pick, so the level-up screen is a *queue*
("what order do I collect everything in?") rather than a choice.

### Diagnosis (from the code, July 2026)

- **There is no weapon slot cap.** Weapon #5 costs nothing. Nothing is ever foregone — the stat card
  you skip comes back next level-up.
- **Weapons don't level.** A weapon is binary (own it or don't) plus one transformation, so there is no
  "upgrade this weapon" card to *compete* with "get a weapon." §1 deliberately put the depth axis at the
  *theme* level instead ("no weapon-specific upgrade cards").
- **Stat cards are +10/15/20/25%, global, and stack additively** — so they *diminish*: a 5th +10%
  damage card is really worth +6.7%.

**The math.** With N roughly-equal weapons, a new weapon multiplies damage by (N+1)/N — **+1/N**. A
common stat card gives **+10%**. The new weapon wins while N < 10, and only ~7 weapons exist across two
decks. **The crossover is never reached**, and the gap *widens* as additive stat cards decay.

**The numbers are the smaller half.** The real cause is the absence of **exclusion**: with no cap and a
finite pool, every pick is deferrable, so you take the biggest number first — forever.

*(Outlier: Projectile Count grants +0.4 where Damage grants +0.1 — roughly +40% kit-wide as a first
pick, far out of line with its neighbours.)*

### Why Vampire Survivors doesn't have this problem (research, July 2026)

Four mechanisms, all absent here:

1. **Slots are capped** (6 weapons + 6 passives). The marginal weapon costs a slot *for the rest of the
   run*, not just this pick.
2. **A weapon is an investment, not a possession.** Levels buff *different multiplicative axes* (damage
   × amount ÷ cooldown × area/pierce). Each level is flat, but they multiply: a Magic Wand's effective
   output goes ~8.3 → ~120 across levels 1→8 (**~14×**) while its damage alone only triples. Six weapons
   at level 2 don't sum to one weapon at level 8.
3. **Evolution is a threshold with no partial credit** — max level + a paired passive + a chest that
   only drops after 10:00. Payoffs are step functions (Axe→Death Spiral: pierce 7 → ~1000;
   Knife→Thousand Edge: cooldown 1.0s → 0.35s).
4. **XP escalates** (+10/level early, +13 after 20, +16 after 40, plus +600 and +2,400 surcharges at
   levels 20 and 40) — spread thin and nothing crosses the finish line.

**VS actively rewards going narrow:** Arcana XX grants +20% Might and −8% cooldown **per empty weapon
slot**; Babi-Onna scales with *fewer* weapons; the Mindbender relic lets a player cap their own slots.
Community consensus is to plan weapon+passive pairs *before the run* and commit from minute zero —
**not** "breadth early, depth late," a hypothesis the research explicitly failed to support.

### What the genre does

| Game | Weapon slots | Depth payoff |
|---|---|---|
| Vampire Survivors / HoloCure | 6 | Evolution / Collab (ingredients maxed) |
| Brotato | 6 (0–24 by character) | Two copies merge into the next tier |
| Halls of Torment | 6 | Trait rank + an Ability Signet ring |
| Deep Rock Galactic: Survivor | 4 | Overclocks at weapon level 6/12/18 |
| Rogue: Genesia | ~8 (player-set slider) | Re-picking levels a weapon; evolving frees the slot |
| 20 Minutes Till Dawn | **1** | Deletes the choice by construction |

Levers beyond the cap:

- **Duplicate → power.** Brotato merges two identical weapons into a higher tier; Rogue: Genesia, Halls
  of Torment and Death Must Die turn a re-pick into a level. *One card does double duty — no
  per-weapon upgrade content to author.*
- **Merging frees a slot.** VS's Union, HoloCure's Collab, Rogue: Genesia's evolutions return breadth
  capacity as the reward for depth.
- **Narrow-build rewards.** HoloCure's Solo Stamp: **+15% damage per empty weapon slot** (+75% at five
  empty). Brotato's Captain. VS's Arcana XX. Lets the player *choose* narrow rather than be forced.
- **Investment-gated options.** Nova Drift's mod trees reveal deeper options only once you commit to a
  branch — breadth of offer earned by depth of prior commitment.
- **Economic gating.** Brotato's shop reroll cost scales with wave and compounds per reroll.

**Sobering context:** several well-documented games have *not* solved this, and say so. Death Must Die's
devs state builds are "same-y" and that gods "predetermine the run before it is even started" (rework
announced, unshipped). Rogue: Genesia's devs describe legendaries going "obsolete due to common items
shortly after." No GDC talk on survivors-like progression exists. This is a genre-wide open problem.

**Uncertain / disputed:** whether open slots measurably dilute VS's card odds (inferred from the
confirmed `P = rarity / poolWeight` formula; one Steam thread disputes it); whether VS evolutions
require the paired passive to be *maxed* (sources contradict each other).

### Direction (PROPOSED — under discussion, not locked)

- **Cap weapon slots at 3.** The cap is load-bearing: it restores exclusion and turns the queue back
  into a choice.
- **Weapons stop being unique** — neither character-exclusive nor one-per-run. Duplicates become legal,
  so the pick becomes *"three of the same, or three different?"* — one currency (slots) buys either
  breadth or depth.
- **Character identity moves to artifacts**, not decks (§2). Characters stop being tied to a deck, which
  multiplies the character × deck combinations a player can try.
- **Decks offer a starting weapon choice** — pick 1 of 2 of the deck's weapons at run start
  ("upgrade 0").
- **The crux, unresolved:** *what a duplicate actually does.* If three copies are just three instances,
  "three of the same" is strictly worse than three different weapons (same damage, less coverage) and
  the choice is fake. A duplicate needs a non-linear payoff — a merge/tier-up (Brotato), a level
  (Rogue: Genesia), or a stacking bonus.

---

## 4. Cross-deck Synergies ("Combos")

The signature mechanic: committing to **two** themed decks unlocks a powerful, build-defining effect.

### Rules
- **Authored per deck-pair.** Curated and bespoke. Not every pair needs a combo; the ones that exist
  should feel handcrafted. (Auto-generated / emergent combos are explicitly rejected — they feel
  generic.)
- **A combo offers 2–4 authored SYNERGY OPTIONS; you pick ONE.** The options should *play differently*
  (sustain vs generation vs burst, etc.), so the pick is an identity decision, not a power pick.
- **One combo per run** — a major commitment.
  - **Stretch goal:** defeating a **secret boss** in the same run unlocks a **second** combo,
    deliberately very strong. Something for players to chase.
- **Investment gate:** a combo is only offered once you've **drafted ≥ N cards from the relevant
  deck(s)** ("power level") — proof you've committed to the theme. `N` = TBD.
- **Unlock trigger (event):** combos are **specialty cards** surfaced at a trigger, **not** in the
  normal level-up pool.
  - **For now: level 20.**
  - **Later: defeating a mini-boss** (secret boss → the second combo).
- **Scaling:** a synergy's effect **scales with continued theme investment** (reads your build), so it
  grows as you keep drafting the themes.

### Balance principle
A single synergy may be very strong, but **never unbounded on its own** — favor cross-theme
*conversions* and *detonates* over self-feeding loops. The "pick ONE synergy" rule is itself a
safeguard: two synergies that would loop together can't both be taken.

### Worked example — Fire + Lightning
Pick one of:
1. **Sustain** — *sparks that hit a burning enemy re-ignite it* (burns never lapse while sparks land).
2. **Generation** — *ignited enemies spawn a spark* (fire feeds your lightning).
3. **Detonate / Burst** — *sparks deal instant damage equal to the target's remaining burn* (trade
   sustain for a spike; the classic ignite-detonate).

Options 1 and 2 are the two halves of a runaway loop — safe *because* you take only one.

---

## 5. How it maps to the existing engine (build notes)

None of this needs a new delivery system:

- **A combo synergy IS an Artifact.** Reuse `ArtifactBase` (Events bus + player-cached
  `get_*_modifier()` hooks) — a combo is exactly "modifies core gameplay + reads your build."
- **Scaling** reads build investment — `BuildAnalyzer` already tallies effect-tag totals (fire,
  lightning, …); a combo artifact queries it.
- **"One per run" / "two if secret boss"** = flags on `CurrentRun`.
- **Investment gate** = a per-deck **drafted-card counter** (new, small — track in run/upgrade state).
- **Combo registry** = a new resource + master list (mirroring the deck list).

### Data model
```
DeckCombo (Resource)
  deck_a_id, deck_b_id       # the pair
  power_gate: int            # min cards drafted from the relevant deck(s) to be offered
  synergies: Array[Upgrade]  # 2–4 artifact-tier options; the player picks ONE
```

---

## 6. Open / deferred (tune in playtest)

- **Secondary deck timing:** chosen at **character-select** (planned, intentional) vs **drafted early
  in-run** (discovery, makes decks feel *unlocked*). Leaning **in-run draft**.
- **3rd-deck unlock condition:** deliberately hard — "some combination of difficult things"
  (secret boss and/or other feats). To flesh out; keep it rare enough that 3 decks stays exceptional.
- **Presentation:** combo as a special card in a gated pool **vs.** a dedicated "choose your fusion"
  screen at the trigger. Build the data/logic so both are trivial to A/B.
- **Trigger evolution:** level 20 (now) → mini-boss (later); secret boss → second combo.
- **Gate value `N`** (cards drafted) — tune. Currently **4** for Fire+Lightning.
- **Synergy effect numbers** — Fire+Lightning's three options are built but **unplaytested**; tune.
- **Content:** authored pairs beyond Fire+Lightning — incremental, added over time.

---

## 7. Build order (from the gap analysis)

0. ✅ Bug sweep (Static Discharge, Goliath, guaranteed core deck).
1. ✅ Biome soft-preference + confirmed adversarial countering.
2. ✅ **Deck restructure** — packs→decks, stable `Deck.id`, counted slot structure
   (`get_composition()`).
3. ✅ **Combo system** — `DeckCombo`/`ComboList`/`ComboManager` + drafted-card counter
   (`CurrentRun.deck_draft_counts`) + gate/trigger + level-20 choice flow; Fire+Lightning authored
   (Arc Ignition / Sustained Burn / Thermal Shock). *Numbers unplaytested.*
4. ✅ **Characters ↔ decks** (§2) — `PlayerStats.primary_deck` + `exclusive_upgrades`;
   `CurrentRun.get_active_deck_paths()` owns composition (core + primary + picks, capped at
   `max_themed_decks = 2`); the picker grants the primary and offers only the leftover slot.
   Magic Man→fire (Cinder Volley), Samurai→melee (Axe), both weapons pulled out of their decks.
   *Remaining:* Edgerunner / Shotgunner / Test are still **open** characters (theme = a design call;
   the projectile deck is empty); the secondary is chosen **at character-select** — moving it to an
   in-run draft milestone is the open call in §6. The 3rd deck is deferred with the secret boss.
   *May be revisited:* §3's proposed direction moves character identity to **artifacts** and unlinks
   characters from decks.
5. **Weapon economy** (§3) — slot cap + what a duplicate does. Blocks meaningful level-up choice.
6. Card manipulation (reroll / banish / swap).
7. Content + the multiplicativity decision (§3 argues for multiplicative).
