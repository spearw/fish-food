#!/usr/bin/env bash
## Balance sweep: measures EVERY weapon across the measurable enemy archetypes, then hands the CSV to
## balance_sweep_analyze.gd -- double normalization -> proposed counter-grid entries.
## See .claude/balance/workflow.md ("The counter-grid pipeline").
##
##   ./balance_sweep.sh [secs_per_run] [weapon_filter_regex]
##
## Columns swept are the CLEAN axes only (frozen, immortal): baseline + the armor ladder.
##   - swarm/tanky need mortal mode (immortal erases HP) -- noisier; add behind a flag when needed.
##   - fast/evasive/ranged are BLOCKED until chase-and-recycle motion lands (the bench overrides AI,
##     and the orbit model measured speed backwards).
##
## The harness PROPOSES; it never writes the grid. Feel is law -- proposals get hand-reviewed.
set -u
GODOT="${GODOT:-C:/Godot/Godot_v4.4.1-stable_win64_console.exe}"
SECS="${1:-10}"
FILTER="${2:-.}"
OUT="bench_results/sweep.csv"
ARCHETYPES="baseline armor10 armor25"

mkdir -p bench_results
echo "weapon_path,archetype,dps" > "$OUT"

WEAPONS=$(find systems/upgrades/weapons -name "*unlock*.tres" | sort | grep -E "$FILTER")
total=$(echo "$WEAPONS" | wc -l)
echo "SWEEP: $total weapons x [$ARCHETYPES] at ${SECS}s per run"

for w in $WEAPONS; do
  name=$(basename "$w" .tres)
  for a in $ARCHETYPES; do
    line=$(timeout 90 "$GODOT" --headless --path . res://balance_bench.tscn -- \
      --weapon="res://$w" --archetype="$a" --secs="$SECS" --motion=frozen 2>/dev/null \
      | grep -oE "dps=[0-9.]+" | head -1)
    dps="${line#dps=}"
    [ -z "$dps" ] && dps="NA"
    echo "$w,$a,$dps" >> "$OUT"
    printf "  %-40s %-9s %s\n" "$name" "$a" "$dps"
  done
done

echo "SWEEP: done -> $OUT"
"$GODOT" --headless --path . res://balance_sweep_analyze.tscn -- --csv="$OUT"
