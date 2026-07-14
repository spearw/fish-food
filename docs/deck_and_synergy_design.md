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

## 2. Cross-deck Synergies ("Combos")

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

## 3. How it maps to the existing engine (build notes)

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

## 4. Open / deferred (tune in playtest)

- **Presentation:** combo as a special card in a gated pool **vs.** a dedicated "choose your fusion"
  screen at the trigger. Build the data/logic so both are trivial to A/B.
- **Trigger evolution:** level 20 (now) → mini-boss (later); secret boss → second combo.
- **Gate value `N`** (cards drafted) — tune.
- **Content:** authored pairs beyond Fire+Lightning — incremental, added over time.

---

## 5. Build order (from the gap analysis)

0. ✅ Bug sweep (Static Discharge, Goliath, guaranteed core deck).
1. ✅ Biome soft-preference + confirmed adversarial countering.
2. **Deck restructure** — rename packs→decks, add the stable `id`, add counted slot structure.
3. **Combo system** — `DeckCombo` registry + drafted-card counter + gate/trigger + choice flow;
   Fire+Lightning as the first authored pair.
4. Characters ↔ decks (linked starting deck + exclusive weapon + secondary).
5. Card manipulation (reroll / banish / swap).
6. Content + the multiplicativity decision.
