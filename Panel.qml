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
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property var shells: []
  property var attention: []
  property bool online: false
  property bool refreshing: false
  property string error: ""
  property int selectedIndex: 0

  readonly property int itemCount: attention.length + shells.length
  readonly property var selectedItem: {
    if (selectedIndex < attention.length) return attention[selectedIndex]
    var shellIndex = selectedIndex - attention.length
    return shellIndex >= 0 && shellIndex < shells.length ? shells[shellIndex] : null
  }
  readonly property int runningCount: shells.filter(function(shell) {
    return shell.status === "running"
  }).length
  readonly property int blockedCount: attention.filter(function(item) {
    return item.reason === "blocked"
  }).length
  readonly property int completedCount: attention.filter(function(item) {
    return item.reason === "completed"
  }).length

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (listProcess.running || attentionProcess.running) return
    refreshing = true
    error = ""
    listProcess.running = true
    attentionProcess.running = true
  }

  function parseShells(raw) {
    try {
      var response = JSON.parse(String(raw || ""))
      if (response.schema !== "boomux.cli/v1" || !response.data || !Array.isArray(response.data.shells))
        throw new Error("unexpected Boomux response")

      shells = response.data.shells
      online = true
      clampSelection()
    } catch (exception) {
      online = false
      shells = []
      selectedIndex = 0
      error = "Could not read Boomux terminals"
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function parseAttention(raw) {
    try {
      var response = JSON.parse(String(raw || ""))
      if (response.schema !== "boomux.cli/v1" || !response.data || !Array.isArray(response.data.attention))
        throw new Error("unexpected Boomux attention response")

      attention = response.data.attention
      clampSelection()
    } catch (exception) {
      attention = []
      clampSelection()
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function clampSelection() {
    selectedIndex = Math.max(0, Math.min(selectedIndex, itemCount - 1))
  }

  function moveSelection(offset) {
    if (itemCount === 0) return
    selectedIndex = Math.max(0, Math.min(selectedIndex + offset, itemCount - 1))
    if (selectedIndex < attention.length)
      attentionList.positionViewAtIndex(selectedIndex, ListView.Contain)
    else
      shellList.positionViewAtIndex(selectedIndex - attention.length, ListView.Contain)
  }

  function openItem(item) {
    if (!item || openProcess.running) return
    if (item.agent && !item.shell_is_retained) return
    var shellId = item.agent ? item.agent.shell_id : item.id
    if (!shellId) return
    openProcess.command = ["boomux", "open", String(shellId)]
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
      if (!attentionProcess.running) root.refreshing = false
      if (exitCode !== 0) {
        root.online = false
        root.shells = []
        root.error = "Boomux is unavailable"
      }
    }
  }

  Process {
    id: attentionProcess
    command: ["boomux", "attention", "list", "--json"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseAttention(text)
    }

    onExited: function(exitCode) {
      if (!listProcess.running) root.refreshing = false
      if (exitCode !== 0) root.attention = []
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
      Item {
        anchors.fill: parent

        BoomuxIcon {
          anchors.fill: parent
          color: root.blockedCount > 0 ? root.urgent : root.foreground
        }

        Text {
          visible: root.attention.length > 0
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          text: String(root.blockedCount > 0 ? root.blockedCount : root.completedCount)
          color: root.blockedCount > 0 ? root.urgent : Color.accent
          font.family: root.fontFamily
          font.pixelSize: Math.max(7, Math.round(parent.height * 0.42))
          font.bold: true
        }
      }
    }
    active: root.blockedCount > 0
    tooltipText: root.online
      ? (root.blockedCount > 0
          ? root.blockedCount + " Boomux agent" + (root.blockedCount === 1 ? "" : "s") + " blocked"
          : root.shells.length + " Boomux terminal" + (root.shells.length === 1 ? "" : "s"))
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
      onActivateRequested: root.openItem(root.selectedItem)
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
          meta: root.blockedCount > 0 ? "NEEDS ATTENTION" : (root.online ? "TERMINALS" : "UNAVAILABLE")
          detail: root.online
            ? (root.blockedCount > 0
                ? root.blockedCount + " blocked · " + root.completedCount + " completed"
                : root.shells.length + " total · " + root.runningCount + " running")
            : "boomux was not found"
          foreground: root.foreground
          fontFamily: root.fontFamily

          iconComponent: Component {
            BoomuxIcon {
              width: Style.font.display
              height: Style.font.display
              color: root.blockedCount > 0 ? root.urgent : root.foreground
            }
          }
        }

        PanelSeparator {
          foreground: root.foreground
        }

        PanelSectionHeader {
          visible: root.attention.length > 0
          width: parent.width
          text: "NEEDS ATTENTION"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        ListView {
          id: attentionList
          visible: root.attention.length > 0
          width: parent.width
          implicitHeight: Math.min(contentHeight, Style.space(root.shells.length > 0 ? 160 : 300))
          model: root.attention
          spacing: Style.space(4)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          currentIndex: root.selectedIndex < root.attention.length ? root.selectedIndex : -1
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          delegate: Rectangle {
            id: attentionRow
            required property var modelData
            required property int index

            width: ListView.view.width
            height: Style.space(64)
            radius: Style.cornerRadius
            color: index === root.selectedIndex
              ? Style.selectedFillFor(root.foreground, Color.accent)
              : (attentionMouse.containsMouse
                  ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                  : "transparent")
            opacity: modelData.shell_is_retained ? 1 : 0.55

            Text {
              id: attentionGlyph
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              text: attentionRow.modelData.reason === "blocked" ? "!" : "✓"
              color: attentionRow.modelData.reason === "blocked" ? root.urgent : Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Column {
              anchors.left: attentionGlyph.right
              anchors.leftMargin: Style.space(12)
              anchors.right: parent.right
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: String(attentionRow.modelData.workspace_name) + " / "
                  + String(attentionRow.modelData.agent ? attentionRow.modelData.agent.name : "Agent")
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: attentionRow.index === root.selectedIndex
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: attentionRow.modelData.shell_is_retained
                  ? String(attentionRow.modelData.observation ? attentionRow.modelData.observation.evidence : "")
                  : "Terminal no longer retained"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            MouseArea {
              id: attentionMouse
              anchors.fill: parent
              hoverEnabled: true
              enabled: attentionRow.modelData.shell_is_retained
              onEntered: root.selectedIndex = attentionRow.index
              onClicked: root.openItem(attentionRow.modelData)
            }
          }
        }

        PanelSectionHeader {
          visible: root.attention.length > 0 && root.shells.length > 0
          width: parent.width
          text: "TERMINALS"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Text {
          visible: root.error !== "" || (root.online && root.itemCount === 0)
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
          implicitHeight: Math.min(contentHeight, Style.space(root.attention.length > 0 ? 220 : 420))
          model: root.shells
          spacing: Style.space(4)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          currentIndex: root.selectedIndex >= root.attention.length
            ? root.selectedIndex - root.attention.length
            : -1
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          delegate: Rectangle {
            id: shellRow
            required property var modelData
            required property int index

            width: ListView.view.width
            height: Style.space(58)
            radius: Style.cornerRadius
            color: index + root.attention.length === root.selectedIndex
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
                font.bold: shellRow.index + root.attention.length === root.selectedIndex
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
              onEntered: root.selectedIndex = shellRow.index + root.attention.length
              onClicked: root.openItem(shellRow.modelData)
            }
          }
        }

        Text {
          visible: root.itemCount > 0
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
