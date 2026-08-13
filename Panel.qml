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

  property var workspaces: []
  property var shells: []
  property var agents: []
  property var workspaceDetail: null
  property string selectedWorkspaceId: ""
  property string activeTab: "agents"
  property int selectedIndex: 0
  property bool online: false
  property bool refreshing: false
  property int refreshPending: 0
  property bool agentBaselineReady: false
  property var previousAgentStates: ({})
  property var completedAgents: ({})
  property var dismissedAttention: ({})
  property string error: ""
  property string actionMessage: ""
  property string formMode: ""
  property string agentHost: "opencode"
  property string pendingAction: ""
  property string pendingWorkspaceName: ""
  property string pendingShellName: ""

  readonly property var visibleAgents: agents.filter(function(agent) {
    var state = agent.observation ? agent.observation.state : "unknown"
    return state !== "inactive" && state !== "done"
  })
  readonly property var selectedWorkspace: {
    for (var i = 0; i < workspaces.length; i++)
      if (workspaces[i].id === selectedWorkspaceId) return workspaces[i]
    return null
  }
  readonly property var workspaceItems: buildWorkspaceItems()
  readonly property int itemCount: activeTab === "agents" ? visibleAgents.length : workspaces.length
  readonly property var selectedItem: {
    var model = activeTab === "agents" ? visibleAgents : workspaces
    return selectedIndex >= 0 && selectedIndex < model.length ? model[selectedIndex] : null
  }
  readonly property int blockedCount: visibleAgents.filter(function(agent) {
    return agentNeedsAttention(agent)
  }).length
  readonly property int workingCount: visibleAgents.filter(function(agent) {
    return agent.observation && agent.observation.state === "working"
  }).length
  readonly property int completedCount: Object.keys(completedAgents).length
  readonly property bool editing: formMode !== ""

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (workspaceListProcess.running || listProcess.running || agentProcess.running) return
    refreshing = true
    refreshPending = 3
    error = ""
    workspaceListProcess.running = true
    listProcess.running = true
    agentProcess.running = true
  }

  function parseEnvelope(raw, command) {
    var response = JSON.parse(String(raw || ""))
    if (response.schema !== "boomux.cli/v1" || response.command !== command || !response.data)
      throw new Error("unexpected Boomux response")
    return response.data
  }

  function parseWorkspaces(raw) {
    try {
      var data = parseEnvelope(raw, "workspace.list")
      if (!Array.isArray(data.workspaces)) throw new Error("missing workspaces")
      workspaces = data.workspaces
      online = true

      if (pendingWorkspaceName !== "") {
        for (var i = 0; i < workspaces.length; i++) {
          if (workspaces[i].name === pendingWorkspaceName) {
            selectedWorkspaceId = workspaces[i].id
            pendingWorkspaceName = ""
            break
          }
        }
      }
      if (!selectedWorkspace || selectedWorkspaceId === "")
        selectedWorkspaceId = workspaces.length > 0 ? workspaces[0].id : ""
      if (selectedWorkspaceId !== "") inspectWorkspace(selectedWorkspaceId)
      else workspaceDetail = null
      clampSelection()
    } catch (exception) {
      online = false
      workspaces = []
      workspaceDetail = null
      error = "Could not read Boomux workspaces"
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function parseShells(raw) {
    try {
      var data = parseEnvelope(raw, "list")
      if (!Array.isArray(data.shells)) throw new Error("missing shells")
      shells = data.shells
      online = true
    } catch (exception) {
      shells = []
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function parseAgents(raw) {
    try {
      var data = parseEnvelope(raw, "agent.list")
      if (!Array.isArray(data.agents)) throw new Error("missing agents")
      var nextAgents = data.agents
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
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function inspectWorkspace(workspaceId) {
    if (!workspaceId || workspaceInspectProcess.running) return
    workspaceInspectProcess.command = ["boomux", "workspace", "inspect", String(workspaceId), "--json"]
    workspaceInspectProcess.running = true
  }

  function parseWorkspaceDetail(raw) {
    try {
      var data = parseEnvelope(raw, "workspace.inspect")
      if (!data.workspace || data.workspace.id !== selectedWorkspaceId) return
      workspaceDetail = data.workspace
      if (pendingShellName !== "") {
        for (var i = 0; i < workspaceDetail.shells.length; i++) {
          if (workspaceDetail.shells[i].name === pendingShellName) {
            var shell = workspaceDetail.shells[i]
            pendingShellName = ""
            openShell(shell)
            break
          }
        }
      }
    } catch (exception) {
      workspaceDetail = null
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function finishRefresh() {
    refreshPending = Math.max(0, refreshPending - 1)
    refreshing = refreshPending > 0
  }

  function selectTab(tab) {
    if (activeTab === tab) return
    activeTab = tab
    selectedIndex = 0
    cancelForm()
  }

  function clampSelection() {
    selectedIndex = Math.max(0, Math.min(selectedIndex, itemCount - 1))
  }

  function moveSelection(offset) {
    if (editing || itemCount === 0) return
    selectedIndex = Math.max(0, Math.min(selectedIndex + offset, itemCount - 1))
    if (activeTab === "agents") agentList.positionViewAtIndex(selectedIndex, ListView.Contain)
    else workspaceList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function activateSelected() {
    if (activeTab === "agents") openAgent(selectedItem)
    else if (selectedItem) selectWorkspace(selectedItem.id)
  }

  function selectWorkspace(workspaceId) {
    selectedWorkspaceId = String(workspaceId)
    workspaceDetail = null
    inspectWorkspace(selectedWorkspaceId)
  }

  function currentAgentForShell(shell) {
    if (!workspaceDetail || !workspaceDetail.agents || !shell) return null
    for (var i = 0; i < workspaceDetail.agents.length; i++) {
      var agent = workspaceDetail.agents[i]
      var state = agent.observation ? agent.observation.state : "unknown"
      if (agent.shell_id === shell.id && agent.run_id === (shell.run ? shell.run.id : "")
          && state !== "inactive" && state !== "done") return agent
    }
    return null
  }

  function buildWorkspaceItems() {
    if (!workspaceDetail) return []
    var items = []
    var detailShells = workspaceDetail.shells || []
    for (var i = 0; i < detailShells.length; i++) {
      var shell = detailShells[i]
      var agent = currentAgentForShell(shell)
      items.push({
        kind: agent ? "agent" : (shell.command && shell.command.length > 0 ? "command" : "shell"),
        id: shell.id,
        name: shell.name,
        status: agent && agent.observation ? agent.observation.state : shell.status,
        detail: agent ? String(agent.integration || "agent")
          : (shell.command && shell.command.length > 0 ? shell.command.join(" ") : String(shell.cwd || "")),
        shell: shell,
        agent: agent
      })
    }
    var launchers = workspaceDetail.launchers || []
    for (var j = 0; j < launchers.length; j++) {
      var launcher = launchers[j]
      items.push({
        kind: "launcher",
        id: launcher.id,
        name: launcher.name,
        status: "on workspace open",
        detail: launcher.command ? launcher.command.join(" ") : "",
        launcher: launcher
      })
    }
    return items
  }

  function openWorkspace(workspace) {
    if (!workspace || actionProcess.running) return
    pendingAction = "open-workspace"
    actionMessage = "Opening " + String(workspace.name) + "..."
    actionProcess.command = ["boomux", "workspace", "open", String(workspace.id)]
    actionProcess.running = true
  }

  function openShell(shell) {
    if (!shell || !shell.id || openProcess.running) return
    openProcess.command = ["boomux", "open", String(shell.id)]
    openProcess.running = true
    close()
  }

  function openAgent(agent) {
    if (!agent) return
    clearCompletedAgent(agent.id)
    acknowledgeAgent(agent)
    openShell({ id: agent.shell_id })
  }

  function openWorkspaceItem(item) {
    if (!item) return
    if (item.kind === "launcher") {
      if (actionProcess.running) return
      pendingAction = "invoke-launcher"
      actionMessage = "Launching " + String(item.name) + "..."
      actionProcess.command = ["boomux", "launcher", "invoke", String(item.id)]
      actionProcess.running = true
      return
    }
    if (item.agent) {
      clearCompletedAgent(item.agent.id)
      acknowledgeAgent(item.agent)
    }
    openShell(item.shell)
  }

  function openDashboard() {
    if (!bar) return
    bar.run("omarchy-launch-tui --app-id=org.omarchy.boomux boomux")
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
      ? Number(agent.attention.observation.revision) : 0
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

  function showForm(mode) {
    formMode = mode
    actionMessage = ""
    nameField.text = ""
    cwdField.text = workspaceDetail && workspaceDetail.default_cwd
      ? String(workspaceDetail.default_cwd) : ""
    Qt.callLater(function() { nameField.forceActiveFocus() })
  }

  function cancelForm() {
    formMode = ""
    if (opened) Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function submitForm() {
    if (actionProcess.running) return
    var name = nameField.text.trim()
    var cwd = cwdField.text.trim()
    if (name === "") {
      actionMessage = "A name is required"
      return
    }

    var command
    if (formMode === "workspace") {
      pendingAction = "create-workspace"
      pendingWorkspaceName = name
      command = ["boomux", "workspace", "create", name]
      if (cwd !== "") command.push("--cwd", cwd)
    } else if (formMode === "shell" && workspaceDetail) {
      pendingAction = "create-shell"
      command = ["boomux", "shell", "create", String(workspaceDetail.id), "--name", name]
      if (cwd !== "") command.push("--cwd", cwd)
    } else if (formMode === "agent" && workspaceDetail) {
      pendingAction = "create-agent"
      pendingShellName = name
      command = ["boomux", "shell", "create", String(workspaceDetail.id), "--name", name]
      if (cwd !== "") command.push("--cwd", cwd)
      command.push("--", agentHost)
    } else {
      return
    }

    actionMessage = "Creating " + name + "..."
    actionProcess.command = command
    actionProcess.running = true
  }

  function processError(raw, fallback) {
    try {
      var response = JSON.parse(String(raw || ""))
      if (response.error && response.error.message) return String(response.error.message)
    } catch (exception) {
    }
    var message = String(raw || "").trim()
    return message !== "" ? message : fallback
  }

  onOpenedChanged: if (opened) {
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  } else {
    cancelForm()
  }

  Process {
    id: workspaceListProcess
    command: ["boomux", "workspace", "list", "--json"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseWorkspaces(text) }
    onExited: function(exitCode) {
      root.finishRefresh()
      if (exitCode !== 0) {
        root.online = false
        root.workspaces = []
        root.error = "Boomux is unavailable"
      }
    }
  }

  Process {
    id: listProcess
    command: ["boomux", "list", "--json"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseShells(text) }
    onExited: function(exitCode) { root.finishRefresh() }
  }

  Process {
    id: agentProcess
    command: ["boomux", "agent", "list", "--json"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseAgents(text) }
    onExited: function(exitCode) { root.finishRefresh() }
  }

  Process {
    id: workspaceInspectProcess
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseWorkspaceDetail(text) }
  }

  Process {
    id: actionProcess
    stdout: StdioCollector { id: actionStdout; waitForEnd: true }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var action = root.pendingAction
      root.pendingAction = ""
      if (exitCode !== 0) {
        root.pendingShellName = ""
        root.pendingWorkspaceName = ""
        root.actionMessage = root.processError(actionStderr.text || actionStdout.text, "Boomux action failed")
        return
      }
      root.formMode = ""
      if (action === "create-workspace") root.actionMessage = "Workspace created"
      else if (action === "create-shell") root.actionMessage = "Shell added"
      else if (action === "create-agent") root.actionMessage = "Starting " + root.agentHost + "..."
      else if (action === "invoke-launcher") root.actionMessage = "Launcher started"
      else root.actionMessage = "Workspace opened"
      root.refresh()
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
      ? root.visibleAgents.length + " agents · " + root.workspaces.length + " workspaces"
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
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(650))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editing
      onMoveRequested: function(dx, dy) { if (dy !== 0) root.moveSelection(dy) }
      onActivateRequested: root.activateSelected()
      onCloseRequested: root.close()
      onTabRequested: function(direction) {
        root.selectTab(root.activeTab === "agents" ? "workspaces" : "agents")
      }
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refresh()
        else if (text === "1") root.selectTab("agents")
        else if (text === "2") root.selectTab("workspaces")
        else if (text === "n" || text === "N") root.showForm("workspace")
      }

      Column {
        id: contentColumn
        width: parent.width
        spacing: Style.space(10)

        PanelHero {
          width: parent.width
          title: "Boomux"
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
          trailingControl: Component {
            Button {
              text: "Open TUI"
              iconText: ""
              tooltipText: "Open the Boomux dashboard"
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.body
              iconSize: Style.font.body
              horizontalPadding: Style.space(5)
              verticalPadding: Style.space(2)
              onClicked: root.openDashboard()
            }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(6)
          Button {
            width: (parent.width - parent.spacing) / 2
            text: "Agents"
            iconText: ""
            selected: root.activeTab === "agents"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.selectTab("agents")
          }
          Button {
            width: (parent.width - parent.spacing) / 2
            text: "Workspaces"
            iconText: ""
            selected: root.activeTab === "workspaces"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.selectTab("workspaces")
          }
        }

        PanelSeparator { foreground: root.foreground }

        Item {
          visible: root.editing
          width: parent.width
          implicitHeight: formColumn.implicitHeight

          Column {
            id: formColumn
            width: parent.width
            spacing: Style.space(6)
            PanelSectionHeader {
              width: parent.width
              text: root.formMode === "workspace" ? "NEW WORKSPACE"
                : (root.formMode === "shell" ? "ADD SHELL" : "START AGENT")
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
            TextField {
              id: nameField
              width: parent.width
              placeholderText: root.formMode === "workspace" ? "Workspace name" : "Shell name"
              foreground: root.foreground
              onAccepted: cwdField.forceActiveFocus()
              Keys.onEscapePressed: root.cancelForm()
            }
            TextField {
              id: cwdField
              width: parent.width
              placeholderText: root.formMode === "workspace" ? "Default directory (optional)" : "Directory (optional)"
              foreground: root.foreground
              onAccepted: root.submitForm()
              Keys.onEscapePressed: root.cancelForm()
            }
            Row {
              visible: root.formMode === "agent"
              width: parent.width
              spacing: Style.space(6)
              Button {
                width: (parent.width - parent.spacing) / 2
                text: "OpenCode"
                selected: root.agentHost === "opencode"
                bordered: true
                foreground: root.foreground
                onClicked: root.agentHost = "opencode"
              }
              Button {
                width: (parent.width - parent.spacing) / 2
                text: "Pi"
                selected: root.agentHost === "pi"
                bordered: true
                foreground: root.foreground
                onClicked: root.agentHost = "pi"
              }
            }
            Row {
              width: parent.width
              spacing: Style.space(6)
              Button {
                width: (parent.width - parent.spacing) / 2
                text: "Cancel"
                bordered: true
                foreground: root.foreground
                onClicked: root.cancelForm()
              }
              Button {
                width: (parent.width - parent.spacing) / 2
                text: root.formMode === "agent" ? "Create & Open" : "Create"
                bordered: true
                active: true
                enabled: nameField.text.trim() !== "" && !actionProcess.running
                foreground: root.foreground
                onClicked: root.submitForm()
              }
            }
          }
        }

        Item {
          visible: root.activeTab === "agents" && !root.editing
          width: parent.width
          implicitHeight: agentColumn.implicitHeight

          Column {
            id: agentColumn
            width: parent.width
            spacing: Style.space(6)
            PanelSectionHeader {
              width: parent.width
              text: "AGENTS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
            Text {
              visible: root.visibleAgents.length === 0
              width: parent.width
              text: root.error !== "" ? root.error : "No active Boomux Agents"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              topPadding: Style.space(24)
              bottomPadding: Style.space(24)
            }
            ListView {
              id: agentList
              visible: root.visibleAgents.length > 0
              width: parent.width
              implicitHeight: Math.min(contentHeight, Style.space(390))
              model: root.visibleAgents
              spacing: Style.space(4)
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              currentIndex: root.activeTab === "agents" ? root.selectedIndex : -1
              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
              delegate: AgentRow {
                required property var modelData
                required property int index
                width: ListView.view.width
                agent: modelData
                selected: index === root.selectedIndex
                onHovered: root.selectedIndex = index
                onActivated: root.openAgent(modelData)
              }
            }
            Text {
              visible: root.visibleAgents.length > 0
              width: parent.width
              text: "Enter opens · Tab switches · R refreshes"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
            }
          }
        }

        Item {
          visible: root.activeTab === "workspaces" && !root.editing
          width: parent.width
          implicitHeight: workspaceColumn.implicitHeight

          Column {
            id: workspaceColumn
            width: parent.width
            spacing: Style.space(6)
            Row {
              width: parent.width
              PanelSectionHeader {
                width: parent.width - newWorkspaceButton.width
                anchors.verticalCenter: parent.verticalCenter
                text: "WORKSPACES"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }
              Button {
                id: newWorkspaceButton
                text: "New Workspace"
                iconText: "+"
                tooltipText: "Create workspace"
                bordered: true
                foreground: root.foreground
                fontSize: Style.font.caption
                iconSize: Style.font.body
                horizontalPadding: Style.space(6)
                verticalPadding: Style.space(2)
                onClicked: root.showForm("workspace")
              }
            }
            Text {
              visible: root.workspaces.length === 0
              width: parent.width
              text: root.error !== "" ? root.error : "No Boomux workspaces"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              topPadding: Style.space(18)
              bottomPadding: Style.space(18)
            }
            ListView {
              id: workspaceList
              visible: root.workspaces.length > 0
              width: parent.width
              implicitHeight: Math.min(contentHeight, Style.space(430))
              model: root.workspaces
              spacing: Style.space(6)
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              currentIndex: root.activeTab === "workspaces" ? root.selectedIndex : -1
              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
              delegate: Item {
                id: workspaceCard
                required property var modelData
                required property int index
                readonly property bool expanded: modelData.id === root.selectedWorkspaceId
                  && root.workspaceDetail !== null
                  && root.workspaceDetail.id === modelData.id

                width: ListView.view.width
                height: cardColumn.implicitHeight

                Column {
                  id: cardColumn
                  width: parent.width
                  spacing: Style.space(5)

                  Rectangle {
                    width: parent.width
                    height: Style.space(52)
                    radius: Style.cornerRadius
                    color: workspaceCard.expanded
                      ? Style.selectedFillFor(root.foreground, Color.accent)
                      : (workspaceMouse.containsMouse
                        ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                        : "transparent")

                    Column {
                      anchors.left: parent.left
                      anchors.leftMargin: Style.space(10)
                      anchors.right: expandGlyph.left
                      anchors.rightMargin: Style.space(8)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(2)
                      Text {
                        width: parent.width
                        text: String(workspaceCard.modelData.name)
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        font.bold: workspaceCard.expanded
                        elide: Text.ElideRight
                      }
                      Text {
                        width: parent.width
                        text: workspaceCard.modelData.shell_count + " items · "
                          + workspaceCard.modelData.agent_count + " agents"
                        color: workspaceCard.modelData.attention_count > 0 ? root.urgent : root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }

                    Text {
                      id: expandGlyph
                      anchors.right: parent.right
                      anchors.rightMargin: Style.space(10)
                      anchors.verticalCenter: parent.verticalCenter
                      text: workspaceCard.expanded ? "⌃" : "⌄"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                    }

                    MouseArea {
                      id: workspaceMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      onEntered: root.selectedIndex = workspaceCard.index
                      onClicked: root.selectWorkspace(workspaceCard.modelData.id)
                      onDoubleClicked: root.openWorkspace(workspaceCard.modelData)
                    }
                  }

                  Row {
                    visible: workspaceCard.expanded
                    width: parent.width
                    spacing: Style.space(5)
                    Button {
                      width: (parent.width - parent.spacing * 2) / 3
                      text: "Open"
                      iconText: ""
                      tooltipText: "Open this workspace"
                      bordered: true
                      foreground: root.foreground
                      fontSize: Style.font.caption
                      iconSize: Style.font.body
                      onClicked: root.openWorkspace(workspaceCard.modelData)
                    }
                    Button {
                      width: (parent.width - parent.spacing * 2) / 3
                      text: "Shell"
                      iconText: "+"
                      tooltipText: "Add shell to this workspace"
                      bordered: true
                      foreground: root.foreground
                      fontSize: Style.font.caption
                      iconSize: Style.font.body
                      onClicked: root.showForm("shell")
                    }
                    Button {
                      width: (parent.width - parent.spacing * 2) / 3
                      text: "Agent"
                      iconText: "+"
                      tooltipText: "Start Agent in this workspace"
                      bordered: true
                      foreground: root.foreground
                      fontSize: Style.font.caption
                      iconSize: Style.font.body
                      onClicked: root.showForm("agent")
                    }
                  }

                  PanelSectionHeader {
                    visible: workspaceCard.expanded
                    width: parent.width
                    text: "ITEMS"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                  }

                  Text {
                    visible: workspaceCard.expanded && root.workspaceItems.length === 0
                    width: parent.width
                    text: "Empty workspace · add a shell or Agent"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: Style.space(12)
                    bottomPadding: Style.space(12)
                  }

                  Repeater {
                    model: workspaceCard.expanded ? root.workspaceItems : []
                    delegate: Rectangle {
                      required property var modelData
                      width: workspaceCard.width
                      height: Style.space(54)
                      radius: Style.cornerRadius
                      color: itemMouse.containsMouse
                        ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                        : "transparent"
                      Text {
                        id: kindGlyph
                        anchors.left: parent.left
                        anchors.leftMargin: Style.space(9)
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.kind === "agent" ? "●"
                          : (modelData.kind === "command" ? ">" : (modelData.kind === "launcher" ? "↗" : "○"))
                        color: modelData.status === "blocked" ? root.urgent
                          : (modelData.status === "working" || modelData.status === "running" ? Color.accent : root.dim)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                      }
                      Column {
                        anchors.left: kindGlyph.right
                        anchors.leftMargin: Style.space(10)
                        anchors.right: parent.right
                        anchors.rightMargin: Style.space(9)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Style.space(1)
                        Text {
                          width: parent.width
                          text: String(modelData.name) + "  ·  " + String(modelData.kind)
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.body
                          elide: Text.ElideRight
                        }
                        Text {
                          width: parent.width
                          text: String(modelData.status) + (modelData.detail ? " · " + String(modelData.detail) : "")
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          elide: Text.ElideMiddle
                        }
                      }
                      MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.openWorkspaceItem(modelData)
                      }
                    }
                  }
                }
              }
            }
          }
        }

        Text {
          visible: root.actionMessage !== ""
          width: parent.width
          text: root.actionMessage
          color: root.actionMessage.toLowerCase().indexOf("failed") >= 0 ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
        }
      }
    }
  }

  component AgentRow: Rectangle {
    id: agentRow
    property var agent
    property bool selected: false
    signal hovered
    signal activated
    readonly property string state: agent && agent.observation ? agent.observation.state : "unknown"
    readonly property bool needsAttention: root.agentNeedsAttention(agent)
    readonly property bool justCompleted: agent ? !!root.completedAgents[agent.id] : false

    height: Style.space(66)
    radius: Style.cornerRadius
    color: selected ? Style.selectedFillFor(root.foreground, Color.accent)
      : (agentMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06) : "transparent")
    Text {
      id: agentGlyph
      anchors.left: parent.left
      anchors.leftMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      text: agentRow.needsAttention ? "!" : (agentRow.justCompleted ? "✓" : (agentRow.state === "working" ? "●" : "○"))
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
        text: agent ? String(agent.workspace_name) + " / " + root.agentDisplayName(agent) : "Agent"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: agentRow.selected
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        text: (agentRow.justCompleted ? "finished" : agentRow.state)
          + (agentRow.needsAttention ? " · needs attention" : "")
          + (agent && agent.integration ? " · " + String(agent.integration) : "")
          + (agent && agent.observation && agent.observation.evidence ? " · " + String(agent.observation.evidence) : "")
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
      onEntered: agentRow.hovered()
      onClicked: agentRow.activated()
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
