#!/bin/sh
# 4並列でシミュレーションして集計する。  sh tools/run.sh [1組あたりの回数] [mode] [出力先のフォルダ]
N=${1:-30}; MODE=${2:-strong}; OUT=${3:-/tmp}
cd "$(dirname "$0")/.."
for i in 0 1 2 3; do node tools/sim.js "$N" "$MODE" "$i/4" > "$OUT/sim-$MODE-$i.json" & done
wait
node tools/report.js "$OUT"/sim-"$MODE"-?.json
