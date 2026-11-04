#!/bin/bash
# Usage: capture-switcher.sh <out.png> '<payload-json>'
# Opens the switcher with a payload, captures the focused monitor at native
# scale, and closes it again (open for ~1 s).
out=$1; payload=${2:-'{}'}
id=$(jq -r .id "$(dirname "$(readlink -f "$0")")/../manifest.json")
omarchy-shell shell summon "$id" "$payload" >/dev/null
sleep 1.0
grim "$out"
omarchy-shell shell hide "$id" >/dev/null
