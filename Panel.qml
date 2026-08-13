import QtQuick
import QtQuick.Controls
import QtQuick.Effects
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
  property var dismissedAttention: ({})
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
    return agentNeedsAttention(agent)
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
        if (agentBaselineReady && previousAgentStates[agent.id] === "working" && state === "idle")
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
    if (item.shell_id) {
      clearCompletedAgent(item.id)
      acknowledgeAgent(item)
    }
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

  function attentionRevision(agent) {
    return agent && agent.attention && agent.attention.observation
      ? Number(agent.attention.observation.revision)
      : 0
  }

  function agentNeedsAttention(agent) {
    if (!agent || !agent.observation || agent.observation.state !== "blocked") return false
    var revision = attentionRevision(agent)
    return revision > 0 && Number(dismissedAttention[agent.id] || 0) !== revision
  }

  function acknowledgeAgent(agent) {
    var revision = attentionRevision(agent)
    if (revision <= 0) return

    var nextDismissed = ({})
    for (var id in dismissedAttention) nextDismissed[id] = dismissedAttention[id]
    nextDismissed[agent.id] = revision
    dismissedAttention = nextDismissed

    if (!acknowledgeProcess.running) {
      acknowledgeProcess.command = ["boomux", "attention", "acknowledge", String(agent.id),
        "--observation-revision", String(revision), "--json"]
      acknowledgeProcess.running = true
    }
  }

  function clearCompletedAgent(agentId) {
    if (!completedAgents[agentId]) return
    var nextCompleted = ({})
    for (var id in completedAgents)
      if (id !== agentId) nextCompleted[id] = completedAgents[id]
    completedAgents = nextCompleted
  }

  function openDashboard() {
    if (!bar) return
    bar.run("omarchy-launch-tui --app-id=org.omarchy.boomux boomux")
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

  Process {
    id: acknowledgeProcess
    onExited: function(exitCode) {
      if (exitCode !== 0) console.warn("io.github.gardnmi.boomux: failed to acknowledge attention")
      root.refresh()
    }
  }

  Timer {
    interval: 1000
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
          lit: root.blockedCount > 0 || root.completedCount > 0
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
          id: hero
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
              width: Style.font.display * 1.15
              height: Style.font.display * 1.15
              color: root.blockedCount > 0 ? root.urgent
                : (root.completedCount > 0 ? Color.accent : root.foreground)
              lit: root.blockedCount > 0 || root.completedCount > 0
            }
          }
        }

        Button {
          width: parent.width
          text: "Open Boomux TUI"
          iconText: ""
          tooltipText: "Open the Boomux dashboard"
          bordered: true
          leftAlign: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          iconSize: Style.font.body
          onClicked: root.openDashboard()
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
            readonly property bool needsAttention: root.agentNeedsAttention(modelData)
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
    id: boomuxIcon
    property color color: root.foreground
    property bool lit: false

    Image {
      id: bombImage
      anchors.fill: parent
      source: Qt.resolvedUrl("assets/bomb.svg")
      fillMode: Image.PreserveAspectFit
      sourceSize.width: Math.round(width * 2)
      sourceSize.height: Math.round(height * 2)
      visible: false
      layer.enabled: true
    }

    MultiEffect {
      anchors.fill: bombImage
      source: bombImage
      colorization: 1.0
      colorizationColor: boomuxIcon.color
    }

    Image {
      anchors.fill: parent
      source: Qt.resolvedUrl("assets/bomb-spark.svg")
      fillMode: Image.PreserveAspectFit
      sourceSize.width: Math.round(width * 2)
      sourceSize.height: Math.round(height * 2)
      visible: boomuxIcon.lit
    }
  }
}
