# UX — information legibility (July 2026)

Field research distilled (two passes: bullet-heavens Brotato/VS/HoT/DRG:S/20MTD/DMD; deckbuilders
Monster Train/StS/Balatro/Roguebook/Griftlands). Full reports in session logs; these are the laws
we build UI against. Sibling docs: `.claude/balance/` (numbers), `.claude/performance/` (frames).

## Laws

1. **Exact numbers, zero adjectives.** Every card states its value; every value states its result.
   Genre-wide consensus — where numbers are missing (20MTD, early VS) the top community threads are
   requests for them, and VS's most-endorsed mods are DPS meters.
2. **A delta with no resulting total is a mistake.** Show "+15% (+30% → +45%)", not "+15%".
   (Brotato deltas, HoT base→final columns; VS's "-30% cooldown" of an unseen base is the
   anti-pattern.)
3. **One source of truth per displayed number.** Every UI number flows through `BuildSummary`
   (or a manager function it calls). HoT's reputation — "tooltips inconsistent and/or broken" —
   is what happens otherwise; a wrong number is worse than no number.
4. **Derive contents from data, never hand-write them.** Deck manifests come from the card list
   (`Deck.get_manifest()`), so they cannot go stale. Hand-written text is for VERBS (flavor,
   identity), and must stay factually true (we've had to fix "slow but powerful" on the deck's
   weakest hit).
5. **The pick is a contract — show the composed result.** Deck select previews the MERGED pool of
   the current picks (size, weapons, stat access with missing stats dimmed, doubled stats gold).
   Monster Train's clan-pick sequence and Balatro's count-panels are the models. Counts, not
   probabilities — counts are honest under weighting changes.
6. **Locked content stays readable with its unlock condition** (MT champion tooltips, Balatro's
   "Not Discovered + how"). A blank LOCKED tile teaches nothing.
7. **Layer depth behind hover/click; layer one must be self-sufficient.** MT's always-on tooltip
   flood (half a controller screen) is the warning.
8. **Weapon-local vs global must be distinguishable** (VS fails this). Cards carry their deck tag;
   per-weapon numbers live on the weapon detail line with player multipliers applied.

## Where things live (built, this pass)

- `BuildSummary.deck_manifest_lines(deck)` — deck button contents (weapons/stats/mechanics/counts).
- `BuildSummary.pool_preview(decks)` — deck-select combined-pool line (gold ×2 / dim missing).
- `BuildSummary.stat_card_preview(player, upgrade, rarity)` — level-up before→after, reading the
  same two-layer state `apply_upgrade` writes (MULTIPLICATIVE→"more ×A→×B", ADDITIVE→percent-sum
  or flat, POWERS→levels).
- `BuildSummary.extras_line(player)` — tab-screen stats without fixed labels (max HP, status
  duration, sparks) — shown only when active.
- `UpgradeManager.deck_tag(upgrade)` — "[Fire]" on every card (combo-gate progress is a draft-time
  read).
- Tab screen: run-context header (slots + loadout + drafted counts), artifact NAMES (were empty
  rectangles).
- All pinned in `ux_verify.tscn` §7.

## Per-source damage attribution (BUILT, July 2026)

Brotato's post-wave report, live: `CurrentRun.damage_by_source` tallies POST-ARMOR damage per
source key. The choke point is `entity.take_damage` (source node carries `attribution_key`);
`FireBehaviorComponent` stamps every projectile with its weapon's `weapon_type`, and everything a
projectile causes inherits it — sparks, explosions (exploding path), trail segments, zones, and
DoT ticks (stamped through `apply_status`, escalations included). **A null source at the choke is
the DoT-tick path and is deliberately NOT credited there — ticks credit themselves** (else double
count); any new damage caller must pass a source node. Artifact damage carries its own key
(Static Discharge, Thermal Shock, Arc Ignition, Emberheart); keyless sources land in "Other".
Displayed via `BuildSummary.damage_report_line()` (top-first, comma-formatted, shares) on the
level-up Build tab and the tab screen, where the top weapon row is tinted gold and each weapon row
shows its dealt total. Pinned in `attribution_verify.tscn`.

Also fixed while surfacing crit (July 2026): **player crit stat is BONUS semantics** — weapon
crit × (1 + bonus), bonus = character base + cards. The old `base × cards` form multiplied a 0.0
base on 3 of 4 characters: every crit card was dead. The sheet says "Crit Bonus: +N% weapon crit"
and each weapon's detail line shows its own effective crit.

## Backlog (ranked by the research, not yet built)

1. Hover tooltips (keyword layering; artifact descriptions on the tab screen).
2. Logbook-style full-pool browse from deck select ("View all cards (N)").
3. Number hygiene at scale: SI prefixes past 100k.
4. "Damage since last level" window (the run-total report may get stale-heavy late; Brotato's
   per-wave framing is the model if playtest wants recency).
