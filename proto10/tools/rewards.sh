#!/bin/sh
# 報酬ごとの価値を4並列で測って表にする。 sh tools/rewards.sh [回数] [出力先]
N=${1:-160}; OUT=${2:-/tmp}
cd "$(dirname "$0")/.."
for i in 0 1 2 3; do node tools/rewards.js "$N" - "$i/4" > "$OUT/rw-$i.json" & done
wait
cat "$OUT"/rw-?.json | node -e '
const E = require("./engine.js");
const rows = require("fs").readFileSync(0, "utf8").trim().split("\n").map((l) => JSON.parse(l));
for (const h of E.HEROES) {
  const rs = rows.filter((r) => r.hero === h.id);
  const base = rs.find((r) => r.kind === "base"); const b = base.won / base.n;
  console.log(`■ ${h.name}（報酬なし ${(b * 100).toFixed(0)}%、${base.n}回）`);
  const d = (r) => `${((r.won / r.n - b) * 100 >= 0 ? "+" : "")}${((r.won / r.n - b) * 100).toFixed(0)}`;
  console.log("  " + rs.filter((r) => r.kind === "up" || r.kind === "hp").map((r) => `${r.label} ${d(r)}`).join(" / "));
  for (const c of E.CARDS.filter((x) => x.hero === h.id && x.extra)) {
    const cs = rs.filter((r) => r.card === c.id).sort((x, y) => y.won / y.n - x.won / x.n);
    console.log(`  ${c.name}: ` + cs.map((r) => `${E.CARD[r.old].name}と交換 ${d(r)}`).join(" / "));
  }
}'
