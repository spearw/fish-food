#!/usr/bin/env bash
## Balance sweep: measures EVERY weapon across the measurable enemy archetypes, then hands the CSV to
## balance_sweep_analyze.gd -- double normalization -> proposed counter-grid entries.
## See .claude/balance/workflow.md ("The counter-grid pipeline").
##
##   ./balance_sweep.sh [secs_per_run] [weapon_filter_regex]
##   MORTAL=1 ./balance_sweep.sh ...   adds the kill-throughput columns (see below)
##
## Columns swept by default are the CLEAN axes (frozen, immortal): baseline + the armor ladder.
## MORTAL=1 adds mortal-mode columns -- real deaths, slot-refilled field, kills/sec:
##   - mortal_baseline: the anchor mortal ratios normalize against (kills/sec vs dps is nonsense)
##   - mortal_tanky:    max_health x6.7 -- what overkill waste actually costs
##   - mortal_regen:    regen_per_sec 8 (the sea star's value) -- the DoT-counter race, measurable
##                      ONLY here: immortal's HP flood gates the heal off entirely
## Mortal columns are noisier (kill quantization: dummies spawn LARGE at x1.6 HP, so kills come
## slowly -- DoT weapons especially), so they run at 4x secs. secs must be an integer; for a
## serious mortal sweep pass secs>=15 so each mortal window sims 60s+ and collects enough kills.
##   - fast/evasive/ranged are BLOCKED until chase-and-recycle motion lands (the bench overrides AI,
##     and the orbit model measured speed backwards).
##
## The harness PROPOSES; it never writes the grid. Feel is law -- proposals get hand-reviewed.
set -u
GODOT="${GODOT:-C:/Godot/Godot_v4.4.1-stable_win64_console.exe}"
SECS="${1:-10}"
FILTER="${2:-.}"
MORTAL="${MORTAL:-0}"
OUT="bench_results/sweep.csv"
ARCHETYPES="baseline armor10 armor25"
MORTAL_ARCHETYPES="baseline tanky regen"

mkdir -p bench_results
echo "weapon_path,archetype,value" > "$OUT"

WEAPONS=$(find systems/upgrades/weapons -name "*unlock*.tres" | sort | grep -E "$FILTER")
total=$(echo "$WEAPONS" | wc -l)
mortal_note=""
[ "$MORTAL" = "1" ] && mortal_note=" + mortal [$MORTAL_ARCHETYPES] at $((SECS * 4))s"
echo "SWEEP: $total weapons x [$ARCHETYPES] at ${SECS}s per run$mortal_note"

for w in $WEAPONS; do
  name=$(basename "$w" .tres)
  for a in $ARCHETYPES; do
    line=$(timeout 90 "$GODOT" --headless --path . res://balance_bench.tscn -- \
      --weapon="res://$w" --archetype="$a" --secs="$SECS" --motion=frozen 2>/dev/null \
      | grep -oE "dps=[0-9.]+" | head -1)
    dps="${line#dps=}"
    [ -z "$dps" ] && dps="NA"
    echo "$w,$a,$dps" >> "$OUT"
    printf "  %-40s %-16s %s\n" "$name" "$a" "$dps"
  done
  if [ "$MORTAL" = "1" ]; then
    for a in $MORTAL_ARCHETYPES; do
      line=$(timeout 300 "$GODOT" --headless --path . res://balance_bench.tscn -- \
        --weapon="res://$w" --archetype="$a" --secs=$((SECS * 4)) --motion=frozen --immortal=0 2>/dev/null \
        | grep -oE "kills_per_sec=[0-9.]+" | head -1)
      kps="${line#kills_per_sec=}"
      [ -z "$kps" ] && kps="NA"
      echo "$w,mortal_$a,$kps" >> "$OUT"
      printf "  %-40s %-16s %s\n" "$name" "mortal_$a" "$kps"
    done
  fi
done

echo "SWEEP: done -> $OUT"
"$GODOT" --headless --path . res://balance_sweep_analyze.tscn -- --csv="$OUT"
