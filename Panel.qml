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
    iconComponent: Component {
      BoomuxIcon {
        anchors.fill: parent
        color: root.foreground
      }
    }
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
            BoomuxIcon {
              width: Style.font.display
              height: Style.font.display
              color: root.foreground
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

  component BoomuxIcon: Item {
    property color color: root.foreground
    onColorChanged: iconCanvas.requestPaint()

    Canvas {
      id: iconCanvas
      anchors.fill: parent
      onPaint: {
        var context = getContext("2d")
        var size = Math.min(width, height)
        context.clearRect(0, 0, width, height)
        context.fillStyle = parent.color
        context.strokeStyle = parent.color
        context.lineCap = "round"

        context.beginPath()
        context.arc(width * 0.42, height * 0.61, size * 0.29, 0, Math.PI * 2)
        context.fill()

        context.lineWidth = size * 0.12
        context.beginPath()
        context.moveTo(width * 0.59, height * 0.39)
        context.lineTo(width * 0.69, height * 0.29)
        context.stroke()

        context.lineWidth = size * 0.08
        context.beginPath()
        context.moveTo(width * 0.7, height * 0.28)
        context.bezierCurveTo(width * 0.8, height * 0.16, width * 0.86, height * 0.28, width * 0.91, height * 0.17)
        context.stroke()

        context.lineWidth = size * 0.06
        context.beginPath()
        context.moveTo(width * 0.91, height * 0.09)
        context.lineTo(width * 0.91, height * 0.01)
        context.moveTo(width * 0.96, height * 0.13)
        context.lineTo(width, height * 0.09)
        context.moveTo(width * 0.86, height * 0.13)
        context.lineTo(width * 0.82, height * 0.09)
        context.stroke()
      }

      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
    }
  }
}
