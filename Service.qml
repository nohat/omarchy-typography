import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Applies the UI role to the whole shell.
//
// Every shell surface binds its font family to Style.fontFamily, which stock
// Omarchy leaves at the fontconfig "monospace" alias. This service reassigns
// that one property from ~/.config/omarchy/typography/state.json (written by
// omarchy-typography) and puts the original value back for the "stock"
// preset, when the state file disappears, or when the plugin is unloaded.
// Nothing else (colours, sizes, spacing, theme) is touched.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  readonly property string statePath: Quickshell.env("HOME") + "/.config/omarchy/typography/state.json"
  property string stockFamily: ""
  property bool overriding: false

  function family(state) {
    if (!state || typeof state !== "object") return ""
    if (String(state.preset || "stock") === "stock") return ""
    var f = String(state.shellFamily || state.ui || "")
    // Family names only: bounded, no control characters.
    if (f.length === 0 || f.length > 96 || /[\u0000-\u001f]/.test(f)) return ""
    return f
  }

  function restore() {
    if (!overriding) return
    Style.fontFamily = stockFamily
    overriding = false
  }

  function apply(raw, missing) {
    if (missing) { restore(); return }
    var text = String(raw || "")
    // A half-written file parses as nothing; keep the current family until it settles.
    if (text.replace(/\s+/g, "").length === 0) return
    var state
    try { state = JSON.parse(text) } catch (e) { return }
    var f = family(state)
    if (f === "") { restore(); return }
    if (!overriding) { stockFamily = Style.fontFamily; overriding = true }
    if (Style.fontFamily !== f) Style.fontFamily = f
  }

  FileView {
    path: root.statePath
    watchChanges: true
    printErrors: false
    onLoaded: root.apply(text(), false)
    onFileChanged: reload()
    onLoadFailed: root.apply("", true)
  }

  Component.onDestruction: restore()
}
