#!/usr/bin/env bash
# Monta uma cópia do painel admin com dados fictícios em <pasta> (padrão: build/admin-preview).
# Não altera admin/ e não fala com o Firebase.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:-$root/build/admin-preview}"
rm -rf "$out" && mkdir -p "$out"
cp "$root"/admin/* "$out"/
cp "$root"/tool/admin-demo/demo-data.js "$out"/
python3 - "$out/index.html" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
s = s.replace('<script type="module" src="admin.js', '<script>globalThis.PAGO_ADMIN_DEMO = true;</script>\n    <script type="module" src="admin.js', 1)
open(p, "w", encoding="utf-8").write(s)
PY
echo "Prévia do admin em $out (abra index.html por um servidor local)."
