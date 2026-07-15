# Balance methods — what the field actually knows

Research, July 2026. **Every item is marked:**

- **FINDING** — what the research established, with a source. Credibility tagged where it matters:
  *(official)* = developer/primary, *(community)* = reverse-engineered but rigorous,
  *(folklore)* = widely repeated, untraceable.
- **CONCLUSION** — what **we** decided for Fish Food. Ours to change.
- **GAP** — confirmed absent. Searched for, not found. These are not to-do items; they're the reason
  we measure instead.

---

## 1. The headline

> **FINDING (verified):** There is exactly **one** rigorous, freely-verifiable framework in this whole
> space — Ian Schreiber's cost curve. It is a **comparative process, not a plug-in equation.**

Almost everything "everyone knows" evaporates on inspection:

- **FINDING (official):** Mark Rosewater, asked point-blank in 2025 whether MTG has a mana→power
  formula: *"There's no formula per se, but we have a lot of institutional knowledge from decades of
  making Magic cards."* The rumoured "leaked internal MTG cost formula" has **no credible provenance**
  — the one circulating is self-admitted fan invention.
- **FINDING (folklore):** Hearthstone's "vanilla test" — `(Attack + Health − 1) ÷ 2 = mana`, i.e.
  total stats ≈ `2×mana + 1`. **No Blizzard designer ever confirmed it**, and it already breaks at 7
  mana (14 stats, not 15). Community keyword prices contradict each other (Divine Shield is 1 stat
  point in one thread, 2 in another, never reconciled).
- **FINDING (official):** Riot *does* publish a Champion Balance Framework — but it's **intervention
  thresholds, not costing**: nerf at 54.5% win rate, buff under 49%, Elite tier at 45% ban rate. A
  *when do we fix it* system, not a *how do we price it* one. And in the same document, its lead
  designer: *"New and updated champs won't abide by these exact parameters for about one month after
  release... we don't think we've done a great job at balancing new and updated champions."*
- **FINDING (community):** League's gold-per-stat table (AD=35g, Armor=20g, AP=20g, Health=2.667g,
  Crit=40g) is **fan-derived by dividing the price of the cheapest single-stat item** — not a Riot
  methodology, and no regression is involved.
- **FINDING (official):** Gwent's "provisions" is a real published budget (~150 pool ÷ 25 cards ≈ 6.5
  per card, +4 for Echo, −4 for thinning) — but CD Projekt frames it as an **auction-price system**,
  not a per-stat table.

> **CONCLUSION:** Stop looking for the formula. It doesn't exist. Use Schreiber's process to ballpark,
> then measure. (README law 2.)

---

## 2. Schreiber's cost curve — the one real method

> **FINDING (official, verified by direct fetch):** The method is **pairwise isolation and subtraction,
> chained** — not regression, not simultaneous equations.
>
> 1. Find two items differing in **exactly one** attribute.
> 2. Set `total_cost = total_benefit` (his equating principle).
> 3. Everything else known → subtract to isolate the unknown:
>    `price(attribute) = total_cost_A − total_cost_B`.
> 4. Chain across many pairs to build a cost table; combine known prices to price compound items.
> 5. Where isolation fails: *"educated guess, then trial and error."*
>
> His own MTG numbers: colorless mana ≈ 1 stat point; 2nd colored pip ≈ 3; **Flying ≈ +1**;
> **Deathtouch ≈ +3**; +1 cost past 4 mana, +1 more past 5 (the curve bends because MTG's own mana
> rate averages ~1/turn).
>
> **It's predictive, not just retrospective** — he plugs a proposed `W3, 1/4` into the derived curve
> and finds it *"exactly 1 below the curve."*
>
> Source: <https://gamebalanceconcepts.wordpress.com/2010/07/21/level-3-transitive-mechanics-and-cost-curves/>

> **FINDING (official):** In that same lesson: *"no one **ever** gets game balance right on the first
> try"*, and cost-curve corrections are *"expensive in terms of design time."* He also notes cards
> *"underpowered normally but overpowered in the right deck"* — metagame effects the curve cannot price.

> **FINDING (official):** At the **end of his own course**, Schreiber recants the premise: *"A fun game
> is a balanced game, and a balanced game is a fun game... I'm not too proud to say that I was very
> wrong about this."*

> **CONCLUSION:** Adopt the isolation method for **ballparking only**. We're well-suited to it — we
> have ~19 weapons to isolate against. It produces a hypothesis to bench, never an answer.

### Transitive vs intransitive — the most useful idea in the research

> **FINDING (official):** **Transitive** = *"some things are just flat out better than others in terms
> of their in-game effects, and we balance that by giving them different costs."* Cost curves apply
> **only** here. **Intransitive** = *"games like Rock-Paper-Scissors... where there is no single
> dominant strategy, because everything can be beaten by something else"* — balanced by counter-play.
> Conflating the two is a named source of balance confusion.

> **CONCLUSION:** Our **rarity ladder is transitive** — price it. Our **slot choice (weapon vs weapon
> vs artifact) is intransitive** — do *not* price it; that's what `COUNTER_MATRIX`, `BuildAnalyzer` and
> `counter_mode` are for. This is README law 4, and it retro-justifies the adversarial director we
> already built.

---

## 3. Effective DPS — the answer is "simulate"

> **FINDING (official):** **SimulationCraft**, the most rigorous DPS tool in the industry, **sidesteps
> the composite-formula problem entirely via Monte Carlo simulation rather than a closed-form
> equation.** It resolves DoT value by simulating, not by pricing. Uptime is handled with scripted
> distance-gated raid events — simulated, not computed.

> **FINDING (GAP, confirmed):** There is **no standardized "effective DPS" formula** anywhere,
> official or community, that composes AoE + DoT + range + pierce. The multiplicative shape is real
> *piecewise* (below), but nobody assembles it under one name. **We'd be inventing ours.**

> **FINDING (official):** The best real composite found — Warframe — **explicitly excludes AoE and DoT**:
> ```
> AvgShot         = TotalDamage × (1 + CritChance × (CritMultiplier − 1))
> AvgBurstDPS     = AvgShot × EffectiveFireRate
> AvgSustainedDPS = AvgBurstDPS × [ShotsPerMag / (FireRate × ReloadTime + ShotsPerMag)]
> ```
> Even the best one doesn't unify what we need.

> **CONCLUSION:** Don't derive a composite. **Bench it.** (README law 2, [workflow.md](workflow.md).)

### AoE

> **FINDING (official):** Schreiber (Level 6): an AoE attack's value ≈ **expected targets hit ×
> single-target value** — *"take the expected number of things you'll hit, and multiply."* With his own
> caveats: damage spread thin is worth less than lethal single-target, and **AoE thins its own cluster
> as it kills** — the multiplier eats itself.

> **FINDING (community):** PoE scales area by **radius², not radius**:
> `new_radius = old_radius × √(1 + increased_AoE%)`. +100% area → radius **×1.41**, not ×2.

> **FINDING (official):** Real falloff shapes exist but don't generalise — TF2 splash floors at 50% at
> the radius edge; Warframe is 90% falloff center→edge; Overwatch's Pharah rework deliberately traded
> explosion damage (80→65) against direct-hit (40→55).

> **FINDING (folklore):** "AoE should be 60–80% of single-target per target" is **untraceable** to any
> professional source.

> **CONCLUSION:** Use expected-targets × single-target as the *ballpark only*. **The self-thinning
> effect is exactly what our bench measures** and no formula covers.

### DoT

> **FINDING (community, cross-confirmed):** `total_damage = tick_damage × (duration / tick_interval)`.

> **FINDING (community):** PoE's ignite **conserves total damage when hastened** —
> `EffectiveDuration = BaseDuration / (1 + faster_ailment%)` **front-loads rather than adds**.

> **FINDING (official):** PoE scopes overkill to hits only — **"damage over time can never overkill"**.
> It designs the problem away rather than modelling it.

> **FINDING (community):** Three real stacking models, all deliberate design choices:
> 1. **Highest-only-then-resume** (PoE Ignite) — instances coexist, only the strongest ticks; weaker
>    resume when it expires.
> 2. **Fully independent/additive** (PoE Poison) — unlimited stacks, all sum.
> 3. **Merge-on-refresh** (Diablo 4) — `dotNew = dotRemaining + dotNewApplication`.

> **FINDING (GAP, confirmed — the important one):** **No credentialed source anywhere states a
> burst-vs-DoT compensation ratio.** **Dan Felder** (ex-Lead Designer, Riot's Legends of Runeterra)
> calls it *"one of balance design's genuinely unsolved problems."* No source models **wasted DoT ticks
> from early target death**. WoW's "pandemic" refresh caps early-refresh near 30% of duration and
> **Blizzard has never explained why 30%.**

> **CONCLUSION:** **Stop looking for a DoT ratio — a Riot lead says it's unsolved.** Bench it.
> DoT overkill waste is a real cost our bench can measure and PoE simply declared away. Relevant to us
> because our fire deck carries most of its damage in `DotStatusEffect.damage_per_tick`, not in
> `projectile_stats.damage`.

### Range, uptime, pierce

> **FINDING (GAP):** No official source converts range into a damage-equivalent multiplier.
> Community models exist and are multiplicative (`ActualDPS = TotalDPS × %map_in_range`; PoE's
> `AverageHit × HitChance × AttackSpeed × multiplier`).

> **FINDING (official, verified):** **Brotato's pierce = 50% damage falloff per pierce, compounding
> multiplicatively, rounded down each hit**, with per-weapon exceptions (Crossbow 0%, Shredder 0%,
> Gatling Laser 25%, Double Barrel 30%). *(This resolves a contradiction between two Brotato wikis —
> 50% is the default, 25% is a per-weapon exception. Both were right.)*

> **FINDING (official):** PoE **prevents "shotgunning"** — one attack's projectiles normally can't all
> hit the same target. So pierce/projectile-count multiplies **targets**, never single-target damage.

> **FINDING (official, and the most telling in the whole report):** **Halls of Torment's in-game DPS
> calculator explicitly excludes AoE and pierce**, and its developer confirmed the displayed stat
> doesn't account for pierce or AoE overkill. **A shipped bullet-heaven's own dev tooling won't fold
> pierce into one number.**

> **CONCLUSION:** Nobody has solved this, including our genre. Bench it. Note also the shape to steal:
> **a global default with per-weapon exceptions** (README law 5).

---

## 4. Stat stacking — the shape to copy

> **FINDING (community):** Path of Exile:
> ```
> stat_total = base × (1 + Σ increased% − Σ reduced%) × ∏(1 + more_i) × ∏(1 − less_i)
> ```
> Two +10% "increased" → **120%** (additive). Two +10% "more" → **121%** (multiplicative).
> Worked: 1000 base with two +100% increased already applied — a third **increased** gives
> `1000×(1+3.0) = 4000`; the same as **more** gives `1000×(1+2.0)×(1+1.0) = 6000`.
>
> **The additive trap:** +60% additive on top of +2000% additive nets **~2.85% real damage.**

> **FINDING (community):** **Halls of Torment**: `FinalStat = (BaseStat + BaseBonus) × (1 + MultiplierBonus%)`
> — a clean two-term additive-then-multiplicative model, in a shipped bullet-heaven.

> **FINDING (community):** **Vampire Survivors**: Area stacks *additively* from characters/PowerUps/items,
> then **Arcanas multiply** against that combined total. Might is additive, capped at +900%. Amount is
> flat-integer, capped at +10. Same two-layer shape, simpler.

> **CONCLUSION — this settles our pending multiplicativity question.** It was never additive *versus*
> multiplicative: **additive within a layer, multiplicative across layers** (README law 6). All three
> reference games converge on it, two of them in our exact genre. `Upgrade.ModifierType` already has
> both values and is currently cosmetic — the work is to **make it real as two tiers of card**, not to
> pick a side. Caps are also load-bearing in both survivors-likes; expect to need them.

---

## 5. Rarity / tier curves

> **FINDING (GAP):** **No franchise publishes a numeric power-per-tier rule.** Checked Diablo,
> Borderlands, Destiny — all public statements are about rarity *feeling* meaningful or about drop
> rates, never power math.

> **FINDING (official):** Diablo IV's system-design blog: tier power *"doesn't need to be linear... can
> slow down"* — an official vote for **diminishing** over pure-geometric.

> **FINDING (community):** WoW realises rarity as a **flat multiplier chain**: Blue = **1.1×** Green,
> Epic = **1.25×** Blue (~1.375× across two tiers) — **much shallower than geometric.** (Its *item-level*
> curve is separately exponential: `Stat = C·e^(k·ilvl)`.)

> **FINDING (community):** D&D 5e magic items are ~10×/tier (100/400/4,000/40,000/200,000 gp) — but that
> prices **gold, not power**, and the source cautions against reading it as power.

> **FINDING (community):** **Why 4–5 tiers: path dependency, not principle.** Colour-coded rarity
> descends from the roguelike *Angband* → Diablo (3 tiers) → WoW added purple in 2004 → everyone copied
> WoW. **No principled justification for the number 5 exists anywhere** (the researcher explicitly
> checked whether "7±2" chunking is ever cited — nothing connects them).

> **FINDING (community):** RoR2 hard-caps one stat at **127 stacks purely to avoid float overflow** —
> unbounded multiplicative tiers create real numerical blowup.

> **FINDING (peer-reviewed — a live dissent):** Ethan Ham (*Game Studies*) argues the rarity=power
> premise is itself wrong: **common items should be broadly, bluntly powerful; rare items merely
> *specialized*** — not necessarily stronger.

> **CONCLUSION:** Our 1.8×/tier is **on the aggressive end** (WoW is ~1.1–1.25×). It's defensible
> because our tiers are **merge-gated** — a tier must beat "two copies in two slots," which WoW's don't
> have to. **But the 2.0 baseline is an assumption.** Bench the real two-copy multiplier per weapon
> before trusting it (README law 5, [workflow.md](workflow.md)). Ham's dissent is worth revisiting if
> the ladder ever feels like it flattens build variety instead of expressing it.

---

## 6. Risk of Rain 2 — the stacking-shape vocabulary

> **FINDING (community, verified twice):**
> ```
> Linear:      f(x) = 1 + a·x
> Hyperbolic:  f(x) = 1 − 1/(1 + a·x)
> Exponential: f(x) = a^x
> Reciprocal:  f(x) = a/x
> ```
> Worked: Tougher Times (a=0.15), 10 stacks → `1 − 1/(1+1.5)` = **60%**, asymptotic, never 100%.
> 57 Leaf Clover: `1 − (1−p)^(n+1)`.

> **FINDING (community) — hyperbolic is applied SELECTIVELY, not universally:** Sticky Bomb is linear.
> **Crowbar is linear +75%/stack and explicitly non-diminishing.** Ukulele's proc is a **fixed 25%**
> regardless of stacks — stacks add targets and radius instead. The pattern: **hyperbolic is reserved
> for uncapped *probability* effects at risk of approaching 100%**; bounded magnitudes stay linear.
> *(The stated reason — linear chance "would eventually lead to a 100% chance... totally invulnerable"
> — is the wiki's own editorial, not a Hopoo statement.)*

> **CONCLUSION:** Adopt as vocabulary (README law 7). Anything chance-based and stackable →
> hyperbolic. Flat magnitudes → linear. Don't diminish something that isn't at risk of running away.

---

## 7. Why formulas break — three structural reasons, all of which bite us

> **FINDING (official):** **Non-linearity.** Jake Thornton (*Kings of War*): point systems are
> *"invariably doomed to failure"*, citing uncostable terrain, synergy discounts, and **non-linear
> scaling — "a unit of 20 ≠ 2 units of 10."**
>
> **Bites us directly:** our whole merge threshold assumes two copies = 2× damage. For an AoE weapon
> that overlaps and overkills, it isn't.

> **FINDING (official):** **Combinatorics.** The sharpest case is **Lutri** — Wizards' own words:
> *"the Singleton deck-building restriction is already built into the format rules... Any deck
> including both blue and red would benefit from including Lutri at no deck-building cost. **This isn't
> an oversight or a case where we underestimated a card that was too powerful.**"* A real designed-in
> cost was **silently zeroed by a pre-existing rule.** Also **Splinter Twin**: two independently
> fair-costed cards → a hard infinite.
>
> **Bites us directly:** the slot cap **is** our cost, and it now has three exemptions (granted combo
> synergies, the identity artifact, replacement-when-full). Each is defensible alone. **Audit what they
> sum to.** And our cross-deck combos *are* a designed two-card combo — "pick ONE synergy" is our
> Splinter Twin insurance.

> **FINDING (official):** **Perception.** Sid Meier: *"2/1 is not equal to 20/10."* Josh Noh:
> *"Perception of balance can be more impactful... than the 'true' numerical balance."*
>
> **Bites us directly:** what decides our 1.8× is whether merging *feels* like a reward — not whether
> it's 10% down on a spreadsheet. (README law 1.)

> **FINDING (official):** **Deck context defeats per-item stats.** Slay the Spire's Anthony Giovannetti:
> *"you can't just look at a card and be like, oh, 56% of the time this is in your deck, you win with
> it. That doesn't really contain... what else is in your deck besides that card?"*
>
> **Bites us directly:** we are deck-based. Per-card numbers are structurally incomplete here.

> **FINDING (official):** Rosewater: *"Millions of Magic players will come up with ideas that R&D and
> its playtesters will just miss."* His Oko post-mortem: repeatable effects are the hard ones to
> contain, *"because you can just do them turn after turn"* — which independently confirms our combo
> rule that a synergy may be strong but **never unbounded on its own**.

---

## 8. Source index

Schreiber's course (Levels [3](https://gamebalanceconcepts.wordpress.com/2010/07/21/level-3-transitive-mechanics-and-cost-curves/),
[6](https://gamebalanceconcepts.wordpress.com/2010/08/11/level-6-situational-balance/),
[9](https://gamebalanceconcepts.wordpress.com/2010/09/01/level-9-intransitive-mechanics/),
[10](https://gamebalanceconcepts.wordpress.com/2010/09/08/level-10-final-boss/)) ·
[Rosewater on there being no formula](https://markrosewater.tumblr.com/post/789475407622799360/good-day-is-there-a-mathematical-formula-that-is) ·
[Rosewater, "Do the Math"](https://magic.wizards.com/en/news/making-magic/do-the-math) ·
[Lutri B&R announcement](https://magic.wizards.com/en/news/announcements/april-13-2020-banned-and-restricted-announcement) ·
[Riot Champion Balance Framework](https://nexus.leagueoflegends.com/en-us/2019/05/dev-champion-balance-framework/) ·
[Dan Felder, Game Developer](https://www.gamedeveloper.com/design/design-101-balancing-games) ·
[SimulationCraft docs](https://github.com/simulationcraft/simc/wiki/Output) ·
[PoE Damage](https://www.poewiki.net/wiki/Damage) · [PoE Overkill](https://www.poewiki.net/wiki/Overkill_damage) ·
[PoE Area of effect](https://www.poewiki.net/wiki/Area_of_effect) ·
[Warframe damage calculation](https://wiki.warframe.com/w/Damage/Calculation) ·
[Brotato piercing](https://brotato.wiki.spellsandguns.com/Piercing) ·
[RoR2 item stacking](https://riskofrain2.wiki.gg/wiki/Item_Stacking) ·
[Galante/PC Gamer](https://www.pcgamer.com/vampire-survivors-creator-didnt-have-a-vision-when-he-started-making-the-game-that-allowed-him-to-quit-his-job/) ·
[Josh Noh/Blizzard](https://news.blizzard.com/en-us/overwatch/23652236/inside-overwatch-balance-design-and-the-experimental-card) ·
[Sid Meier GDC 2010](https://gdcvault.com/play/1012186/The-Psychology-of-Game-Design) ·
[Griesemer GDC 2010](https://gdcvault.com/play/1012211/Design-in-Detail-Changing-the) ·
[Thornton on point systems](https://quirkworthy.com/2011/10/15/design-theory-why-points-systems-will-always-be-broken/) ·
[Giovannetti/Slay the Spire](https://hopeinsource.com/games/) ·
[Ham, Game Studies](https://gamestudies.org/1001/articles/ham) ·
[D4 system design](https://news.blizzard.com/en-us/diablo4/23232022/system-design-in-diablo-iv-part-i)

**Worth watching (free):** [Giovannetti, "Slay the Spire: Metrics Driven Design and Balance"](https://www.youtube.com/watch?v=7rqfbvnO_H0)
(telemetry-driven roguelite tuning — the closest structural analog to us) ·
[Jaffe, "Cursed Problems in Game Design"](https://www.youtube.com/watch?v=8uE6-vIi1rQ) ·
[Pecorella, "Quest for Progress: The Math and Design of Idle Games"](https://media.gdcvault.com/gdceurope2016/presentations/Pecorella_Anthony_Quest%20for%20Progress.pdf)
(exponential curve tuning) · [Schreiber, "A Course About Game Balance"](https://www.youtube.com/watch?v=tR-9oXiytsk)

### Could not verify

- Full text of Schreiber & Romero's *Game Balance* (2021) — publisher 403s. Chapter titles only.
- Any leaked MTG cost formula — **no credible provenance; treat as fan invention.**
- Why WoW's pandemic refresh cap is specifically ~30% — mechanic documented, reasoning never stated.
- Whether GGG designed increased/more for the stated reasons — **no developer source found**; the
  "'more' feels special" explanation is community folk-explanation.
- **Noobs Are Coming's weapon-duplicate merge** — unconfirmed after dedicated searching (its wiki is a
  JS app). Its confirmed "Character Merge" fuses *passive kits*, a different mechanic.
