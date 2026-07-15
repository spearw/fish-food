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

1. **The combo gate demands depth.** Combos gate on ≥N cards drafted from *both* decks (§3) — a
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

**Why a 3rd is allowed at all:** the secret-boss **second combo** (§3) *requires* it — a 2nd combo
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

## 3. Cross-deck Synergies ("Combos")

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

## 4. How it maps to the existing engine (build notes)

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

## 5. Open / deferred (tune in playtest)

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

## 6. Build order (from the gap analysis)

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
   in-run draft milestone is the open call in §5. The 3rd deck is deferred with the secret boss.
5. Card manipulation (reroll / banish / swap).
6. Content + the multiplicativity decision.
