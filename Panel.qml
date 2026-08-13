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
  property bool agentBaselineReady: false
  property var previousAgentStates: ({})
  property var completedAgents: ({})
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
  readonly property int completedCount: Object.keys(completedAgents).length

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

      var nextAgents = response.data.agents
      var nextStates = ({})
      var nextCompleted = ({})
      for (var completedId in completedAgents) nextCompleted[completedId] = true

      for (var i = 0; i < nextAgents.length; i++) {
        var agent = nextAgents[i]
        var state = agent.observation ? agent.observation.state : "unknown"
        nextStates[agent.id] = state
        if (agentBaselineReady && !opened && previousAgentStates[agent.id] === "working" && state === "idle")
          nextCompleted[agent.id] = true
        if (state === "working" || state === "blocked") delete nextCompleted[agent.id]
      }

      previousAgentStates = nextStates
      completedAgents = nextCompleted
      agentBaselineReady = true
      agents = nextAgents
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

  function agentDisplayName(agent) {
    if (!agent) return "Agent"
    for (var i = 0; i < shells.length; i++)
      if (shells[i].id === agent.shell_id) return shells[i].name
    return agent.name
  }

  function clearCompletedAgents() {
    completedAgents = ({})
  }

  onOpenedChanged: if (opened) {
    clearCompletedAgents()
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
          color: root.blockedCount > 0 ? root.urgent
            : (root.completedCount > 0 ? Color.accent : root.foreground)
        }

        Text {
          visible: root.blockedCount > 0 || root.completedCount > 0
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
    active: root.blockedCount > 0 || root.completedCount > 0
    tooltipText: root.online
      ? (root.blockedCount > 0
          ? root.blockedCount + " Boomux agent" + (root.blockedCount === 1 ? "" : "s") + " blocked"
          : (root.completedCount > 0
              ? root.completedCount + " Boomux agent" + (root.completedCount === 1 ? "" : "s") + " finished"
              : root.visibleAgents.length + " agent" + (root.visibleAgents.length === 1 ? "" : "s")
                + " · " + root.terminalShells.length + " terminal" + (root.terminalShells.length === 1 ? "" : "s")))
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
          meta: root.blockedCount > 0 ? "NEEDS ATTENTION"
            : (root.completedCount > 0 ? "AGENT FINISHED" : (root.online ? "WORKSPACES" : "UNAVAILABLE"))
          detail: root.online
            ? (root.blockedCount > 0
                ? root.blockedCount + " blocked · " + root.workingCount + " working"
                : (root.completedCount > 0
                    ? root.completedCount + " finished · " + root.workingCount + " working"
                    : root.visibleAgents.length + " agents · " + root.terminalShells.length + " terminals"))
            : "boomux was not found"
          foreground: root.foreground
          fontFamily: root.fontFamily

          iconComponent: Component {
            BoomuxIcon {
              width: Style.font.display
              height: Style.font.display
              color: root.blockedCount > 0 ? root.urgent
                : (root.completedCount > 0 ? Color.accent : root.foreground)
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
            readonly property bool justCompleted: !!root.completedAgents[modelData.id]

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
              text: agentRow.needsAttention ? "!"
                : (agentRow.justCompleted ? "✓" : (agentRow.state === "working" ? "●" : "○"))
              color: agentRow.needsAttention ? root.urgent
                : ((agentRow.justCompleted || agentRow.state === "working") ? Color.accent : root.dim)
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
                text: String(agentRow.modelData.workspace_name) + " / " + root.agentDisplayName(agentRow.modelData)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: agentRow.index === root.selectedIndex
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: (agentRow.justCompleted ? "finished" : agentRow.state)
                  + (agentRow.needsAttention ? " · needs attention" : "")
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
        context.strokeStyle = parent.color
        context.lineCap = "round"
        context.lineJoin = "round"

        context.lineWidth = size * 0.1
        context.beginPath()
        context.arc(width * 0.4, height * 0.61, size * 0.3, 0, Math.PI * 2)
        context.stroke()

        context.lineWidth = size * 0.1
        context.beginPath()
        context.moveTo(width * 0.59, height * 0.39)
        context.lineTo(width * 0.67, height * 0.31)
        context.lineTo(width * 0.72, height * 0.36)
        context.lineTo(width * 0.78, height * 0.29)
        context.stroke()

        context.lineWidth = size * 0.08
        context.beginPath()
        context.moveTo(width * 0.4, height * 0.78)
        context.bezierCurveTo(width * 0.5, height * 0.77, width * 0.58, height * 0.71, width * 0.62, height * 0.64)
        context.stroke()

        context.lineWidth = size * 0.08
        context.beginPath()
        context.moveTo(width * 0.8, height * 0.2)
        context.lineTo(width * 0.8, height * 0.09)
        context.moveTo(width * 0.87, height * 0.25)
        context.lineTo(width * 0.97, height * 0.22)
        context.moveTo(width * 0.75, height * 0.22)
        context.lineTo(width * 0.7, height * 0.13)
        context.stroke()
      }

      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
    }
  }
}
