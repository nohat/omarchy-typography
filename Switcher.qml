import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Typography switcher: preset list, live specimen preview, A/B comparison,
// monospace-companion cycling and a custom pairing. All state changes go
// through the omarchy-typography CLI, which is the single source of truth.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  // The CLI ships in this plugin's folder; resolvedUrl may use a qs:// or file:// scheme.
  readonly property string cli: decodeURIComponent(String(Qt.resolvedUrl("bin/omarchy-typography")).replace(/^[a-z]+:\/\//, ""))

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  property bool opened: false
  property var data: ({ presets: [], families: { ui: [], mono: [] }, active: "stock", state: {} })
  property var presets: data.presets || []
  // Rows: every preset, then the custom pairing.
  readonly property int rowCount: presets.length + 1
  property int selectedIndex: 0
  property bool compare: false
  property string pinA: ""
  property string pinB: ""
  property bool busy: false
  property string message: ""
  // Mono companion override for the previewed preset ("" = the preset's own).
  property int monoOffset: 0
  property string customUi: ""
  property string customMono: ""

  readonly property color background: Commons.Color.menu.background
  readonly property color foreground: Commons.Color.menu.text
  readonly property color dim: Util.alpha(Commons.Color.menu.text, 0.6)
  readonly property color border: Commons.Color.menu.border
  readonly property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  readonly property color selectedBackground: Commons.Color.menu.selectedBackground
  readonly property color selectedText: Commons.Color.menu.selectedText
  readonly property string fontFamily: Style.font.menuFamily

  // ---------------------------------------------------------------- data

  function presetAt(i) { return (i >= 0 && i < presets.length) ? presets[i] : null }
  function presetById(id) {
    for (var i = 0; i < presets.length; i++) if (presets[i].id === id) return presets[i]
    return null
  }
  function isCustomRow(i) { return i === presets.length }

  function tabularFamily(ui) {
    var f = ui + " Tabular"
    var all = installed
    return all.indexOf(f) !== -1 ? f : ui
  }
  property var installed: []

  // Monospace companions: every preset mono first (in table order), then the rest.
  readonly property var monoChoices: {
    var out = []
    for (var i = 0; i < presets.length; i++) {
      var m = presets[i].mono
      if (m && presets[i].status !== "unavailable" && out.indexOf(m) === -1) out.push(m)
    }
    var fam = (data.families && data.families.mono) || []
    for (var j = 0; j < fam.length; j++) if (out.indexOf(fam[j]) === -1) out.push(fam[j])
    return out
  }
  function companion(baseMono) {
    if (monoOffset === 0 || monoChoices.length === 0) return baseMono
    var at = monoChoices.indexOf(baseMono)
    if (at < 0) at = 0
    var n = monoChoices.length
    return monoChoices[(((at + monoOffset) % n) + n) % n]
  }

  // Families to render a row with; null when it can't be previewed truthfully.
  function pairingFor(i) {
    if (isCustomRow(i)) {
      if (!customUi || !customMono) return null
      return { name: strings.t("custom"), ui: customUi, mono: customMono, shell: tabularFamily(customUi) }
    }
    var p = presetAt(i)
    if (!p || p.status === "unavailable") return null
    if (p.id === "stock") {
      // Stock draws the shell with the monospace alias, as Omarchy does.
      var sm = "JetBrainsMono Nerd Font"
      return { name: p.name, ui: sm, mono: sm, shell: sm }
    }
    return { name: p.name, ui: p.ui, mono: p.mono, shell: tabularFamily(p.ui) }
  }

  function load() { listProc.running = true }

  Process {
    id: listProc
    command: [root.cli, "list", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text)
          root.data = d
          if (root.customUi === "") root.customUi = (d.state && d.state.ui) || "Jost"
          if (root.customMono === "") root.customMono = (d.state && d.state.mono) || "JetBrains Mono"
          if (!root.opened) return
          for (var i = 0; i < d.presets.length; i++) if (d.presets[i].active) root.selectedIndex = i
          if (d.active === "custom") root.selectedIndex = d.presets.length
          root.applyPayload()
        } catch (e) {
          root.message = "omarchy-typography list failed"
        }
      }
    }
  }
  Process {
    id: famProc
    command: ["fc-list", ":", "family"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var out = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].split(",")
          for (var j = 0; j < parts.length; j++) { var f = parts[j].trim(); if (f && out.indexOf(f) === -1) out.push(f) }
        }
        root.installed = out
      }
    }
  }
  Process {
    id: applyProc
    property var args: []
    command: [root.cli].concat(args)
    stderr: StdioCollector { id: applyErr; waitForEnd: true }
    onExited: function(code) {
      root.busy = false
      root.message = code === 0 ? "" : (applyErr.text || "").split("\n")[0]
      root.load()
    }
  }

  function run(args) {
    if (busy) return
    busy = true
    message = strings.t("applying")
    applyProc.args = args
    applyProc.running = true
  }

  function applySelected() {
    if (isCustomRow(selectedIndex)) { run(["custom", customUi, customMono]); return }
    var p = presetAt(selectedIndex)
    if (!p) return
    if (p.status === "unavailable") { message = p.detail; return }
    if (monoOffset !== 0 && p.id !== "stock") { run(["custom", p.ui, companion(p.mono)]); return }
    run(["set", p.id])
  }

  // ---------------------------------------------------------------- lifecycle

  // Optional payload, e.g. for scripted screenshots:
  //   {"select":"modernist-classic","pinA":"…","pinB":"…","compare":true,"monoOffset":1}
  property var pendingPayload: ({})
  function applyPayload() {
    var p = pendingPayload || {}
    if (p.pinA) pinA = String(p.pinA)
    if (p.pinB) pinB = String(p.pinB)
    if (p.compare === true) compare = true
    if (p.select) {
      if (p.select === "custom") selectedIndex = presets.length
      else for (var i = 0; i < presets.length; i++) if (presets[i].id === p.select) selectedIndex = i
    }
    if (typeof p.monoOffset === "number") monoOffset = p.monoOffset
    pendingPayload = ({})
  }

  function open(payloadJson) {
    opened = true
    compare = false
    monoOffset = 0
    message = ""
    try { pendingPayload = JSON.parse(payloadJson || "{}") || {} } catch (e) { pendingPayload = ({}) }
    famProc.running = true
    load()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  function close() { opened = false }
  function dismiss() {
    opened = false
    if (shell && typeof shell.hide === "function" && manifest && manifest.id) shell.hide(manifest && manifest.id)
  }

  function move(delta) {
    selectedIndex = Math.max(0, Math.min(rowCount - 1, selectedIndex + delta))
    monoOffset = 0
    list.positionViewAtIndex(selectedIndex, ListView.Contain)
  }
  function pin(slot) {
    var id = isCustomRow(selectedIndex) ? "custom" : (presetAt(selectedIndex) || {}).id
    if (!id) return
    if (slot === "A") pinA = id; else pinB = id
    if (pinA && pinB) compare = true
  }
  function pinnedPairing(id) {
    if (id === "custom") return pairingFor(presets.length)
    for (var i = 0; i < presets.length; i++) if (presets[i].id === id) return pairingFor(i)
    return null
  }

  OverlayWindow {
    id: panel
    shown: root.opened
    WlrLayershell.namespace: "omarchy-typography"

    Rectangle { anchors.fill: parent; color: Commons.Color.menu.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    BorderSurface {
      id: card
      width: Math.min(Style.space(1240), panel.width - Style.gapsOut * 4)
      height: Math.min(Style.space(880), panel.height - Style.gapsOut * 4)
      anchors.centerIn: parent
      radius: Style.cornerRadius
      color: root.background
      borderSpec: root.borderSpec
      padding: Style.spacing.panelPadding

      MouseArea { anchors.fill: parent; onClicked: keyCatcher.forceActiveFocus() }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (uiPick.popupOpen || monoPick.popupOpen) return
          var k = event.key
          if (k === Qt.Key_Escape) { if (root.compare) root.compare = false; else root.dismiss() }
          else if (k === Qt.Key_Up) root.move(-1)
          else if (k === Qt.Key_Down) root.move(1)
          else if (k === Qt.Key_PageUp) root.move(-6)
          else if (k === Qt.Key_PageDown) root.move(6)
          else if (Util.readingKey(event) === Qt.Key_Left) root.monoOffset -= 1
          else if (Util.readingKey(event) === Qt.Key_Right) root.monoOffset += 1
          else if (k === Qt.Key_Tab) root.compare = !root.compare && root.pinA !== "" && root.pinB !== ""
          else if (k === Qt.Key_A) root.pin("A")
          else if (k === Qt.Key_B) root.pin("B")
          else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.applySelected()
          else return
          event.accepted = true
        }
      }

      Item {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

        // ------------------------------------------------------------ header
        Item {
          id: header
          width: parent.width
          height: Style.space(34)
          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            text: strings.t("title")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
          }
          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.md
            Text {
              textFormat: Text.PlainText
              anchors.verticalCenter: parent.verticalCenter
              text: {
                var p = root.presetById(root.data.active)
                var name = p ? p.name : strings.t("custom")
                if (root.data.active === "custom" && root.data.state) name += " — " + root.data.state.ui + " + " + root.data.state.mono
                return strings.t("active").arg(name)
              }
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Button {
              text: root.compare ? strings.t("preview") : strings.t("compare")
              bordered: true
              fontFamily: root.fontFamily
              onClicked: root.compare = !root.compare
            }
            Button {
              text: strings.t("original")
              bordered: true
              fontFamily: root.fontFamily
              onClicked: root.run(["stock"])
            }
          }
        }

        // ------------------------------------------------------------ preset list
        ListView {
          id: list
          anchors.top: header.bottom
          anchors.topMargin: Style.spacing.lg
          anchors.bottom: footer.top
          anchors.bottomMargin: Style.spacing.lg
          width: Style.space(300)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          model: root.rowCount
          delegate: Rectangle {
            id: rowItem
            required property int index
            readonly property var preset: root.presetAt(index)
            readonly property bool custom: root.isCustomRow(index)
            readonly property bool current: index === root.selectedIndex
            readonly property bool active: custom ? root.data.active === "custom" : (preset && preset.active === true)
            readonly property bool unavailable: !custom && preset && preset.status === "unavailable"
            readonly property string rowId: custom ? "custom" : (preset ? preset.id : "")
            width: list.width
            height: Style.space(44)
            radius: Math.max(0, Style.cornerRadius - 2)
            color: current ? root.selectedBackground : "transparent"

            Text {
              id: activeMark
              textFormat: Text.PlainText
              x: Style.spacing.md
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(12)
              text: rowItem.active ? "●" : ""
              color: root.selectedText
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Column {
              anchors.left: activeMark.right
              anchors.leftMargin: Style.spacing.sm
              anchors.right: badges.left
              anchors.rightMargin: Style.spacing.sm
              anchors.verticalCenter: parent.verticalCenter
              Text {
                textFormat: Text.PlainText
                width: parent.width
                elide: Text.ElideRight
                text: rowItem.custom ? strings.t("custom") : (rowItem.preset ? rowItem.preset.name : "")
                color: rowItem.current ? root.selectedText : root.foreground
                opacity: rowItem.unavailable ? 0.5 : 1
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
              Text {
                textFormat: Text.PlainText
                width: parent.width
                elide: Text.ElideRight
                text: {
                  if (rowItem.custom) return root.customUi + " + " + root.customMono
                  var p = rowItem.preset
                  if (!p) return ""
                  if (p.id === "stock") return "JetBrainsMono Nerd Font"
                  if (p.status === "unavailable") return p.requested.ui + " + " + p.requested.mono
                  return p.ui + " + " + p.mono
                }
                color: root.dim
                opacity: rowItem.unavailable ? 0.6 : 1
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
            Row {
              id: badges
              anchors.right: parent.right
              anchors.rightMargin: Style.spacing.md
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.xs
              Repeater {
                model: [
                  { t: "A", on: root.pinA !== "" && root.pinA === rowItem.rowId },
                  { t: "B", on: root.pinB !== "" && root.pinB === rowItem.rowId },
                  { t: "", on: rowItem.unavailable },
                  { t: "≈", on: !rowItem.custom && rowItem.preset && rowItem.preset.status === "substituted" }
                ]
                delegate: Rectangle {
                  required property var modelData
                  visible: modelData.on
                  width: Style.space(18); height: Style.space(18)
                  radius: Style.space(3)
                  color: "transparent"
                  border.width: 1
                  border.color: Util.alpha(root.foreground, 0.35)
                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: modelData.t
                    color: root.dim
                    font.family: modelData.t === "" ? "Symbols Nerd Font" : root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }
            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onClicked: function(mouse) {
                root.selectedIndex = rowItem.index
                root.monoOffset = 0
                keyCatcher.forceActiveFocus()
              }
              onDoubleClicked: root.applySelected()
            }
          }
        }

        // ------------------------------------------------------------ preview pane
        Item {
          id: pane
          anchors.left: list.right
          anchors.leftMargin: Style.spacing.panelGap
          anchors.right: parent.right
          anchors.top: header.bottom
          anchors.topMargin: Style.spacing.lg
          anchors.bottom: footer.top
          anchors.bottomMargin: Style.spacing.lg

          readonly property var single: root.pairingFor(root.selectedIndex)
          readonly property var leftPair: root.compare ? root.pinnedPairing(root.pinA) : single
          readonly property var rightPair: root.compare ? root.pinnedPairing(root.pinB) : null

          // Controls row: the previewed pairing and its monospace companion.
          Item {
            id: controls
            width: parent.width
            height: Style.spacing.controlHeight + Style.spacing.huge
            visible: !root.compare

            Row {
              visible: !root.isCustomRow(root.selectedIndex)
              anchors.bottom: parent.bottom
              spacing: Style.spacing.lg
              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                text: pane.single ? pane.single.name : ""
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }
              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                visible: pane.single !== null && root.presetAt(root.selectedIndex) && root.presetAt(root.selectedIndex).id !== "stock"
                text: pane.single ? strings.t("monoCompanion") + ":  ‹ " + root.companion(pane.single.mono) + " ›" + (root.monoOffset !== 0 ? "  (preview only — Enter applies as custom)" : "") : ""
                color: root.monoOffset !== 0 ? root.selectedText : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
              Text {
                textFormat: Text.PlainText
                anchors.verticalCenter: parent.verticalCenter
                visible: { var p = root.presetAt(root.selectedIndex); return !!(p && p.note) }
                text: { var p = root.presetAt(root.selectedIndex); return p && p.note ? "· " + strings.t("noTabular") : "" }
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }

            Row {
              visible: root.isCustomRow(root.selectedIndex)
              spacing: Style.spacing.lg
              SearchableDropdown {
                id: uiPick
                label: strings.t("uiFont")
                options: (root.data.families && root.data.families.ui) || []
                value: root.customUi
                fontFamily: root.fontFamily
                onChanged: function(v) { root.customUi = v; keyCatcher.forceActiveFocus() }
              }
              SearchableDropdown {
                id: monoPick
                label: strings.t("monoFont")
                options: (root.data.families && root.data.families.mono) || []
                value: root.customMono
                fontFamily: root.fontFamily
                onChanged: function(v) { root.customMono = v; keyCatcher.forceActiveFocus() }
              }
              Button {
                anchors.bottom: parent.bottom
                text: strings.t("apply")
                bordered: true
                fontFamily: root.fontFamily
                onClicked: root.run(["custom", root.customUi, root.customMono])
              }
            }
          }

          Flickable {
            id: flick
            anchors.top: root.compare ? parent.top : controls.bottom
            anchors.topMargin: Style.spacing.lg
            anchors.bottom: parent.bottom
            width: parent.width
            clip: true
            contentHeight: Math.max(leftCol.implicitHeight, rightCol.visible ? rightCol.implicitHeight : 0)
            boundsBehavior: Flickable.StopAtBounds

            Row {
              id: sheets
              width: flick.width
              spacing: Style.spacing.panelGap
              readonly property int colWidth: root.compare ? (width - spacing) / 2 : width

              Column {
                id: leftCol
                width: sheets.colWidth
                spacing: Style.spacing.lg
                Text {
                  visible: root.compare
                  textFormat: Text.PlainText
                  text: pane.leftPair ? "A — " + pane.leftPair.name + "   " + pane.leftPair.ui + " + " + pane.leftPair.mono : "A — press A on a preset"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }
                SampleSheet {
                  visible: pane.leftPair !== null
                  width: parent.width
                  columns: root.compare ? 1 : 2
                  uiFamily: pane.leftPair ? pane.leftPair.ui : ""
                  shellFamily: pane.leftPair ? pane.leftPair.shell : ""
                  monoFamily: pane.leftPair ? (root.compare ? pane.leftPair.mono : root.companion(pane.leftPair.mono)) : ""
                }
                Text {
                  // Unavailable presets are never rendered with a stand-in font.
                  visible: pane.leftPair === null && !root.compare
                  width: parent.width
                  wrapMode: Text.Wrap
                  textFormat: Text.PlainText
                  text: {
                    var p = root.presetAt(root.selectedIndex)
                    if (root.isCustomRow(root.selectedIndex)) return strings.t("customHint")
                    return p ? strings.t("unavailable") + " — " + (p.detail || "") : ""
                  }
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
              }
              Column {
                id: rightCol
                visible: root.compare
                width: sheets.colWidth
                spacing: Style.spacing.lg
                Text {
                  textFormat: Text.PlainText
                  text: pane.rightPair ? "B — " + pane.rightPair.name + "   " + pane.rightPair.ui + " + " + pane.rightPair.mono : "B — press B on a preset"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }
                SampleSheet {
                  visible: pane.rightPair !== null
                  width: parent.width
                  uiFamily: pane.rightPair ? pane.rightPair.ui : ""
                  shellFamily: pane.rightPair ? pane.rightPair.shell : ""
                  monoFamily: pane.rightPair ? pane.rightPair.mono : ""
                }
              }
            }
          }
        }

        // ------------------------------------------------------------ footer
        Item {
          id: footer
          anchors.bottom: parent.bottom
          width: parent.width
          height: Style.space(22)
          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.5
            elide: Text.ElideRight
            text: root.message
            color: root.selectedText
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          Text {
            textFormat: Text.PlainText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: strings.t("hints")
            color: root.dim
            // Key names are the monospace role.
            font.family: (root.data.state && root.data.state.mono) || "monospace"
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
