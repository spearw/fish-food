# Deck & Synergy System — Design

**Status:** locked, July 2026 (William + Jeff + Claude). The forward design for Fish Food's
progression: themed **decks** and cross-deck **synergies (combos)**. Builds on the existing engine —
weapons, artifacts, encounter director, armor (see `CLAUDE.md` for the map, `.claude/performance/`
for the perf-critical systems).

---

## 1. Decks (renamed from "packs")

The code currently calls these **packs** (`UpgradePack`). Rename to **decks** — same concept.

- ~~**Core deck** — granted every run, base-stat upgrades only (no weapons), locked on.~~
  **DISSOLVED (July 2026, locked — see §1b):** generic stat cards live *inside* themed decks now,
  with deliberate overlap. A run's pool is its picks and nothing else.
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

## 1b. Stat cards live IN decks — the core deck is dissolved (LOCKED, July 2026)

The always-on core deck of eleven generic stat cards is gone; the cards were redistributed into the
themed decks with deliberate overlap. **Deck choice is now also a stat-economy choice.** The model is
**Monster Train's two-clan structure** (every card comes from your chosen clans, pairings define the
run), not Vampire Survivors' universal passive pool.

Why (this doc's own research, §"why another weapon is always best"):

- Additive generic stat cards were already indicted as the decaying auto-pick wallpaper.
- Every core card in the union pool diluted themed offers and advanced **no combo counter** — while
  the doc's stated goal is that a run "feel like *a specific thing*."
- The pattern was half-built anyway: projectile carried Swift Bracer / Slipstream / Split Fire, toxin
  its status trio, lightning its spark trio. The core deck was the vestige.

**The law (locked): hard exclusivity for combat stats, guaranteed coverage for survival plumbing.**

- Every themed deck carries `player_max_health` — the universal defense floor.
- `player_armor` is **melee-exclusive**. "You have to take melee to get armor" is the point: deck
  select is a strategic read on what you'll need.
- Every former core stat must remain offerable from at least one deck.
- Enforced by `deck_link_verify.gd` (coverage section) — a deck that drops its max-health card or a
  second deck that picks up armor fails the build.

**Distribution v1 (WORKING — tweak freely as balance; only the law above is locked):**

| Card | Fire | Lightning | Melee | Projectile | Venom (id: toxin) | Cosmic |
|---|---|---|---|---|---|---|
| Damage | ✓ | ✓ | ✓ | | | |
| Crit chance | | ✓ | ✓ | | | |
| Crit damage | | ✓ | ✓ | | | ✓ |
| Area | ✓ | | | | ✓ | ✓ |
| Fire rate | | | | ✓ | | |
| Projectile count | ✓ | | | ✓ | | |
| Projectile speed | | | | ✓ | | |
| **Armor** | | | **✓ (only)** | | | |
| Move speed | | | | ✓ | ✓ | |
| Luck | | ✓ | | | | |
| Max health | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

Notes:

- **Doubling down:** pairing two decks that share a stat doubles your draft density on it. Cross-deck
  copies are the SAME resource today (one card, one tune). Two later balance levers, in escalation
  order: deck-flavored *variants* (different values/names — lightning's benched
  amplification/overcharge/reach are the ready-made template, see
  `systems/upgrades/upgrades/lightning/BENCHED.md`), and moving a doubled stat's rarer tiers into the
  multiplicative "more" layer so committing to the overlap *compounds* instead of decaying.
- **Mobility is NOT universal** (fire/lightning/melee pairings have no move-speed card; melee's Fight
  or Flight is its flavored answer). Watch-item: if dodge starvation feels bad rather than
  interesting, add *flavored* mobility per deck — never re-centralize.
- The meta shop's `permanent_stats` remain the out-of-deck plumbing floor.
- **Combo gate:** with core gone, every pick advances a deck counter, so combos arrive faster — the
  gate threshold is a playtest knob.
- **Zero decks = dead run** (empty pool, no starter weapon), so character select refuses to start
  without a pick. Fresh saves unlock fire + projectile (a full stat economy between them); when decks
  re-lock behind meta progression, the **unlock order must keep coverage sane**.
- The card resources still live in `systems/upgrades/upgrades/core/` — folder name is historical.

---

## 2. Characters ↔ Decks — identity, and how many decks a run gets

> **⚠ SUPERSEDED by §3, and the supersession is now BUILT (July 2026).** The **deck-count rule below
> is unaffected and still locked** (2 themed decks, 3 rare, never 4). Everything else here about the
> character↔deck *link* is history: `primary_deck` is retired, characters carry a granted identity
> **artifact** instead (Emberheart / Bushido / Adrenaline Rush / Extra Barrels), decks are chosen
> freely by any character, and the starting weapon is upgrade 0's cross-deck roll. "Lock the verb,
> free the sentence" survives — the verb just lives in an artifact now. Read §2 for the deck-count
> reasoning only; §3 is current for identity.

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

### The escalation ladder (in-run deck acquisition) — *revised by §3*

Deck acquisition rides the same milestone rhythm as combos, so a run has an arc:

| When | What |
|---|---|
| Start | **Both themed decks** (+ core), chosen at character-select. Upgrade 0 rolls one starter weapon candidate from *each* — the first fork between your themes (§3). |
| Level 20 / mini-boss | **Combo unlocks** (enough runway to have hit the ≥N-each gate). |
| Rare, hard-earned (condition TBD) | **3rd deck + 2nd combo** — the "go wide" reward for exceptional runs. |

Each unlock is an **event**, reusing the milestone-reward pattern the combo trigger already
establishes.

*(Superseded: the original ladder started with the character's linked primary deck and drafted the
secondary at an early milestone. §3's upgrade-0 roll needs both decks present from turn one, so the
mid-run rung is gone and the secondary is picked at character-select — which is what's already built.)*

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

### Direction (WORKING — agreed July 2026, deliberately NOT locked)

The direction to build against and playtest. **Reversible on purpose** — merge especially is "convinced
for now, not forever." Reversal cost is low: this is one economy plus an offer filter, not a rewrite.
See *What would make us revisit* at the end.

#### The shape

- **~5 slots, SHARED between weapons and artifacts.** One currency buys either damage or rules.
  - *Why shared — the economy self-balances.* A weapon's marginal value is **+1/N**: it *declines* as you
    take more. An artifact's is roughly flat — a rule is a rule. So a 4th weapon is worth +25% and
    falling while an artifact is still worth what it's worth, and every build slides to its own mix
    point. **Neither category can permanently dominate, because taking more of one makes it worth less.**
    That is the exact inverse of the diagnosed disease (weapons never got worse, because nothing was
    foregone).
  - *And narrow builds become native.* "1 weapon + 4 artifacts buffing it" is HoloCure's Solo Stamp
    fantasy expressed through the core economy — no bolted-on "+X% per empty slot" card needed.
  - *Why 5, not 3.* 3 was right for weapons-only; with artifacts sharing, three things total is a thin
    build. 5 keeps every pick heavy while leaving the spectrum expressible (3 weapons + 2 artifacts /
    1 weapon + 4 artifacts / five of one thing).
  - *Known risk:* if artifacts are flatly stronger per slot, "always take the artifact" simply replaces
    "always take the weapon." +1/N protects at low weapon counts; it does **not** protect against
    artifacts just being numerically bigger. **Watch in playtest.**
  - *Known deviation:* VS, Brotato, Halls of Torment and DRG:S all keep weapon and item slots
    **separate**; only Backpack Survivors shares (spatially). We're doing the rarer thing knowingly.
- **Weapons are not unique** — neither character-exclusive nor one-per-run. Duplicates are legal, so the
  pick becomes *"three of the same, or three different?"*
- **Character identity lives in ARTIFACTS, not decks.** A deck is a *noun* (a theme); an artifact is a
  **verb** (it changes a rule) — so this honours §2's *"lock the verb, free the sentence"* harder than
  the deck link did, and unlinking characters from decks multiplies the combinations a player can try.
  **The identity artifact is GRANTED, not slotted** — otherwise identity costs a slot and is really a
  tax (same principle as §2's granted primary deck).
  - *Cost, accepted:* Magic Man can now run melee. We gain combinations and lose thematic coherence, so
    **the artifact must carry the whole identity** or characters become hats. VS accepts this same trade.
- **Upgrade 0 — one starting weapon, chosen from two candidates, one drawn at random from each of your
  starting decks.** The first decision is a fork between your two themes; randomised candidates give
  replay variance without letting the run be pre-scripted. It doubles as the **damage floor**, so a
  shared pool can never produce a "0 weapons, dead run."

#### Duplicates merge (Brotato's rule)

- **Two identical weapons of the same rarity → one of the next rarity.** Strictly **pairwise, not bulk**
  — three copies don't collapse in one action.
- **Merging frees a slot** (2 → 1). That's what keeps the economy churning instead of filling at ~pick 5
  and leaving 20 level-ups of stats: **draft copies → merge up → free slots → draft rules.**
- **"Three of the same" is therefore a ladder:** 4 copies → 2 second-rarity → 1 third-rarity, ending with
  3 slots freed for artifacts.
  - *Built (v1, Jul 2026) — one honest gap:* the shipped merge trigger is **drafting a duplicate at a
    full loadout** (drafted card + your same-tier copy → next tier). That conserves slots rather than
    freeing them. The **2-owned→1 consolidation that frees a slot has no trigger yet** — it needs a
    small UI (a merge button on the pause/level screen), deferred. Until then the ladder climbs via
    drafts; the "free slots for artifacts" payoff needs the UI piece.
- **Auto-merge when slots are full** and a matching duplicate is drafted (Brotato does this) — do the
  obvious thing rather than block the pick.
- **Merging is a path, never a gate.** Higher rarities can also be drafted directly; the draw is
  rarity-weighted and luck-scaled, so **luck is the "find it in the wild" lever** (Brotato gates high
  tiers on wave + Luck the same way).
- **Per-weapon rarity curves, not a uniform ladder.** Brotato scales per weapon on purpose — Fist doubles
  every tier (8/16/32/64) while Wrench crawls (12/16/20/24) — making some weapons merge-hungry and others
  not worth it. That texture is worth stealing.

#### The slot economy: pre-commitment vs post-commitment

The rule that keeps each lever distinct — and the reason a discard would undermine merge:

- **Pre-commitment tools act on the OFFER.** Reroll / banish / swap (§7) shape what you're *shown*.
  Free by nature: at a level-up you already pick 1 of 3, so declining costs nothing.
- **Post-commitment: MERGE IS THE ONLY LEVER. There is no owned-weapon discard.**
  - *This is Brotato's actual design, and it's deliberate.* There is no way to sell or discard an owned
    weapon; its "recycle" is **crate-only** (pre-pickup). The New Dawn DLC's ban system covers items and
    **explicitly excludes weapons** — reportedly tested and cut as overpowered. Steam Workshop mods exist
    *solely* to add owned-item selling: players want it, the dev withheld it. A player defending its
    absence: *"the point that you can't sell them is part of the decision process."*
  - *Cleaner here than in Brotato:* we're always pre-commitment at a level-up, so **you only ever own
    what you chose.** There's nothing to be rescued from, so no discard is needed.
- **Every game checked follows the same split** — Rogue: Genesia's banish/reroll, Boneraiser's seal,
  Brotato's crate recycle all act on *offers*, never on owned slots. They never compete with merge
  because they answer a different question: *"do I want this at all?"* vs *"I own two — consolidate?"*

#### Replacement-when-full (the anti-dead-card rule)

**The hole:** slots full, you own a Common Fire Staff, you're offered a Rare one. They can't merge
(different rarities) and there's no slot — so a strict upgrade is unusable. Brotato has this exact hole;
it just doesn't hurt there, because a blocked *shop purchase* is one of four options you chose to browse
and can reroll. **In a 3-card level-up draw, a dead card is a third of your choice, gone.** Different
delivery model, different rule — don't copy the reference here.

**The rule:** *at full slots, drafting a higher-rarity copy of a weapon you own replaces it in place.*

- **"Only when full" is the correct gate, and it falls out of the math** rather than being special-cased:
  with a free slot, taking it as a *second copy* is strictly more damage (Common 10 + Rare 20 = 30 > a
  lone Rare's 20). You'd never *want* to replace while a slot is open. Full slots is precisely the
  condition where replacement is the only way to gain.
- **It doesn't reopen the post-commitment door.** Same weapon, better — you can't pivot themes, dodge a
  bad call, or convert a weapon into an artifact. It *deepens* a commitment rather than escaping one.
- **It sharpens merge rather than diluting it.** Replacement frees no slot, so it takes the "I just want
  a higher rarity" job off merge. Each mechanic now has exactly one job: **merge consolidates,
  replacement upgrades in place.**
- **Accepted cost:** with a free slot, "take as a 2nd copy" vs "replace" is arguably a real choice (two
  sources vs one better source + a freed slot). This rule forecloses it — buying a one-sentence rule at
  the price of one point of expressiveness. Two-sources is usually the better play anyway.
- **The healthy tradeoff survives:** Common + Rare in two slots (30 damage, never mergeable) vs two
  Commons merged into a Rare with a slot freed (20 damage + an artifact). A real decision, not a trap.

#### The general form: never offer a card the player can't use

Replacement is one instance of a class. The mirror bites too: full slots, you own a **Rare** Fire Staff,
you're offered a **Common** — can't merge, can't slot, can't upgrade. Dead card again. So the thing to
implement is not "allow replacement when full" but the **offer filter**:

> A weapon is offerable if it can be **slotted**, **merged**, or **upgrade-replaced**. Otherwise don't
> show it.

Replacement is then simply what taking the card *does* in one of those cases. This extends machinery that
already exists — `UpgradeManager.get_upgrade_choices()` already filters offers against inventory (UNLOCK
cards only appear if you don't own the target). Legal duplicates just mean "already owned" stops being a
disqualifier, and that check becomes the three-way test above. Same machinery, better predicate.

#### How it maps to what exists

- **`Upgrade.Rarity`** (COMMON/RARE/EPIC/LEGENDARY/MYTHIC) is already the merge ladder.
- **The rarity-weighted draw** (85/40/25/15/5), already scaled by the player's **`luck`** stat, is
  already Brotato's "higher tiers appear with luck."
- **`rarity_values: Array[float]`** already does per-card scaling → per-weapon rarity curves are
  expressible today.
- **`PlayerStats.exclusive_upgrades`** is already the mechanism for a granted identity artifact — same
  field, different content.
- Weapons currently carry a single fixed `rarity` (UNLOCK cards match an exact bucket). A merge ladder
  needs an **instance** rarity that can grow — the one genuinely new piece.

#### Knock-on effects

- **§2's ladder loses its middle rung.** "Both decks at start" (required by the 1-of-2 starter roll)
  settles §6's open secondary-deck timing: **chosen at character-select** — which is what's already
  built. The ladder becomes: 2 decks at start → combo at level 20 → 3rd deck rare.
- **§2's character↔deck link is superseded** if this lands: `primary_deck` goes away, identity moves to a
  granted artifact, and Cinder Volley / the Axe return to their decks (probably as starter candidates).
  The unwind is small — deck composition, the cap and the picker are untouched.
- **Multiplicativity (§7):** this direction argues for **multiplicative**. Additive stat cards decay
  exactly when weapons stay strong, which is the shape of the diagnosed problem.

#### What would make us revisit merge

- The ladder proves **too slow** to matter within a run's ~20–30 picks (4 copies for a third-rarity
  weapon is a lot of RNG to ask for).
- **Artifacts dominate the shared pool**, making weapon merging moot.
- "Three of the same" turns out **visually or mechanically dull** next to three different weapons.
- Held in reserve: **level-in-place** (Rogue: Genesia — a re-pick levels the weapon; consumes no slot, so
  it doesn't participate in the shared economy, which is why it lost) and **stacking bonuses**.

#### Uncertain

- **Noobs Are Coming** was cited as corroboration for the merge pattern, but **its weapon-duplicate merge
  is unconfirmed** after dedicated research (its wiki is unreadable to tooling). What *is* confirmed there
  is a **"Character Merge"** fusing 2–3 characters' *passive kits* — a different mechanic. Treat NAC as
  un-cited support until verified in-game.

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
  - **BUILT (Jul 2026): killing the Herald** — a mini-boss the director spawns at 8:00, drawn from
    three candidates (Pufferfish/Moray/Lionfish) through the counter-mode weighting, so Abyssal
    sends the one your build least answers. Kill → the combo choice on the spot (gate still
    applies; unmet gate defers the offer to the first qualifying level-up).
  - **Fallback:** if the Herald leaves unkilled (90s leave timer) — or the world has no herald
    (benches) — the trigger falls back to level 20. Delayed, never lost (reward-not-requirement).
  - **The secret boss → the second combo** (pass 2, designed: the Anglerfish lure, armed by any of
    three proofs — fast Herald kill / combo+depth by 12:00 / flawless Herald fight).
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

- ~~**Secondary deck timing**~~ — **SETTLED (§3):** both decks are held from the start, because
  upgrade 0 rolls one starter candidate *from each* deck. So the secondary is chosen at
  **character-select**, which is what's already built. §2's ladder loses its middle rung.
- **3rd-deck unlock condition:** deliberately hard — "some combination of difficult things"
  (secret boss and/or other feats). To flesh out; keep it rare enough that 3 decks stays exceptional.
- **Presentation:** combo as a special card in a gated pool **vs.** a dedicated "choose your fusion"
  screen at the trigger. Build the data/logic so both are trivial to A/B.
- **Trigger evolution:** level 20 (now) → mini-boss (later); secret boss → second combo.
- **Gate value `N`** (cards drafted) — tune. Currently **4** for Fire+Lightning.
- **Synergy effect numbers** — Fire+Lightning's three options are built but **unplaytested**; tune.
- **Content:** authored pairs beyond Fire+Lightning — incremental, added over time.
- **Identity artifacts must be self-sufficient verbs** (decided Jul 2026): they may *love* a deck,
  but must never *require* one — the same reward-not-requirement shape as the combo gate and the
  walled cap. Found the hard way: Emberheart v1 only listened for burns, and with free deck choice a
  fire-less Magic Man carried a literally dead artifact all run (while his card text promised "his
  fire follows"). v2 = kills spread fire (universal — the fire mirror of Static Discharge) + burns
  escalate to ignites (amplified by fire investment). **Flagged, accepted for now: Extra Barrels is
  partially dead on a pure-melee Shotgunner** (swings don't consume projectile count) — most decks
  carry projectiles, but it's the same class of issue if a melee-only meta emerges.
- **DoT's counter axis** (direction noted Jul 2026): armor hard-counters direct damage; nothing
  hard-counters DoT. The matrix now soft-counters it (FAST closers outrace the ramp, RANGED kites the
  short delivery — and armored/evasive are down-weighted, since ticks ignore armor and one graze
  applies a full burn). Candidates for the *hard* version later: a **status-RESISTANT/immune**
  behavior tag (armor's twin) and/or a **REGENERATOR** enemy (out-heals slow ticks). A status-immune
  enemy would also need the walled-share cap generalized — immunity is a wall for a pure-DoT build,
  and the wall test currently only models armor.
- **Armor-interaction artifacts** (content, decided Jul 2026): an **armor-BREAK** artifact (hits shred
  armor — turns fast weapons into can-openers) and a **CHIP-floor** artifact (hits always deal ≥X% of
  raw through armor — makes a million-hits lightning build work into heavy armor). Player-side verbs
  only — **no artifact ever changes the global armor rule.** Either also silently disables the
  director's walled-share cap for that build, since nothing is walled anymore (see
  `.claude/balance/workflow.md`).

---

## 7. Build order (from the gap analysis)

0. ✅ Bug sweep (Static Discharge, Goliath, guaranteed core deck — *the guarantee is since retired
   with the core deck itself, §1b; the verifier now pins pool-from-picks-only*).
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
   **⚠ Partly superseded by §3** — identity moves to a granted artifact and characters unlink from
   decks, retiring `primary_deck` and returning Cinder Volley / the Axe to their decks. The deck
   *composition* (core + picks, capped) survives, as does `exclusive_upgrades` (repointed at the
   identity artifact). Don't build further on the deck link until §3 is settled.

5. **Weapon economy** (§3) — gates the rest. Progress:
   1. ✅ **Shared slot cap** (5, weapons+artifacts; granted items exempt). *Upgrade-0's 1-of-2 starter
      roll (the damage floor) is NOT built yet — it lands with step 5.*
   2. ✅ **Instance rarity** — per-weapon curve, scales the whole damage tree (nested stats + DoT).
   3. ✅ **Merge (v1)** — drafted duplicate at a full loadout fuses with your same-tier copy →
      next tier, via `Weapon.set_rarity` (in place: transformations survive). Strictly pairwise, no
      cascade. *Deferred: the 2-owned→1 slot-freeing consolidation needs a small merge UI.*
   4. ✅ **Offer filter** — a weapon card is offerable iff slottable / mergeable / upgrade-replaceable
      **at the rolled tier** (`_weapon_offerable_at`); replacement-when-full upgrades the lowest owned
      copy in place; dead tiers (lower than everything owned, Mythic-on-Mythic) are hidden. The card
      text says what taking it does ("merges into Epic" / "upgrades your Common").
   5. ✅ **Identity artifacts + upgrade 0** (Jul 2026) — `primary_deck` retired; characters carry a
      GRANTED identity artifact in `starting_upgrades` (Magic Man: **Emberheart**, burns can escalate
      to ignite; Samurai: **Bushido**, kills grow crit; Edgerunner: **Adrenaline Rush**, kills surge
      speed; Shotgunner: **Extra Barrels**, +2 projectiles on everything). Cinder Volley and the Axe
      returned to fire/melee; **daggers + shotgun fill the projectile deck** (no longer empty, added
      to the master list). **Upgrade 0 built**: at run start, one weapon candidate rolled per chosen
      deck, pick one — the fork between your themes, and the damage floor. Decks are chosen freely
      (any character, any pair). *Numbers on all four artifacts are playtest fodder.*
   Then **playtest**: does the ladder pay off inside ~20–30 picks, and do artifacts eat the pool?
6. ✅ **Card manipulation** (Jul 2026) — **pre-commitment only** (§3), acting on the offer, never on
   owned slots. **Reroll** (redraw all 3) and **Banish** (remove a card from this run's pool at every
   tier, refill the slot) — flat **2 charges each per run** (`CurrentRun.REROLLS_PER_RUN`/
   `BANISHES_PER_RUN`; a meta unlock can feed these later, as VS does). One-shot offers (the combo
   choice, the starter roll) are exempt. Also fixed in passing: **per-run state now actually resets**
   (`CurrentRun.reset_run_state()` from the start button) — run 2 in a session used to inherit run 1's
   flags, killing the starter roll and combo. *"Swap" folded into banish (banish = swap this card for
   another); a dedicated swap can come later if playtest wants it.*
7. Content + the multiplicativity decision (§3 argues for multiplicative).
8. ✅ **Core deck dissolved → stat cards live in decks** (§1b, Jul 2026) — Monster Train model:
   eleven cards redistributed with overlap (same shared resources), max-health floor everywhere,
   armor melee-exclusive, coverage law enforced in `deck_link_verify.gd`; character select requires
   ≥1 deck; fresh saves start fire+projectile. *Distribution v1 is a balance knob, not locked.*
