## glossary.gd -- the keyword system behind card text (the Slay the Spire / Monster Train pattern):
## reusable terms keep the card FACE short, and the hover tooltip defines every keyword the card
## touches. One definition per concept, written once, shown everywhere -- when a mechanic changes,
## its definition changes in exactly one place.
## Preload pattern (no class_name): const Glossary := preload("res://systems/global/glossary.gd")
extends RefCounted

## One-line definitions, keyed by the player-facing keyword.
const KEYWORDS := {
	"Poison": "Damage over time, stacking to 5. Each stack adds a full set of ticks. Ticks ignore armor.",
	"Burn": "Damage over time. Hitting again refreshes the timer. Ticks ignore armor.",
	"Ignite": "A fiercer burn. Burning enemies have a chance to escalate into it.",
	"Spark": "A small bolt that bounces between nearby enemies until spent.",
	"Pierce": "Passes through enemies, hitting each one along the way.",
	"Armor": "Flat soak per hit. A hit at or under the armor value deals nothing.",
	"Armor Pen": "A share of the target's armor is ignored.",
	"Regeneration": "Constant healing. Damage over time races it; direct hits beat it.",
	"Crit": "A chance to multiply the hit. Character crit adds base chance to every damage source.",
	"Merge": "Two same-tier copies fuse into one a tier higher, freeing a slot.",
	"Evolution": "A rework of a weapon's core design. One evolution per weapon per run.",
	"Granted": "Earned, not drafted. Costs no loadout slot.",
	"Combo": "A cross-deck synergy. One per run; the depths hide a way to earn a second.",
	"Slow": "Reduces the target's move speed while active.",
	"Homing": "Steers toward its target.",
	"Knockback": "Pushes the target away on hit.",
	"Area": "Hits everything in a zone. Scales with area size.",
	"Chip": "Always deals at least a share of raw damage, even through armor.",
	"Stacks": "Repeat applications pile up, multiplying the effect.",
}

## Card-face labels for weapon effect tags. Absent entries stay off the face (identity noise).
const EFFECT_LABELS := {
	WeaponTags.Effect.DOT: "DoT",
	WeaponTags.Effect.SLOW: "Slow",
	WeaponTags.Effect.CHAIN: "Spark",
	WeaponTags.Effect.PIERCE: "Pierce",
	WeaponTags.Effect.AOE: "Area",
	WeaponTags.Effect.KNOCKBACK: "Knockback",
	WeaponTags.Effect.HOMING: "Homing",
	WeaponTags.Effect.EXPLOSIVE: "Area",
	WeaponTags.Effect.ARMOR_PEN: "Armor Pen",
	WeaponTags.Effect.SPARK: "Spark",
	WeaponTags.Effect.MELEE: "Melee",
	WeaponTags.Effect.HIGH_FIRE_RATE: "Rapid",
	WeaponTags.Effect.SINGLE_TARGET: "Focused",
	WeaponTags.Effect.LONG_RANGE: "Long Range",
}

## Tooltip definitions for face labels that are not glossary keywords themselves.
const LABEL_NOTES := {
	"DoT": "Damage over time. Ticks ignore armor; regeneration races them.",
	"Rapid": "Many small hits. Armor eats them; regeneration cannot keep up.",
	"Focused": "Big single hits. Punches through armor thresholds.",
	"Melee": "Close range, unlimited cleave through whatever stands in the arc.",
	"Long Range": "Reaches across the screen.",
}

## The card-face keyword row for a weapon's effect tags: "[Pierce] [DoT]". Deduped, order-stable.
static func keyword_row(effects: Array) -> String:
	var labels: Array = []
	for effect in effects:
		var label = EFFECT_LABELS.get(effect)
		if label != null and not label in labels:
			labels.append(label)
	if labels.is_empty():
		return ""
	return "[" + "] [".join(labels) + "]"

## The hover tooltip: the card's prose, then one definition line per keyword the card touches --
## scanned from the text and from the effect tags. Progressive disclosure: the face stays short
## because THIS is where the detail lives.
static func tooltip_for(description: String, effects: Array = []) -> String:
	var lines: Array = []
	if description.strip_edges() != "":
		lines.append(description.strip_edges())
	var seen: Array = []
	var lower := description.to_lower()
	for keyword in KEYWORDS:
		if keyword.to_lower() in lower and not keyword in seen:
			seen.append(keyword)
	for effect in effects:
		var label = EFFECT_LABELS.get(effect)
		if label == null or label in seen:
			continue
		if KEYWORDS.has(label) or LABEL_NOTES.has(label):
			seen.append(label)
	if not seen.is_empty():
		lines.append("")
		for keyword in seen:
			var note: String = KEYWORDS.get(keyword, LABEL_NOTES.get(keyword, ""))
			if note != "":
				lines.append("%s: %s" % [keyword, note])
	return "\n".join(lines)
