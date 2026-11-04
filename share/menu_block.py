"""Insert the Appearance > Typography rows into omarchy-menu.jsonc (idempotent).

usage: menu_block.py <omarchy-menu.jsonc> <presets.json> <cli-path>
The block sits between marker comments so `omarchy-typography uninstall`
can remove exactly what was added.
"""
import json
import os
import shlex
import sys

path, presets_path, cli = sys.argv[1], sys.argv[2], shlex.quote(sys.argv[3])
presets = json.load(open(presets_path))["presets"]
FONT = ""


def row(key, data):
    return f'  "appearance.typography{key}": ' + json.dumps(data, ensure_ascii=False) + ","


lines = [
    "  // omarchy-typography >>> (generated; removed by `omarchy-typography uninstall`)",
    row("", {"icon": FONT, "label": "Typography", "description": "Proportional UI and monospace font pairings"}),
    row(".switcher", {"icon": "", "label": "Compare & Switch…", "description": "Live previews, A/B comparison, custom pairing",
                      "action": f"{cli} switcher"}),
]
for p in presets:
    if p["id"] == "stock":
        lines.append(row(".stock", {"icon": "", "label": "Original Omarchy", "description": "Stock typography",
                                    "checked": f"{cli} is stock", "action": f"{cli} stock"}))
        continue
    desc = f"{p['ui'][0]} + {p['mono'][0]}"
    data = {"icon": FONT, "label": p["name"], "description": desc,
            "checked": f"{cli} is {p['id']}", "action": f"{cli} set {p['id']}"}
    if p.get("commercial"):
        data["description"] = desc + " — commercial fonts, unavailable until imported"
        data["disabled"] = f"! {cli} available {p['id']}"
    lines.append(row("." + p["id"], data))
lines.append("  // <<< omarchy-typography")

text = open(path).read() if os.path.exists(path) else "{\n}\n"
if "omarchy-typography >>>" in text:
    sys.exit(0)
end = text.rstrip().rfind("}")
if end < 0:
    sys.exit(f"{path}: no closing brace; not editing it")
with open(path, "w") as out:
    out.write(text[:end] + "\n".join(lines) + "\n" + text[end:])
