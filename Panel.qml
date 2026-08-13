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
  property var agents: []
  property bool online: false
  property bool refreshing: false
  property int refreshPending: 0
  property string error: ""
  property int selectedIndex: 0

  readonly property var visibleAgents: agents.filter(function(agent) {
    var state = agent.observation ? agent.observation.state : "unknown"
    return state !== "inactive" && state !== "done"
  })
  readonly property var terminalShells: shells.filter(function(shell) {
    return !visibleAgents.some(function(agent) { return agent.shell_id === shell.id })
  })
  readonly property int itemCount: visibleAgents.length + terminalShells.length
  readonly property var selectedItem: {
    if (selectedIndex < visibleAgents.length) return visibleAgents[selectedIndex]
    var shellIndex = selectedIndex - visibleAgents.length
    return shellIndex >= 0 && shellIndex < terminalShells.length ? terminalShells[shellIndex] : null
  }
  readonly property int blockedCount: visibleAgents.filter(function(agent) {
    return agent.attention && agent.attention.reason === "blocked"
  }).length
  readonly property int workingCount: visibleAgents.filter(function(agent) {
    return agent.observation && agent.observation.state === "working"
  }).length

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (listProcess.running || agentProcess.running) return
    refreshing = true
    refreshPending = 2
    error = ""
    listProcess.running = true
    agentProcess.running = true
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

  function parseAgents(raw) {
    try {
      var response = JSON.parse(String(raw || ""))
      if (response.schema !== "boomux.cli/v1" || !response.data || !Array.isArray(response.data.agents))
        throw new Error("unexpected Boomux Agent response")

      agents = response.data.agents
      clampSelection()
    } catch (exception) {
      agents = []
      clampSelection()
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function finishRefresh() {
    refreshPending = Math.max(0, refreshPending - 1)
    refreshing = refreshPending > 0
  }

  function clampSelection() {
    selectedIndex = Math.max(0, Math.min(selectedIndex, itemCount - 1))
  }

  function moveSelection(offset) {
    if (itemCount === 0) return
    selectedIndex = Math.max(0, Math.min(selectedIndex + offset, itemCount - 1))
    if (selectedIndex < visibleAgents.length)
      agentList.positionViewAtIndex(selectedIndex, ListView.Contain)
    else
      shellList.positionViewAtIndex(selectedIndex - visibleAgents.length, ListView.Contain)
  }

  function openItem(item) {
    if (!item || openProcess.running) return
    var shellId = item.shell_id || item.id
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
      root.finishRefresh()
      if (exitCode !== 0) {
        root.online = false
        root.shells = []
        root.error = "Boomux is unavailable"
      }
    }
  }

  Process {
    id: agentProcess
    command: ["boomux", "agent", "list", "--json"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseAgents(text)
    }

    onExited: function(exitCode) {
      root.finishRefresh()
      if (exitCode !== 0) root.agents = []
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
          visible: root.blockedCount > 0
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          text: String(root.blockedCount)
          color: root.urgent
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
          : root.visibleAgents.length + " agent" + (root.visibleAgents.length === 1 ? "" : "s")
            + " · " + root.terminalShells.length + " terminal" + (root.terminalShells.length === 1 ? "" : "s"))
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
          meta: root.blockedCount > 0 ? "NEEDS ATTENTION" : (root.online ? "WORKSPACES" : "UNAVAILABLE")
          detail: root.online
            ? (root.blockedCount > 0
                ? root.blockedCount + " blocked · " + root.workingCount + " working"
                : root.visibleAgents.length + " agents · " + root.terminalShells.length + " terminals")
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
          visible: root.visibleAgents.length > 0
          width: parent.width
          text: "AGENTS"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        ListView {
          id: agentList
          visible: root.visibleAgents.length > 0
          width: parent.width
          implicitHeight: Math.min(contentHeight, Style.space(root.terminalShells.length > 0 ? 220 : 420))
          model: root.visibleAgents
          spacing: Style.space(4)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          currentIndex: root.selectedIndex < root.visibleAgents.length ? root.selectedIndex : -1
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          delegate: Rectangle {
            id: agentRow
            required property var modelData
            required property int index

            readonly property string state: modelData.observation ? modelData.observation.state : "unknown"
            readonly property bool needsAttention: modelData.attention && modelData.attention.reason === "blocked"

            width: ListView.view.width
            height: Style.space(64)
            radius: Style.cornerRadius
            color: index === root.selectedIndex
              ? Style.selectedFillFor(root.foreground, Color.accent)
              : (agentMouse.containsMouse
                  ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                  : "transparent")

            Text {
              id: agentGlyph
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              text: agentRow.needsAttention ? "!" : (agentRow.state === "working" ? "●" : "○")
              color: agentRow.needsAttention ? root.urgent
                : (agentRow.state === "working" ? Color.accent : root.dim)
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: agentRow.needsAttention
            }

            Column {
              anchors.left: agentGlyph.right
              anchors.leftMargin: Style.space(12)
              anchors.right: parent.right
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: String(agentRow.modelData.workspace_name) + " / " + String(agentRow.modelData.name)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: agentRow.index === root.selectedIndex
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: agentRow.state + (agentRow.needsAttention ? " · needs attention" : "")
                  + (agentRow.modelData.observation && agentRow.modelData.observation.evidence
                  ? " · " + String(agentRow.modelData.observation.evidence)
                  : "")
                color: agentRow.needsAttention ? root.urgent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            MouseArea {
              id: agentMouse
              anchors.fill: parent
              hoverEnabled: true
              onEntered: root.selectedIndex = agentRow.index
              onClicked: root.openItem(agentRow.modelData)
            }
          }
        }

        PanelSectionHeader {
          visible: root.terminalShells.length > 0
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
          visible: root.terminalShells.length > 0
          width: parent.width
          implicitHeight: Math.min(contentHeight, Style.space(root.visibleAgents.length > 0 ? 220 : 420))
          model: root.terminalShells
          spacing: Style.space(4)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          currentIndex: root.selectedIndex >= root.visibleAgents.length
            ? root.selectedIndex - root.visibleAgents.length
            : -1
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          delegate: Rectangle {
            id: shellRow
            required property var modelData
            required property int index

            width: ListView.view.width
            height: Style.space(58)
            radius: Style.cornerRadius
            color: index + root.visibleAgents.length === root.selectedIndex
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
                font.bold: shellRow.index + root.visibleAgents.length === root.selectedIndex
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
              onEntered: root.selectedIndex = shellRow.index + root.visibleAgents.length
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
