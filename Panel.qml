import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
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
  readonly property string home: Quickshell.env("HOME") || ""

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
  property var acknowledgeQueue: []
  property var activeAcknowledgement: null
  property var automaticAttentionRevisions: ({})
  property var pendingOpenAgent: null
  property string inspectRequestedId: ""
  property string inspectActiveId: ""
  property string error: ""
  property string actionMessage: ""
  property string formMode: ""
  property string agentHost: "opencode"
  property string pendingAction: ""
  property string pendingWorkspaceName: ""
  property string pendingShellName: ""

  readonly property var visibleAgents: agents.filter(function(agent) {
    var state = agent.observation ? agent.observation.state : "unknown"
    return !agentIsScheduleOwned(agent)
      && ((agentIsProjectedCurrent(agent) && state !== "inactive" && state !== "done")
        || attentionRevision(agent) > 0)
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
  readonly property int completedCount: countCompletedAgents()
  readonly property bool editing: formMode !== ""

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (daemonStatusProcess.running) return
    daemonStatusProcess.running = true
  }

  function refreshData() {
    if (workspaceListProcess.running || listProcess.running || agentProcess.running) return
    refreshing = true
    refreshPending = 3
    error = ""
    workspaceListProcess.running = true
    listProcess.running = true
    agentProcess.running = true
  }

  function setOffline(message) {
    online = false
    refreshing = false
    workspaces = []
    shells = []
    agents = []
    workspaceDetail = null
    selectedWorkspaceId = ""
    previousAgentStates = ({})
    completedAgents = ({})
    automaticAttentionRevisions = ({})
    agentBaselineReady = false
    error = message
  }

  function parseDaemonStatus(raw) {
    try {
      var data = parseEnvelope(raw, "daemon.status")
      if (data.status !== "running") {
        setOffline("Boomux daemon is stopped")
        return
      }
      refreshData()
    } catch (exception) {
      setOffline("Boomux daemon is stopped")
    }
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
      syncWorkspaceIndex()
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
      var nextAutomaticAttentionRevisions = ({})

      for (var i = 0; i < nextAgents.length; i++) {
        var agent = nextAgents[i]
        if (agentIsScheduleOwned(agent)) continue
        var state = agent.observation ? agent.observation.state : "unknown"
        var attentionRevision = root.attentionRevision(agent)
        nextStates[agent.id] = state
        if (completedAgents[agent.id] && state === "idle") nextCompleted[agent.id] = true
        if (agentBaselineReady && previousAgentStates[agent.id] === "working" && state === "idle")
          nextCompleted[agent.id] = true
        if (state === "working" && attentionRevision > 0 && attentionReason(agent) === "blocked") {
          nextAutomaticAttentionRevisions[agent.id] = attentionRevision
          if (automaticAttentionRevisions[agent.id] !== attentionRevision)
            acknowledgeAgent(agent, false, true)
        }
      }

      previousAgentStates = nextStates
      completedAgents = nextCompleted
      automaticAttentionRevisions = nextAutomaticAttentionRevisions
      agentBaselineReady = true
      agents = nextAgents
      clampSelection()
    } catch (exception) {
      agents = []
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function inspectWorkspace(workspaceId) {
    inspectRequestedId = String(workspaceId || "")
    if (inspectRequestedId === "" || workspaceInspectProcess.running) return
    inspectActiveId = inspectRequestedId
    workspaceInspectProcess.command = ["boomux", "workspace", "inspect", inspectActiveId, "--json"]
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
    if (tab === "workspaces") syncWorkspaceIndex()
    else selectedIndex = 0
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
    syncWorkspaceIndex()
    workspaceDetail = null
    inspectWorkspace(selectedWorkspaceId)
  }

  function syncWorkspaceIndex() {
    if (activeTab !== "workspaces") return
    for (var i = 0; i < workspaces.length; i++) {
      if (workspaces[i].id === selectedWorkspaceId) {
        selectedIndex = i
        return
      }
    }
    clampSelection()
  }

  function compactPath(path) {
    var value = String(path || "")
    if (home !== "" && value === home) return "~"
    return home !== "" && value.indexOf(home + "/") === 0 ? "~" + value.substring(home.length) : value
  }

  function currentAgentForShell(shell) {
    if (!workspaceDetail || !workspaceDetail.agents || !shell) return null
    for (var i = 0; i < workspaceDetail.agents.length; i++) {
      var agent = workspaceDetail.agents[i]
      var state = agent.observation ? agent.observation.state : "unknown"
      if (agent.shell_id === shell.id && agent.run_id === (shell.run ? shell.run.id : "")
          && state !== "inactive" && state !== "done" && agentIsProjectedCurrent(agent)) return agent
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

  function openShell(shell, agent) {
    if (!shell || !shell.id || openProcess.running) return
    pendingOpenAgent = agent || null
    actionMessage = "Opening terminal..."
    openProcess.command = ["boomux", "open", String(shell.id), "--takeover"]
    openProcess.running = true
  }

  function openAgent(agent) {
    if (!agent) return
    if (!agentShellRetained(agent)) {
      if (attentionRevision(agent) > 0) {
        actionMessage = "Acknowledging attention for removed shell..."
        acknowledgeAgent(agent)
      } else {
        actionMessage = "This Agent's shell was removed"
      }
      return
    }
    openShell({ id: agent.shell_id }, agent)
  }

  function agentShellRetained(agent) {
    if (!agent || !agent.shell_id) return false
    for (var i = 0; i < shells.length; i++)
      if (shells[i].id === agent.shell_id) return true
    return false
  }

  function agentIsCurrent(agent) {
    if (!agent || !agent.shell_id || !agent.run_id) return false
    for (var i = 0; i < shells.length; i++) {
      var shell = shells[i]
      if (shell.id === agent.shell_id && shell.run && shell.run.id === agent.run_id)
        return true
    }
    return false
  }

  function agentIsScheduleOwned(agent) {
    if (!agent || !agent.shell_id) return false
    for (var i = 0; i < shells.length; i++)
      if (shells[i].id === agent.shell_id) return shells[i].owner === "schedule"
    return false
  }

  function agentIsProjectedCurrent(agent) {
    if (!agentIsCurrent(agent)) return false
    var observedAt = agent.observation ? Number(agent.observation.observed_at_ms || 0) : 0
    var startedAt = Number(agent.started_at_ms || 0)
    for (var i = 0; i < agents.length; i++) {
      var candidate = agents[i]
      var state = candidate.observation ? candidate.observation.state : "unknown"
      if (candidate.id === agent.id || candidate.shell_id !== agent.shell_id
          || candidate.run_id !== agent.run_id || state === "inactive" || state === "done") continue
      var candidateObservedAt = candidate.observation
        ? Number(candidate.observation.observed_at_ms || 0) : 0
      var candidateStartedAt = Number(candidate.started_at_ms || 0)
      if (candidateObservedAt > observedAt
          || (candidateObservedAt === observedAt && candidateStartedAt > startedAt)
          || (candidateObservedAt === observedAt && candidateStartedAt === startedAt
            && String(candidate.id) > String(agent.id))) return false
    }
    return true
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
    openShell(item.shell, item.agent)
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

  function attentionReason(agent) {
    return agent && agent.attention && agent.attention.reason ? String(agent.attention.reason) : ""
  }

  function agentNeedsAttention(agent) {
    return attentionRevision(agent) > 0 && attentionReason(agent) === "blocked"
  }

  function acknowledgeAgent(agent, dismissed, automatic) {
    var revision = attentionRevision(agent)
    if (revision <= 0) return
    var queue = acknowledgeQueue.slice()
    for (var i = 0; i < queue.length; i++) {
      if (queue[i].agentId !== String(agent.id) || queue[i].revision !== revision) continue
      if (dismissed) {
        queue[i].dismissed = true
        queue[i].automatic = false
        acknowledgeQueue = queue
      }
      return
    }
    queue.push({
      agentId: String(agent.id),
      revision: revision,
      dismissed: !!dismissed,
      automatic: !!automatic
    })
    acknowledgeQueue = queue
    startNextAcknowledgement()
  }

  function dismissAgent(agent) {
    if (!agent || (!completedAgents[agent.id] && attentionRevision(agent) <= 0)) return
    clearCompletedAgent(agent.id)
    if (attentionRevision(agent) > 0) {
      actionMessage = "Dismissing Agent notification..."
      acknowledgeAgent(agent, true)
    } else {
      actionMessage = "Agent notification dismissed"
    }
  }

  function startNextAcknowledgement() {
    if (acknowledgeProcess.running || acknowledgeQueue.length === 0) return
    activeAcknowledgement = acknowledgeQueue[0]
    acknowledgeProcess.command = ["boomux", "attention", "acknowledge",
      activeAcknowledgement.agentId, "--observation-revision",
      String(activeAcknowledgement.revision), "--json"]
    acknowledgeProcess.running = true
  }

  function countCompletedAgents() {
    var completed = ({})
    for (var i = 0; i < agents.length; i++) {
      if (agentIsScheduleOwned(agents[i])) continue
      if (completedAgents[agents[i].id] && agentIsProjectedCurrent(agents[i]))
        completed[agents[i].id] = true
      if (attentionReason(agents[i]) === "completed" && attentionRevision(agents[i]) > 0)
        completed[agents[i].id] = true
    }
    return Object.keys(completed).length
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
    cwdField.text = mode !== "workspace" && workspaceDetail && workspaceDetail.default_cwd
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
    id: daemonStatusProcess
    command: ["boomux", "daemon", "status", "--json"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseDaemonStatus(text) }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.setOffline("Boomux daemon is stopped")
    }
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
    onExited: function(exitCode) {
      if (root.inspectRequestedId !== "" && root.inspectRequestedId !== root.inspectActiveId)
        root.inspectWorkspace(root.inspectRequestedId)
    }
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
      root.cancelForm()
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
      var agent = root.pendingOpenAgent
      root.pendingOpenAgent = null
      if (exitCode !== 0) {
        root.actionMessage = "Could not open terminal"
        return
      }
      if (agent) {
        root.clearCompletedAgent(agent.id)
        root.acknowledgeAgent(agent)
      }
      root.actionMessage = ""
      root.close()
    }
  }

  Process {
    id: acknowledgeProcess
    stdout: StdioCollector { id: acknowledgeStdout; waitForEnd: true }
    stderr: StdioCollector { id: acknowledgeStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var dismissed = root.activeAcknowledgement && root.activeAcknowledgement.dismissed
      var automatic = root.activeAcknowledgement && root.activeAcknowledgement.automatic
      if (exitCode !== 0)
        root.actionMessage = root.processError(acknowledgeStderr.text || acknowledgeStdout.text,
          dismissed ? "Could not dismiss Agent notification"
            : (automatic ? "Could not clear resumed Agent attention" : "Could not acknowledge Agent attention"))
      else if (root.opened && !automatic)
        root.actionMessage = dismissed ? "Agent notification dismissed" : "Agent attention acknowledged"
      var queue = root.acknowledgeQueue.slice()
      if (queue.length > 0) queue.shift()
      root.acknowledgeQueue = queue
      root.activeAcknowledgement = null
      root.refresh()
      root.startNextAcknowledgement()
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
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveSelection(dy)
      }
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
        else if ((text === "d" || text === "D") && root.activeTab === "agents")
          root.dismissAgent(root.selectedItem)
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
                onDismissed: root.dismissAgent(modelData)
              }
            }
            Text {
              visible: root.visibleAgents.length > 0
              width: parent.width
              text: "Enter opens · D dismisses · Tab switches · R refreshes"
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
              implicitHeight: Math.min(contentHeight, Style.space(150))
              model: root.workspaces
              spacing: Style.space(3)
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              currentIndex: root.activeTab === "workspaces" ? root.selectedIndex : -1
              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
              delegate: Rectangle {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: Style.space(50)
                radius: Style.cornerRadius
                color: modelData.id === root.selectedWorkspaceId
                  ? Style.selectedFillFor(root.foreground, Color.accent)
                  : (workspaceMouse.containsMouse
                    ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                    : "transparent")
                Column {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(10)
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)
                  Text {
                    width: parent.width
                    text: String(modelData.name)
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: modelData.id === root.selectedWorkspaceId
                    elide: Text.ElideRight
                  }
                  Text {
                    width: parent.width
                    text: (modelData.shell_count + modelData.launcher_count) + " items · "
                      + modelData.agent_count + " agents"
                    color: modelData.attention_count > 0 ? root.urgent : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
                MouseArea {
                  id: workspaceMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  onEntered: root.selectedIndex = index
                  onClicked: root.selectWorkspace(modelData.id)
                  onDoubleClicked: root.openWorkspace(modelData)
                }
              }
            }

            BorderSurface {
              visible: root.workspaceDetail !== null
              width: parent.width
              implicitHeight: detailColumn.implicitHeight + Style.space(18)
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.025)
              borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
              radius: Style.cornerRadius

              Column {
                id: detailColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(9)
                spacing: Style.space(6)

                Text {
                  width: parent.width
                  text: root.workspaceDetail ? String(root.workspaceDetail.name) : ""
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  text: root.workspaceDetail && root.workspaceDetail.default_cwd
                    ? root.compactPath(root.workspaceDetail.default_cwd) : "No default directory"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideMiddle
                }

                Row {
                  width: parent.width
                  spacing: Style.space(5)
                  Button {
                    width: (parent.width - parent.spacing * 2) / 3
                    text: "Open"
                    iconText: ""
                    tooltipText: "Open selected workspace"
                    bordered: true
                    foreground: root.foreground
                    fontSize: Style.font.caption
                    iconSize: Style.font.body
                    onClicked: root.openWorkspace(root.workspaceDetail)
                  }
                  Button {
                    width: (parent.width - parent.spacing * 2) / 3
                    text: "Shell"
                    iconText: "+"
                    tooltipText: "Add shell to selected workspace"
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
                    tooltipText: "Start Agent in selected workspace"
                    bordered: true
                    foreground: root.foreground
                    fontSize: Style.font.caption
                    iconSize: Style.font.body
                    onClicked: root.showForm("agent")
                  }
                }

                PanelSectionHeader {
                  width: parent.width
                  text: "ITEMS"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                }

                Text {
                  visible: root.workspaceItems.length === 0
                  width: parent.width
                  text: "Empty workspace · add a shell or Agent"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  horizontalAlignment: Text.AlignHCenter
                  topPadding: Style.space(10)
                  bottomPadding: Style.space(10)
                }

                ListView {
                  id: itemList
                  width: parent.width
                  implicitHeight: Math.min(contentHeight, Style.space(220))
                  model: root.workspaceItems
                  spacing: Style.space(3)
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds
                  ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                  delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
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
                        text: String(modelData.status) + (modelData.detail
                          ? " · " + (modelData.kind === "shell"
                            ? root.compactPath(modelData.detail) : String(modelData.detail)) : "")
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
    signal dismissed
    readonly property string state: agent && agent.observation ? agent.observation.state : "unknown"
    readonly property bool needsAttention: root.agentNeedsAttention(agent)
    readonly property bool justCompleted: agent
      ? !!root.completedAgents[agent.id] || root.attentionReason(agent) === "completed" : false
    readonly property bool dismissible: agent
      ? !!root.completedAgents[agent.id] || root.attentionRevision(agent) > 0 : false

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
      anchors.rightMargin: agentRow.dismissible ? Style.space(86) : Style.space(10)
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
          + (agent && !root.agentShellRetained(agent)
            ? (root.attentionRevision(agent) > 0
              ? " · shell removed · dismiss notification" : " · shell removed") : "")
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
    Button {
      visible: agentRow.dismissible
      z: 1
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: "Dismiss"
      tooltipText: "Dismiss Agent notification"
      bordered: true
      foreground: root.foreground
      fontSize: Style.font.caption
      horizontalPadding: Style.space(6)
      verticalPadding: Style.space(2)
      onClicked: agentRow.dismissed()
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
