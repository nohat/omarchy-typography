import QtQuick
import qs.Commons
import qs.Commons as Commons

// One specimen of representative Omarchy typography for a pairing.
// Content, sizes, weights, spacing and colours are fixed; only the three
// family properties vary, so the typeface is the independent variable.
Item {
  id: sheet

  property string uiFamily: ""
  // What the shell actually draws with: the tabular-figure derivative when one exists.
  property string shellFamily: uiFamily
  property string monoFamily: ""
  property string iconFamily: "Symbols Nerd Font"
  property bool tabularFigures: shellFamily !== uiFamily
  // 2 in the single preview (wide pane), 1 per side in A/B comparison.
  property int columns: 1
  readonly property real sectionWidth: (width - (columns - 1) * Style.spacing.panelGap) / columns

  readonly property color fg: Commons.Color.menu.text
  readonly property color dim: Util.alpha(Commons.Color.menu.text, 0.62)
  readonly property color faint: Util.alpha(Commons.Color.menu.text, 0.07)
  readonly property color rule: Util.alpha(Commons.Color.menu.text, 0.14)
  readonly property color accent: Commons.Color.menu.selectedText
  readonly property color selBg: Commons.Color.menu.selectedBackground
  readonly property int gap: Style.spacing.lg
  readonly property int sectionGap: Style.spacing.xxxl
  readonly property int radius: Math.max(0, Style.cornerRadius - 2)

  implicitHeight: column.implicitHeight

  component Caption: Text {
    textFormat: Text.PlainText
    color: sheet.dim
    font.family: sheet.shellFamily
    font.pixelSize: Style.font.caption
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 0
    bottomPadding: Style.spacing.xs
  }
  component UiText: Text {
    textFormat: Text.PlainText
    color: sheet.fg
    font.family: sheet.shellFamily
    font.pixelSize: Style.font.body
    elide: Text.ElideRight
  }
  component MonoText: Text {
    textFormat: Text.PlainText
    color: sheet.fg
    font.family: sheet.monoFamily
    font.pixelSize: Style.font.body
  }
  component Icon: Text {
    textFormat: Text.PlainText
    color: sheet.fg
    font.family: sheet.iconFamily
    font.pixelSize: Style.font.icon
    width: Style.font.icon + Style.spacing.md
    horizontalAlignment: Text.AlignHCenter
  }

  Grid {
    id: column
    width: parent.width
    columns: sheet.columns
    columnSpacing: Style.spacing.panelGap
    rowSpacing: sheet.sectionGap

    // ---------------------------------------------------------------- launcher
    Column {
      width: sheet.sectionWidth
      Caption { text: "Launcher" }
      Repeater {
        model: [
          { i: "", n: "Files", d: "Browse and organize your documents", s: true },
          { i: "", n: "Chromium", d: "Web browser", s: false },
          { i: "", n: "System Monitor and Resource Usage Overview", d: "Processes, CPU, memory, disks and network activity at a glance", s: false }
        ]
        delegate: Rectangle {
          required property var modelData
          width: sheet.sectionWidth
          height: Style.spacing.popupRowHeight + Style.spacing.lg
          radius: sheet.radius
          color: modelData.s ? sheet.selBg : "transparent"
          Row {
            anchors.verticalCenter: parent.verticalCenter
            x: Style.spacing.md
            width: parent.width - Style.spacing.md * 2
            spacing: Style.spacing.md
            Icon { text: modelData.i; color: modelData.s ? sheet.accent : sheet.fg; anchors.verticalCenter: parent.verticalCenter }
            Column {
              width: parent.width - Style.font.icon - Style.spacing.md * 2
              anchors.verticalCenter: parent.verticalCenter
              UiText { width: parent.width; text: modelData.n; color: modelData.s ? sheet.accent : sheet.fg }
              UiText { width: parent.width; text: modelData.d; color: sheet.dim; font.pixelSize: Style.font.caption }
            }
          }
        }
      }
    }

    // ---------------------------------------------------------------- menu
    Column {
      width: sheet.sectionWidth
      Caption { text: "Menu" }
      Repeater {
        model: [
          { i: String.fromCodePoint(0xF03D8), n: "Appearance", sub: true },
          { i: String.fromCodePoint(0xE615), n: "Setup", sub: true },
          { i: String.fromCodePoint(0xF0249), n: "Install Development Environments and Toolchains", sub: true },
          { i: "", n: "Restart…", sub: false }
        ]
        delegate: Item {
          required property var modelData
          width: sheet.sectionWidth
          height: Style.spacing.popupRowHeight
          Row {
            anchors.verticalCenter: parent.verticalCenter
            x: Style.spacing.md
            spacing: Style.spacing.md
            Icon { text: modelData.i; anchors.verticalCenter: parent.verticalCenter }
            UiText {
              anchors.verticalCenter: parent.verticalCenter
              width: sheet.sectionWidth - Style.font.icon * 3 - Style.spacing.md * 4
              text: modelData.n
            }
          }
          Icon {
            visible: modelData.sub
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            color: sheet.dim
            font.pixelSize: Style.font.caption
          }
        }
      }
    }

    // ---------------------------------------------------------------- notification + window title
    Column {
      width: sheet.sectionWidth
      spacing: Style.spacing.sm
      Caption { text: "Notification & window title" }
      Rectangle {
        width: parent.width
        height: note.implicitHeight + Style.spacing.xxl * 2
        radius: sheet.radius
        color: sheet.faint
        border.width: 1
        border.color: sheet.rule
        Row {
          id: note
          x: Style.spacing.xxl; y: Style.spacing.xxl
          width: parent.width - Style.spacing.xxl * 2
          spacing: Style.spacing.lg
          Icon { text: ""; font.pixelSize: Style.font.heading; width: Style.font.heading + Style.spacing.sm }
          Column {
            width: parent.width - Style.font.heading - Style.spacing.sm - Style.spacing.lg
            spacing: Style.spacing.xs
            Row {
              width: parent.width
              UiText { width: parent.width - stamp.width; text: "Update available"; font.bold: true }
              UiText { id: stamp; text: "now"; color: sheet.dim; font.pixelSize: Style.font.caption }
            }
            UiText {
              width: parent.width
              wrapMode: Text.Wrap
              elide: Text.ElideNone
              color: sheet.dim
              text: "Omarchy 4.1 is ready — 23 fixes, 7 new themes & “Quattro” improvements. Restart to apply (≈ 2 min)."
            }
          }
        }
      }
      Rectangle {
        width: parent.width
        height: Style.space(22)
        color: Util.alpha(Commons.Color.background, 0.6)
        border.width: 1
        border.color: sheet.rule
        UiText {
          anchors.verticalCenter: parent.verticalCenter
          x: Style.spacing.lg
          width: parent.width - Style.spacing.lg * 2
          font.bold: true
          text: "README.md — ~/Work/omarchy-typography — Neovim"
        }
      }
    }

    // ---------------------------------------------------------------- shortcuts (monospace keys)
    Column {
      width: sheet.sectionWidth
      Caption { text: "Keyboard shortcuts" }
      Repeater {
        model: [
          ["Super + Return", "Terminal"],
          ["Super + Shift + B", "Browser"],
          ["Super + Alt + Space", "Omarchy menu"],
          ["Ctrl + Alt + Del", "System"]
        ]
        delegate: Row {
          required property var modelData
          height: Style.spacing.popupRowHeight - Style.spacing.sm
          spacing: Style.spacing.xxl
          MonoText { text: modelData[0].padEnd(20, " "); anchors.verticalCenter: parent.verticalCenter }
          UiText { text: modelData[1]; color: sheet.dim; anchors.verticalCenter: parent.verticalCenter }
        }
      }
    }

    // ---------------------------------------------------------------- clock + readouts (tabular)
    Column {
      width: sheet.sectionWidth
      spacing: Style.spacing.xs
      Caption { text: sheet.tabularFigures ? "Clock & readouts — tabular figures" : "Clock & readouts — proportional figures (font has no tabular set)" }
      Row {
        width: parent.width
        spacing: Style.spacing.huge
        UiText { text: "Tuesday 21:47:08"; font.pixelSize: Style.font.display; elide: Text.ElideNone }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          Repeater {
            model: ["111.11", "808.08", "10:01"]
            delegate: UiText {
              required property string modelData
              width: Style.space(64)
              horizontalAlignment: Text.AlignRight
              text: modelData
              font.pixelSize: Style.font.caption
              color: sheet.dim
            }
          }
        }
      }
      UiText { width: parent.width; text: "CPU 12.4%   MEM 3.81 GB   NET 104.7 Mb/s   BAT 100%   21°C" }
    }

    // ---------------------------------------------------------------- terminal / code (monospace)
    Column {
      width: sheet.sectionWidth
      Caption { text: "Terminal & code" }
      Rectangle {
        width: parent.width
        height: code.implicitHeight + Style.spacing.xl * 2
        radius: sheet.radius
        color: Util.alpha(Commons.Color.background, 0.7)
        border.width: 1
        border.color: sheet.rule
        clip: true
        Column {
          id: code
          x: Style.spacing.xl; y: Style.spacing.xl
          MonoText { text: "$ fc-match monospace -f '%{family}'"; color: sheet.accent }
          MonoText { text: sheet.monoFamily }
          MonoText { text: "fn parse(id: &str) -> u32 { 0xDEADBEEF }" }
          MonoText { text: "|  id  | name   | size   |" }
          MonoText { text: "| 0x1F | ok     | 1024 B |" }
          MonoText { text: "0O 1lI| rn m  {}[]() <=> != == ->" }
        }
      }
    }

    // ---------------------------------------------------------------- character check
    Column {
      width: sheet.sectionWidth
      spacing: Style.spacing.xs
      Caption { text: "Characters" }
      UiText { width: parent.width; text: "Sphinx of black quartz, judge my vow · SPHINX OF BLACK QUARTZ" }
      UiText { width: parent.width; text: "0O  1lI|  rn m  illiterate  WWMMWW  mmwwmm  Il1  O0Q" }
      UiText { width: parent.width; text: "“Quotes” ‘single’ … – — @#&%*+=/\\ ¿¡ (a) [b] {c} 3×4 ½ €£¥" }
      UiText { width: parent.width; text: "Ångström · façade · Straße · Łódź · Ελληνικά · Кириллица" }
    }
  }
}
