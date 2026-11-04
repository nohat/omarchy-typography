#!/bin/bash
# End-to-end test: apply every available preset, verify each surface, capture
# the live bar and a real notification toast at native scale, then return to
# stock and verify restoration. Nothing here takes keyboard focus.
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
H="${XDG_DATA_HOME:-$HOME/.local/share}/omarchy-typography"   # baseline + venv, created by bin/install
OUT="${1:-$H/test-output}"; mkdir -p "$OUT"
PATH="$ROOT/bin:$PATH"
export OMARCHY_TYPOGRAPHY_QUIET=1
PY="$H/venv/bin/python"
pass=0; fail=0
ok()  { echo "  PASS $*"; pass=$((pass+1)); }
bad() { echo "  FAIL $*"; fail=$((fail+1)); }

fixed_pitch() { # family -> verifies every printable ASCII glyph has one advance width
  local file; file=$(fc-match "$1:style=Regular" -f '%{file}')
  "$PY" -I -c '
import sys; from fontTools.ttLib import TTFont
f=TTFont(sys.argv[1], fontNumber=0); cm=f.getBestCmap(); hm=f["hmtx"]
w={hm[cm[c]][0] for c in range(0x21,0x7f) if c in cm}
sys.exit(0 if len(w)==1 else 1)' "$file"
}

shot() { # name
  grim -g "0,0 2560x26" "$OUT/$1-bar.png"
  notify-send -a Omarchy -t 2500 "Update available" "Omarchy 4.1 is ready — 23 fixes & “Quattro” improvements (≈ 2 min). 0O 1lI rn m"
  sleep 0.9
  grim -g "2150,26 410x96" "$OUT/$1-toast.png"
  sleep 2.2
}

echo "== baseline stock capture"
omarchy-typography stock >/dev/null; sleep 1.5; shot 00-stock

i=1
while IFS=$'\t' read -r id status ui mono; do
  [[ $id == stock ]] && continue
  n=$(printf '%02d-%s' "$i" "$id"); i=$((i+1))
  echo "== $id ($ui + $mono) [$status]"
  if [[ $status == unavailable ]]; then
    if omarchy-typography set "$id" >/dev/null 2>&1; then bad "unavailable preset applied"; else ok "refused unavailable preset (no silent substitution)"; fi
    continue
  fi
  t0=$(date +%s.%N); omarchy-typography set "$id" >/dev/null || bad "set failed"; t1=$(date +%s.%N)
  awk -v a="$t0" -v b="$t1" 'BEGIN{printf "  time %.2fs\n", b-a}'
  if omarchy-typography doctor >"$OUT/.doctor.txt" 2>&1; then ok "doctor"; else bad "doctor"; cat "$OUT/.doctor.txt"; fi
  fixed_pitch "$mono" && ok "$mono is fixed-pitch (terminal cells intact)" || bad "$mono not fixed-pitch"
  [[ $(fc-match monospace -f '%{family[0]}') == "$mono" ]] && ok "monospace alias → $mono" || bad "alias"
  fc-match monospace -f '%{spacing}' | grep -qE '^(90|100)$' && ok "alias still monospaced" || bad "alias proportional!"
  sleep 0.8; shot "$n"
done < <(omarchy-typography list --json | jq -r '.presets[] | [.id,.status,.ui,.mono] | @tsv')

echo "== custom pairing (same UI, different mono companion)"
omarchy-typography custom "Jost" "Geist Mono" >/dev/null && [[ $(omarchy-typography current) == custom ]] && ok "custom Jost + Geist Mono" || bad "custom"
omarchy-typography custom "Jost" "Space Mono" >/dev/null && [[ $(omarchy-typography current) == modernist-classic ]] && ok "custom matching a preset resolves to that preset" || bad "custom→preset"

echo "== refuses a proportional font as monospace"
omarchy-typography custom "Jost" "Outfit" >/dev/null 2>&1 && bad "accepted Outfit as mono" || ok "rejected Outfit as monospace role"

echo "== restore stock"
omarchy-typography stock >/dev/null
omarchy-typography doctor >"$OUT/.doctor.txt" 2>&1 && ok "stock doctor" || { bad "stock doctor"; cat "$OUT/.doctor.txt"; }
B="$H/baseline/files/.config"
for f in alacritty/alacritty.toml foot/foot.ini ghostty/config kitty/kitty.conf; do
  cmp -s "$HOME/.config/$f" "$B/$f" && ok "$f byte-identical to baseline" || bad "$f differs from baseline"
done
[[ ! -e $HOME/.config/fontconfig/fonts.conf ]] && ok "fonts.conf removed (as baseline)" || bad "fonts.conf remains"
[[ $(gsettings get org.gnome.desktop.interface font-name) == "'$(jq -r '.gsettings["font-name"]' "$H/baseline/manifest.json")'" ]] && ok "GTK font-name baseline" || bad "GTK font-name"
[[ $(gsettings get org.gnome.desktop.interface monospace-font-name) == "'$(jq -r '.gsettings["monospace-font-name"]' "$H/baseline/manifest.json")'" ]] && ok "GTK mono baseline" || bad "GTK mono"
sleep 1.5; shot 99-stock-restored

echo; echo "passed $pass, failed $fail"
(( fail == 0 ))
