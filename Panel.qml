import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root

  moduleName: "io.github.gardnmi.boomux"
  ipcTarget: "io.github.gardnmi.boomux"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property var shells: []
  property bool online: false
  property bool refreshing: false
  property string error: ""
  property int selectedIndex: 0

  readonly property var selectedShell: shells.length > 0 && selectedIndex < shells.length
    ? shells[selectedIndex]
    : null
  readonly property int runningCount: shells.filter(function(shell) {
    return shell.status === "running"
  }).length

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (listProcess.running) return
    refreshing = true
    error = ""
    listProcess.running = true
  }

  function parseShells(raw) {
    try {
      var response = JSON.parse(String(raw || ""))
      if (response.schema !== "boomux.cli/v1" || !response.data || !Array.isArray(response.data.shells))
        throw new Error("unexpected Boomux response")

      shells = response.data.shells
      online = true
      selectedIndex = Math.max(0, Math.min(selectedIndex, shells.length - 1))
    } catch (exception) {
      online = false
      shells = []
      selectedIndex = 0
      error = "Could not read Boomux terminals"
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function moveSelection(offset) {
    if (shells.length === 0) return
    selectedIndex = Math.max(0, Math.min(selectedIndex + offset, shells.length - 1))
    shellList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function openShell(shell) {
    if (!shell || openProcess.running) return
    openProcess.command = ["boomux", "open", String(shell.id)]
    openProcess.running = true
    close()
  }

  onOpenedChanged: if (opened) {
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Process {
    id: listProcess
    command: ["boomux", "list", "--json"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseShells(text)
    }

    onExited: function(exitCode) {
      root.refreshing = false
      if (exitCode !== 0) {
        root.online = false
        root.shells = []
        root.error = "Boomux is unavailable"
      }
    }
  }

  Process {
    id: openProcess
    onExited: function(exitCode) {
      if (exitCode !== 0) console.warn("io.github.gardnmi.boomux: failed to open terminal")
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    active: root.runningCount > 0
    tooltipText: root.online
      ? root.shells.length + " Boomux terminal" + (root.shells.length === 1 ? "" : "s")
      : "Boomux unavailable"

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(390))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { if (dy !== 0) root.moveSelection(dy) }
      onActivateRequested: root.openShell(root.selectedShell)
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) { if (text === "r" || text === "R") root.refresh() }

      Column {
        id: contentColumn
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: "Boomux"
          meta: root.online ? "TERMINALS" : "UNAVAILABLE"
          detail: root.online
            ? root.shells.length + " total · " + root.runningCount + " running"
            : "boomux was not found"
          foreground: root.foreground
          fontFamily: root.fontFamily

          iconComponent: Component {
            Text {
              text: ""
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        PanelSeparator {
          foreground: root.foreground
        }

        Text {
          visible: root.error !== "" || (root.online && root.shells.length === 0)
          width: parent.width
          text: root.error !== "" ? root.error : "No Boomux terminals"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          topPadding: Style.space(20)
          bottomPadding: Style.space(20)
        }

        ListView {
          id: shellList
          visible: root.shells.length > 0
          width: parent.width
          implicitHeight: Math.min(contentHeight, Style.space(420))
          model: root.shells
          spacing: Style.space(4)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          currentIndex: root.selectedIndex
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          delegate: Rectangle {
            id: shellRow
            required property var modelData
            required property int index

            width: ListView.view.width
            height: Style.space(58)
            radius: Style.cornerRadius
            color: index === root.selectedIndex
              ? Style.selectedFillFor(root.foreground, Color.accent)
              : (rowMouse.containsMouse
                  ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                  : "transparent")

            Text {
              id: statusGlyph
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              text: shellRow.modelData.status === "running" ? "●" : "○"
              color: shellRow.modelData.status === "running" ? Color.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Column {
              anchors.left: statusGlyph.right
              anchors.leftMargin: Style.space(10)
              anchors.right: parent.right
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: String(shellRow.modelData.workspace_name) + " / " + String(shellRow.modelData.name)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: shellRow.index === root.selectedIndex
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: String(shellRow.modelData.cwd || "")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideMiddle
              }
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              onEntered: root.selectedIndex = shellRow.index
              onClicked: root.openShell(shellRow.modelData)
            }
          }
        }

        Text {
          visible: root.shells.length > 0
          width: parent.width
          text: "Enter opens · R refreshes"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
  }
}
