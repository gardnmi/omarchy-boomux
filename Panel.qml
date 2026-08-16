import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Qt.labs.folderlistmodel
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
  property var schedules: []
  property var executions: []
  property var nodes: []
  property var projects: []
  property var workspaceDetail: null
  property string selectedWorkspaceKey: ""
  property string selectedScheduleKey: ""
  property string activeTab: "agents"
  property int selectedIndex: 0
  property bool online: false
  property bool refreshing: false
  property int refreshPending: 0
  property bool capabilitiesReady: false
  property bool federationSupported: false
  property var cliFeatures: []
  property bool scheduleCommandsSupported: false
  property bool projectListSupported: false
  property bool shellNameSuggestionSupported: false
  property bool projectRootsConfigured: false
  property int daemonProtocolVersion: 0
  property string schedulerState: "offline"
  property int schedulerActiveExecutions: 0
  property int schedulerMaxConcurrent: 0
  property bool agentBaselineReady: false
  property var previousAgentStates: ({})
  property var completedAgents: ({})
  property var acknowledgeQueue: []
  property var activeAcknowledgement: null
  property var automaticAttentionRevisions: ({})
  property var pendingOpenAgent: null
  property string pendingOpenKey: ""
  property string pendingExecutionOpenKey: ""
  property var itemToRemove: null
  property string inspectRequestedKey: ""
  property string inspectActiveKey: ""
  property string error: ""
  property string scheduleError: ""
  property string executionError: ""
  property string actionMessage: ""
  property string formMode: ""
  property string workspaceCreationMode: "custom"
  property string projectQuery: ""
  property int selectedProjectIndex: 0
  property string projectError: ""
  property bool cwdIsExact: false
  property bool nameFieldEdited: false
  property string suggestedNameRequestedWorkspaceKey: ""
  property string suggestedNameActiveWorkspaceKey: ""
  property bool directoryPickerOpen: false
  property string directoryPickerPath: ""
  property int directoryPickerIndex: 0
  property string agentHost: "opencode"
  property var pendingAction: null
  property var pendingWorkspace: null
  property var pendingShell: null
  property string projectNodeId: ""
  property string executionRequestedScheduleKey: ""
  property string executionActiveScheduleKey: ""
  property int pollEpoch: 0
  property int snapshotActiveEpoch: 0

  readonly property var visibleWorkspaces: workspaces
  readonly property var visibleSchedules: schedules

  readonly property var visibleAgents: agents.filter(function(agent) {
    var state = agent.observation ? agent.observation.state : "unknown"
    return !agentIsScheduleOwned(agent)
      && ((agentIsProjectedCurrent(agent) && state !== "inactive" && state !== "done")
        || attentionRevision(agent) > 0)
  })
  readonly property var selectedWorkspace: {
    for (var i = 0; i < workspaces.length; i++)
      if (workspaces[i].key === selectedWorkspaceKey) return workspaces[i]
    return null
  }
  readonly property bool scheduleAvailable: scheduleCommandsSupported && daemonProtocolVersion >= 25
  readonly property bool federationAvailable: federationSupported && daemonProtocolVersion >= 33
  readonly property var selectedSchedule: {
    for (var i = 0; i < schedules.length; i++)
      if (schedules[i].key === selectedScheduleKey) return schedules[i]
    return null
  }
  readonly property var selectedExecutions: executions.filter(function(execution) {
    return execution.schedule_key === selectedScheduleKey
  })
  readonly property var latestExecution: selectedExecutions.length > 0 ? selectedExecutions[0] : null
  readonly property var visibleProjects: filterProjects()
  readonly property var selectedProject: selectedProjectIndex >= 0
    && selectedProjectIndex < visibleProjects.length ? visibleProjects[selectedProjectIndex] : null
  readonly property var workspaceItems: buildWorkspaceItems()
  readonly property int itemCount: activeTab === "agents" ? visibleAgents.length
    : (activeTab === "workspaces" ? visibleWorkspaces.length : visibleSchedules.length)
  readonly property var selectedItem: {
    var model = activeTab === "agents" ? visibleAgents
      : (activeTab === "workspaces" ? visibleWorkspaces : visibleSchedules)
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

  onProjectQueryChanged: {
    selectedProjectIndex = 0
    clampProjectSelection()
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: capabilityProcess.running = true

  function resourceId(value) {
    return value && typeof value === "object" ? String(value.inner_id || "") : String(value || "")
  }

  function resourceNode(value, fallback) {
    return value && typeof value === "object" ? String(value.node_id || fallback || "")
      : String(fallback || "")
  }

  function resourceKey(nodeId, value) {
    return String(nodeId || "") + "\u001f" + resourceId(value)
  }

  function nodeFor(nodeId) {
    for (var i = 0; i < nodes.length; i++) if (nodes[i].node_id === nodeId) return nodes[i]
    return null
  }

  function nodeIsActionable(nodeId, capability) {
    var node = nodeFor(nodeId)
    if (!node) return !federationAvailable && nodeId === "local"
    if (!node.current || node.stale || node.health !== "online") return false
    if (node.local || !capability) return true
    return cliFeatures.indexOf(capability) >= 0
      && node.observed_capabilities.indexOf(capability) >= 0
  }

  function nodeArgs(nodeId, capability) {
    var node = nodeFor(nodeId)
    if (!node || node.local) return []
    return nodeIsActionable(nodeId, capability) ? ["--node", nodeId] : null
  }

  function selectedCreationNode() {
    for (var i = 0; i < nodes.length; i++) if (nodes[i].local) return nodes[i]
    return { node_id: "local", alias: "local", local: true, current: online, stale: false }
  }

  function nodeName(item) {
    return String(item && item.node_alias ? item.node_alias : "local")
  }

  function nodeHealthLabel(node) {
    if (!node) return "unknown"
    return String(node.health).split("_").join(" ") + (node.stale ? " · stale cache" : "")
  }

  function shellOwner(owner) {
    if (typeof owner === "string") return owner
    return owner && owner.kind === "schedule" ? "schedule" : "user"
  }

  function shellStatus(status) {
    if (typeof status === "string") return status
    return status && status.exited !== undefined ? "exited" : "unknown"
  }

  function refresh() {
    if (daemonStatusProcess.running) return
    daemonStatusProcess.running = true
  }

  function refreshData() {
    if (nodeSnapshotProcess.running || workspaceListProcess.running || listProcess.running
        || agentProcess.running || scheduleListProcess.running || executionListProcess.running) return
    if (federationAvailable) {
      refreshing = true
      refreshPending = 1
      error = ""
      snapshotActiveEpoch = pollEpoch
      nodeSnapshotProcess.running = true
      return
    }
    var loadSchedules = opened && activeTab === "schedules" && scheduleAvailable
    refreshing = true
    refreshPending = loadSchedules ? 5 : 3
    error = ""
    if (loadSchedules) {
      scheduleError = ""
      executionError = ""
    }
    workspaceListProcess.running = true
    listProcess.running = true
    if (loadSchedules) {
      scheduleListProcess.running = true
    }
  }

  function setOffline(message) {
    pollEpoch++
    online = false
    refreshing = false
    workspaces = []
    shells = []
    agents = []
    schedules = []
    executions = []
    nodes = []
    workspaceDetail = null
    selectedWorkspaceKey = ""
    selectedScheduleKey = ""
    itemToRemove = null
    daemonProtocolVersion = 0
    schedulerState = "offline"
    schedulerActiveExecutions = 0
    schedulerMaxConcurrent = 0
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
      daemonProtocolVersion = Number(data.protocol_version || 0)
      schedulerState = data.scheduler && data.scheduler.state
        ? String(data.scheduler.state) : "offline"
      schedulerActiveExecutions = data.scheduler
        ? Number(data.scheduler.active_executions || 0) : 0
      schedulerMaxConcurrent = data.scheduler
        ? Number(data.scheduler.max_concurrent || 0) : 0
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

  function parseCapabilities(raw) {
    try {
      var data = parseEnvelope(raw, "capabilities")
      if (!Array.isArray(data.json_commands)) throw new Error("missing JSON commands")
      cliFeatures = Array.isArray(data.features) ? data.features : []
      var required = ["schedule.list", "schedule.pause", "schedule.resume",
        "schedule.run", "execution.list", "execution.open"]
      scheduleCommandsSupported = required.every(function(command) {
        return data.json_commands.indexOf(command) >= 0
      })
      projectListSupported = data.json_commands.indexOf("project.list") >= 0
      shellNameSuggestionSupported = data.json_commands.indexOf("shell.suggest-name") >= 0
      federationSupported = data.json_commands.indexOf("node.snapshot") >= 0
        && cliFeatures.indexOf("combined_node_snapshot") >= 0
        && cliFeatures.indexOf("node_qualified_dashboard") >= 0
        && cliFeatures.indexOf("typed_exact_node_routing") >= 0
    } catch (exception) {
      scheduleCommandsSupported = false
      projectListSupported = false
      shellNameSuggestionSupported = false
      federationSupported = false
      cliFeatures = []
      console.warn("io.github.gardnmi.boomux:", exception)
    }
    capabilitiesReady = true
  }

  function normalizeAgent(source, node, workspaceName) {
    var id = resourceId(source.id)
    var workspaceId = resourceId(source.workspace_id)
    var shellId = resourceId(source.shell_id)
    var runId = resourceId(source.run_id)
    var observation = source.observation || {
      revision: Number(source.observation_revision || 0),
      state: String(source.state || "unknown"),
      authority: "daemon_lifecycle",
      evidence: node.local ? "" : "cached reduced observation",
      confidence: 0,
      observed_at_ms: Number(source.observed_at_ms || 0)
    }
    var attention = source.attention || null
    if (attention && !attention.observation) attention = {
      reason: attention.reason,
      observation: {
        revision: Number(attention.observation_revision || 0),
        observed_at_ms: Number(attention.observed_at_ms || 0)
      }
    }
    return Object.assign({}, source, {
      id: id, key: resourceKey(node.node_id, id), node_id: node.node_id,
      node_alias: node.alias, node_current: node.current, node_stale: node.stale,
      workspace_id: workspaceId, workspace_key: resourceKey(node.node_id, workspaceId),
      workspace_name: String(source.workspace_name || workspaceName || "unknown"),
      shell_id: shellId, shell_key: resourceKey(node.node_id, shellId), run_id: runId,
      observation: observation, attention: attention
    })
  }

  function normalizeSchedule(source, node, workspaceName) {
    var id = resourceId(source.id)
    var workspaceId = resourceId(source.workspace_id)
    var trigger = source.trigger || {}
    return Object.assign({}, source, {
      id: id, key: resourceKey(node.node_id, id), node_id: node.node_id,
      node_alias: node.alias, node_current: node.current, node_stale: node.stale,
      workspace_id: workspaceId, workspace_key: resourceKey(node.node_id, workspaceId),
      workspace_name: String(source.workspace_name || workspaceName || "unknown"),
      cron: String(source.cron || trigger.cron || ""),
      timezone: String(source.timezone || trigger.timezone || ""),
      session_mode: source.session_mode || (source.session && source.session.continue ? "continue" : "fresh"),
      cwd: source.cwd || (node.local ? "" : "remote path available on owner")
    })
  }

  function normalizeExecution(source, node) {
    var id = resourceId(source.id)
    var scheduleId = resourceId(source.schedule_id)
    return Object.assign({}, source, {
      id: id, key: resourceKey(node.node_id, id), node_id: node.node_id,
      node_alias: node.alias, node_current: node.current, node_stale: node.stale,
      schedule_id: scheduleId, schedule_key: resourceKey(node.node_id, scheduleId),
      workspace_id: resourceId(source.workspace_id), shell_id: resourceId(source.shell_id),
      run_id: resourceId(source.run_id), agent_id: resourceId(source.agent_id)
    })
  }

  function parseNodeSnapshot(raw) {
    try {
      if (snapshotActiveEpoch !== pollEpoch) return
      var data = parseEnvelope(raw, "node.snapshot")
      if (!Array.isArray(data.nodes)) throw new Error("missing Nodes")
      var nextNodes = [], nextWorkspaces = [], nextShells = [], nextAgents = []
      var nextSchedules = [], nextExecutions = []
      for (var n = 0; n < data.nodes.length; n++) {
        var rawNode = data.nodes[n]
        if (!rawNode || typeof rawNode.node_id !== "string" || typeof rawNode.alias !== "string")
          throw new Error("invalid Node")
        var node = {
          node_id: rawNode.node_id, alias: rawNode.alias, local: !!rawNode.local,
          health: String(rawNode.health || "unobserved"), current: !!rawNode.current,
          stale: !!rawNode.stale, observed_at_ms: Number(rawNode.observed_at_ms || 0),
          observed_protocol_version: Number(rawNode.observed_protocol_version || 0),
          observed_capabilities: Array.isArray(rawNode.observed_capabilities)
            ? rawNode.observed_capabilities : [],
          scheduler: rawNode.scheduler || { state: "offline", active_executions: 0, max_concurrent: 0 }
        }
        nextNodes.push(node)
        var projection = node.local ? rawNode.local_snapshot : rawNode.remote_projection
        if (!projection) continue
        var projectedWorkspaces = projection.workspaces || []
        var projectedShells = node.local ? [] : (projection.shells || [])
        var projectedLaunchers = node.local ? [] : (projection.launchers || [])
        var projectedAgents = node.local ? [] : (projection.agents || [])
        var projectedSchedules = node.local ? [] : (projection.schedules || [])
        for (var w = 0; w < projectedWorkspaces.length; w++) {
          var rawWorkspace = projectedWorkspaces[w]
          var workspaceId = resourceId(rawWorkspace.id)
          var workspace = Object.assign({}, rawWorkspace, {
            id: workspaceId, key: resourceKey(node.node_id, workspaceId), node_id: node.node_id,
            node_alias: node.alias, node_current: node.current, node_stale: node.stale,
            node_health: node.health, shells: [], launchers: [], agents: [], schedules: []
          })
          if (node.local) {
            workspace.shells = rawWorkspace.shells || []
            workspace.launchers = rawWorkspace.launchers || []
            workspace.agents = rawWorkspace.agents || []
            workspace.schedules = rawWorkspace.schedules || []
          } else {
            workspace.shells = projectedShells.filter(function(item) {
              return resourceId(item.workspace_id) === workspaceId
            })
            workspace.launchers = projectedLaunchers.filter(function(item) {
              return resourceId(item.workspace_id) === workspaceId
            })
            workspace.agents = projectedAgents.filter(function(item) {
              return resourceId(item.workspace_id) === workspaceId
            })
            workspace.schedules = projectedSchedules.filter(function(item) {
              return resourceId(item.workspace_id) === workspaceId
            })
          }
          workspace.shell_count = workspace.shells.length
          workspace.launcher_count = workspace.launchers.length
          workspace.schedule_count = workspace.schedules.length
          nextWorkspaces.push(workspace)
          for (var s = 0; s < workspace.shells.length; s++) {
            var shell = workspace.shells[s]
            var shellId = resourceId(shell.id)
            var owner = shellOwner(shell.owner)
            nextShells.push(Object.assign({}, shell, {
              id: shellId, key: resourceKey(node.node_id, shellId), node_id: node.node_id,
              node_alias: node.alias, node_current: node.current, node_stale: node.stale,
              workspace_id: workspaceId, workspace_key: workspace.key, workspace_name: workspace.name,
              owner: owner, status: shellStatus(shell.status),
              run: shell.run || (shell.run_id ? { id: resourceId(shell.run_id) } : null)
            }))
          }
          for (var a = 0; a < workspace.agents.length; a++)
            nextAgents.push(normalizeAgent(workspace.agents[a], node, workspace.name))
          for (var q = 0; q < workspace.schedules.length; q++)
            nextSchedules.push(normalizeSchedule(workspace.schedules[q], node, workspace.name))
        }
        var projectedExecutions = node.local ? [] : (projection.executions || [])
        for (var e = 0; e < projectedExecutions.length; e++)
          nextExecutions.push(normalizeExecution(projectedExecutions[e], node))
      }
      nodes = nextNodes
      workspaces = nextWorkspaces
      shells = nextShells
      schedules = nextSchedules
      executions = nextExecutions
      applyAgentSnapshot(nextAgents)
      online = true
      if (pendingWorkspace) {
        for (var p = 0; p < workspaces.length; p++) {
          if (workspaces[p].node_id === pendingWorkspace.nodeId
              && workspaces[p].name === pendingWorkspace.name) {
            selectedWorkspaceKey = workspaces[p].key
            pendingWorkspace = null
            break
          }
        }
      }
      preserveSelections()
      if (activeTab === "schedules" && selectedSchedule) requestExecutions(selectedSchedule)
    } catch (exception) {
      error = "Could not read federated Boomux state"
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function preserveSelections() {
    if (!selectedWorkspace)
      selectedWorkspaceKey = visibleWorkspaces.length > 0 ? visibleWorkspaces[0].key : ""
    if (!selectedSchedule)
      selectedScheduleKey = visibleSchedules.length > 0 ? visibleSchedules[0].key : ""
    workspaceDetail = selectedWorkspace
    syncWorkspaceIndex()
    syncScheduleIndex()
    clampSelection()
  }

  function parseWorkspaces(raw) {
    try {
      var data = parseEnvelope(raw, "workspace.list")
      if (!Array.isArray(data.workspaces)) throw new Error("missing workspaces")
      nodes = [{ node_id: "local", alias: "local", local: true, health: "online",
        current: true, stale: false, observed_capabilities: [],
        scheduler: { state: schedulerState, active_executions: schedulerActiveExecutions,
          max_concurrent: schedulerMaxConcurrent } }]
      workspaces = data.workspaces.map(function(workspace) {
        return Object.assign({}, workspace, { key: resourceKey("local", workspace.id),
          node_id: "local", node_alias: "local", node_current: true, node_stale: false,
          node_health: "online" })
      })
      online = true

      if (pendingWorkspace) {
        for (var i = 0; i < workspaces.length; i++) {
          if (workspaces[i].node_id === pendingWorkspace.nodeId
              && workspaces[i].name === pendingWorkspace.name) {
            selectedWorkspaceKey = workspaces[i].key
            pendingWorkspace = null
            break
          }
        }
      }
      if (!selectedWorkspace || selectedWorkspaceKey === "")
        selectedWorkspaceKey = workspaces.length > 0 ? workspaces[0].key : ""
      syncWorkspaceIndex()
      if (selectedWorkspaceKey !== "") inspectWorkspace(selectedWorkspaceKey)
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
      shells = data.shells.map(function(shell) {
        return Object.assign({}, shell, { key: resourceKey("local", shell.id), node_id: "local",
          node_alias: "local", node_current: true, node_stale: false,
          workspace_key: resourceKey("local", shell.workspace_id) })
      })
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
      var localNode = nodes.length > 0 ? nodes[0]
        : { node_id: "local", alias: "local", local: true, current: true, stale: false }
      applyAgentSnapshot(data.agents.map(function(agent) {
        return normalizeAgent(agent, localNode, agent.workspace_name)
      }))
    } catch (exception) {
      agents = []
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function applyAgentSnapshot(nextAgents) {
      var nextStates = ({})
      var nextCompleted = ({})
      var nextAutomaticAttentionRevisions = ({})

      for (var i = 0; i < nextAgents.length; i++) {
        var agent = nextAgents[i]
        if (agentIsScheduleOwned(agent)) continue
        var state = agent.observation ? agent.observation.state : "unknown"
        var attentionRevision = root.attentionRevision(agent)
        nextStates[agent.key] = state
        if (completedAgents[agent.key] && state === "idle") nextCompleted[agent.key] = true
        if ((!federationAvailable || nodeFor(agent.node_id).local) && agentBaselineReady
            && previousAgentStates[agent.key] === "working" && state === "idle")
          nextCompleted[agent.key] = true
        if (state === "working" && attentionRevision > 0 && attentionReason(agent) === "blocked") {
          nextAutomaticAttentionRevisions[agent.key] = attentionRevision
          if (automaticAttentionRevisions[agent.key] !== attentionRevision
              && nodeIsActionable(agent.node_id, "guarded_remote_management"))
            acknowledgeAgent(agent, false, true)
        }
      }

      previousAgentStates = nextStates
      completedAgents = nextCompleted
      automaticAttentionRevisions = nextAutomaticAttentionRevisions
      agentBaselineReady = true
      agents = nextAgents
      clampSelection()
  }

  function parseSchedules(raw) {
    try {
      var data = parseEnvelope(raw, "schedule.list")
      if (!Array.isArray(data.schedules)) throw new Error("missing schedules")
      var localNode = nodes.length > 0 ? nodes[0]
        : { node_id: "local", alias: "local", local: true, current: true, stale: false }
      schedules = data.schedules.map(function(schedule) {
        return normalizeSchedule(schedule, localNode, schedule.workspace_name)
      })
      if (!selectedSchedule || selectedScheduleKey === "")
        selectedScheduleKey = schedules.length > 0 ? schedules[0].key : ""
      syncScheduleIndex()
      clampSelection()
    } catch (exception) {
      schedules = []
      executions = []
      selectedScheduleKey = ""
      scheduleError = "Could not read Boomux Schedules"
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function parseExecutions(raw) {
    try {
      var data = parseEnvelope(raw, "execution.list")
      if (!Array.isArray(data.executions)) throw new Error("missing executions")
      if (executionActiveScheduleKey !== executionRequestedScheduleKey) return
      var schedule = selectedSchedule
      if (!schedule || schedule.key !== executionActiveScheduleKey) return
      var node = nodeFor(schedule.node_id)
      var replacement = data.executions.map(function(execution) {
        return normalizeExecution(execution, node)
      })
      executions = executions.filter(function(execution) {
        return execution.schedule_key !== executionActiveScheduleKey
      }).concat(replacement)
      executionError = ""
    } catch (exception) {
      executions = []
      executionError = "Could not read the last Schedule run"
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function parseProjects(raw) {
    try {
      var owner = selectedCreationNode()
      if (!owner || owner.node_id !== projectNodeId) return
      var data = parseEnvelope(raw, "project.list")
      if (typeof data.roots_configured !== "boolean" || !Array.isArray(data.projects)
          || !Array.isArray(data.warnings)) throw new Error("missing project discovery fields")
      var nextProjects = []
      for (var i = 0; i < data.projects.length; i++) {
        var project = data.projects[i]
        if (!project || typeof project.name !== "string" || typeof project.path !== "string"
            || project.path.indexOf("/") !== 0 || typeof project.group !== "string"
            || !Number.isFinite(Number(project.group_order)))
          throw new Error("invalid discovered project")
        nextProjects.push(project)
      }
      projects = nextProjects
      projectRootsConfigured = data.roots_configured
      projectError = data.warnings.length > 0 ? data.warnings.join(" · ") : ""
      clampProjectSelection()
      if (formMode === "workspace" && workspaceCreationMode === "project"
          && !projectRootsConfigured) selectWorkspaceCreationMode("custom")
    } catch (exception) {
      projects = []
      projectRootsConfigured = false
      projectError = "Could not discover configured projects"
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function loadProjects() {
    if (!projectListSupported || projectListProcess.running) return
    projects = []
    projectRootsConfigured = false
    selectedProjectIndex = 0
    projectError = ""
    var node = selectedCreationNode()
    if (!node || (!node.local && !nodeIsActionable(node.node_id, "remote_project_discovery"))) {
      projectError = "Project discovery is unavailable for this Node"
      return
    }
    projectNodeId = node.node_id
    projectListProcess.command = ["boomux", "project", "list", "--json"]
    if (!node.local) projectListProcess.command.push("--node", node.node_id)
    projectListProcess.running = true
  }

  function filterProjects() {
    var query = projectQuery.trim().toLowerCase()
    if (query === "") return projects
    return projects.filter(function(project) {
      return String(project.name).toLowerCase().indexOf(query) >= 0
        || String(project.path).toLowerCase().indexOf(query) >= 0
        || String(project.group).toLowerCase().indexOf(query) >= 0
    })
  }

  function clampProjectSelection() {
    if (visibleProjects.length === 0) selectedProjectIndex = 0
    else selectedProjectIndex = Math.max(0, Math.min(selectedProjectIndex, visibleProjects.length - 1))
  }

  function moveProjectSelection(delta) {
    if (visibleProjects.length === 0) return
    selectedProjectIndex = Math.max(0, Math.min(selectedProjectIndex + delta, visibleProjects.length - 1))
    projectList.positionViewAtIndex(selectedProjectIndex, ListView.Contain)
  }

  function requestShellNameSuggestion() {
    if (!shellNameSuggestionSupported || !workspaceDetail
        || (formMode !== "shell" && formMode !== "agent")) return
    if (!nodeIsActionable(workspaceDetail.node_id, workspaceDetail.node_id === "local"
        ? "" : "typed_node_host_services")) return
    suggestedNameRequestedWorkspaceKey = workspaceDetail.key
    if (!shellNameSuggestionProcess.running) startShellNameSuggestion()
  }

  function startShellNameSuggestion() {
    if (suggestedNameRequestedWorkspaceKey === "") return
    suggestedNameActiveWorkspaceKey = suggestedNameRequestedWorkspaceKey
    var workspace = null
    for (var i = 0; i < workspaces.length; i++)
      if (workspaces[i].key === suggestedNameActiveWorkspaceKey) workspace = workspaces[i]
    if (!workspace) return
    shellNameSuggestionProcess.command = ["boomux", "shell", "suggest-name",
      workspace.id, "--json"]
    if (!nodeFor(workspace.node_id).local)
      shellNameSuggestionProcess.command.push("--node", workspace.node_id)
    shellNameSuggestionProcess.running = true
  }

  function parseShellNameSuggestion(raw) {
    try {
      var data = parseEnvelope(raw, "shell.suggest-name")
      var responseWorkspaceId = resourceId(data.workspace_id)
      var responseNodeId = resourceNode(data.workspace_id,
        workspaceDetail ? workspaceDetail.node_id : "")
      if (resourceKey(responseNodeId, responseWorkspaceId) !== suggestedNameActiveWorkspaceKey
          || typeof data.name !== "string" || data.name.trim() === "")
        throw new Error("invalid shell name suggestion")
      if ((formMode === "shell" || formMode === "agent") && workspaceDetail
          && workspaceDetail.key === suggestedNameActiveWorkspaceKey && !nameFieldEdited
          && nameField.text === "") nameField.text = data.name
    } catch (exception) {
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function inspectWorkspace(workspaceKey) {
    inspectRequestedKey = String(workspaceKey || "")
    if (inspectRequestedKey === "") return
    var workspace = null
    for (var i = 0; i < workspaces.length; i++) if (workspaces[i].key === inspectRequestedKey) workspace = workspaces[i]
    if (!workspace) return
    if (federationAvailable) {
      workspaceDetail = workspace
      openPendingShellIfPresent()
      return
    }
    if (workspaceInspectProcess.running) return
    inspectActiveKey = inspectRequestedKey
    workspaceInspectProcess.command = ["boomux", "workspace", "inspect", workspace.id, "--json"]
    workspaceInspectProcess.running = true
  }

  function parseWorkspaceDetail(raw) {
    try {
      var data = parseEnvelope(raw, "workspace.inspect")
      if (!data.workspace || resourceKey("local", data.workspace.id) !== selectedWorkspaceKey) return
      workspaceDetail = Object.assign({}, data.workspace, { key: selectedWorkspaceKey,
        node_id: "local", node_alias: "local", node_current: true, node_stale: false })
      openPendingShellIfPresent()
    } catch (exception) {
      workspaceDetail = null
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function openPendingShellIfPresent() {
    if (!pendingShell || !workspaceDetail || pendingShell.workspaceKey !== workspaceDetail.key) return
    for (var i = 0; i < workspaceDetail.shells.length; i++) {
      if (String(workspaceDetail.shells[i].name) === pendingShell.name) {
        var shell = Object.assign({}, workspaceDetail.shells[i], { node_id: workspaceDetail.node_id,
          node_alias: workspaceDetail.node_alias })
        pendingShell = null
        openShell(shell)
        return
      }
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
    else if (tab === "schedules") {
      syncScheduleIndex()
      refresh()
    } else selectedIndex = 0
    cancelForm()
  }

  function cycleTab(direction) {
    var tabs = ["agents", "workspaces", "schedules"]
    var index = tabs.indexOf(activeTab)
    var step = direction < 0 ? -1 : 1
    selectTab(tabs[(index + step + tabs.length) % tabs.length])
  }

  function clampSelection() {
    selectedIndex = Math.max(0, Math.min(selectedIndex, itemCount - 1))
  }

  function moveSelection(offset) {
    if (editing || itemCount === 0) return
    selectedIndex = Math.max(0, Math.min(selectedIndex + offset, itemCount - 1))
    if (activeTab === "agents") agentList.positionViewAtIndex(selectedIndex, ListView.Contain)
    else if (activeTab === "workspaces") workspaceList.positionViewAtIndex(selectedIndex, ListView.Contain)
    else scheduleList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function activateSelected() {
    if (activeTab === "agents") openAgent(selectedItem)
    else if (activeTab === "workspaces" && selectedItem) selectWorkspace(selectedItem.key)
    else if (selectedItem) selectSchedule(selectedItem.key)
  }

  function selectWorkspace(workspaceKey) {
    selectedWorkspaceKey = String(workspaceKey)
    syncWorkspaceIndex()
    workspaceDetail = null
    inspectWorkspace(selectedWorkspaceKey)
  }

  function syncWorkspaceIndex() {
    if (activeTab !== "workspaces") return
    for (var i = 0; i < visibleWorkspaces.length; i++) {
      if (visibleWorkspaces[i].key === selectedWorkspaceKey) {
        selectedIndex = i
        return
      }
    }
    clampSelection()
  }

  function selectSchedule(scheduleKey) {
    selectedScheduleKey = String(scheduleKey)
    executionError = ""
    syncScheduleIndex()
    if (selectedSchedule) requestExecutions(selectedSchedule)
  }

  function syncScheduleIndex() {
    if (activeTab !== "schedules") return
    for (var i = 0; i < visibleSchedules.length; i++) {
      if (visibleSchedules[i].key === selectedScheduleKey) {
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
      var rawAgent = workspaceDetail.agents[i]
      var agent = rawAgent.key ? rawAgent : normalizeAgent(rawAgent, nodeFor(workspaceDetail.node_id), workspaceDetail.name)
      var state = agent.observation ? agent.observation.state : "unknown"
      if (agent.shell_id === resourceId(shell.id) && agent.run_id === resourceId(shell.run ? shell.run.id : shell.run_id)
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
      var owner = shellOwner(shell.owner)
      if (owner === "schedule") continue
      var shellId = resourceId(shell.id)
      var normalizedShell = Object.assign({}, shell, { id: shellId,
        key: resourceKey(workspaceDetail.node_id, shellId), node_id: workspaceDetail.node_id,
        node_alias: workspaceDetail.node_alias, node_current: workspaceDetail.node_current,
        node_stale: workspaceDetail.node_stale, workspace_id: workspaceDetail.id,
        workspace_key: workspaceDetail.key, owner: owner, status: shellStatus(shell.status),
        run: shell.run || (shell.run_id ? { id: resourceId(shell.run_id) } : null) })
      var agent = currentAgentForShell(normalizedShell)
      items.push({
        kind: agent ? "agent" : (shell.command && shell.command.length > 0 ? "command" : "shell"),
        id: shellId,
        key: normalizedShell.key,
        node_id: workspaceDetail.node_id,
        node_alias: workspaceDetail.node_alias,
        name: shell.name,
        status: agent && agent.observation ? agent.observation.state : normalizedShell.status,
        detail: agent ? String(agent.integration || "agent")
          : (shell.command && shell.command.length > 0 ? shell.command.join(" ") : String(shell.cwd || "")),
        shell: normalizedShell,
        agent: agent
      })
    }
    var launchers = workspaceDetail.launchers || []
    for (var j = 0; j < launchers.length; j++) {
      var launcher = launchers[j]
      var launcherId = resourceId(launcher.id)
      items.push({
        kind: "launcher",
        id: launcherId,
        key: resourceKey(workspaceDetail.node_id, launcherId),
        node_id: workspaceDetail.node_id,
        node_alias: workspaceDetail.node_alias,
        name: launcher.name,
        status: "on workspace open",
        detail: launcher.command ? launcher.command.join(" ") : "",
        launcher: launcher
      })
    }
    return items
  }

  function openWorkspace(workspace) {
    if (!workspace || actionProcess.running
        || !nodeIsActionable(workspace.node_id, "guarded_remote_management")) return
    pendingAction = { kind: "open-workspace", key: workspace.key, nodeId: workspace.node_id }
    actionMessage = "Opening " + String(workspace.name) + "..."
    actionProcess.command = ["boomux", "workspace", "open", String(workspace.id)]
    var args = nodeArgs(workspace.node_id, "guarded_remote_management")
    if (args === null) return
    actionProcess.command = actionProcess.command.concat(args)
    actionProcess.running = true
  }

  function openShell(shell, agent) {
    if (!shell || !shell.id || openProcess.running
        || !nodeIsActionable(shell.node_id, "remote_pty_attachment")) return
    pendingOpenAgent = agent || null
    pendingOpenKey = resourceKey(shell.node_id, shell.id)
    actionMessage = "Opening terminal..."
    openProcess.command = ["boomux", "open", String(shell.id), "--takeover"]
    var args = nodeArgs(shell.node_id, "remote_pty_attachment")
    if (args === null) return
    openProcess.command = openProcess.command.concat(args)
    openProcess.running = true
  }

  function openAgent(agent) {
    if (!agent) return
    if (!agentShellRetained(agent)) {
      if (attentionRevision(agent) > 0 && agentCanAcknowledge(agent)) {
        actionMessage = "Acknowledging attention for removed shell..."
        acknowledgeAgent(agent)
      } else if (attentionRevision(agent) > 0) {
        actionMessage = "Remote attention remains visible; this CLI cannot acknowledge it"
      } else {
        actionMessage = "This Agent's shell was removed"
      }
      return
    }
    openShell({ id: agent.shell_id, node_id: agent.node_id, node_alias: agent.node_alias }, agent)
  }

  function agentShellRetained(agent) {
    if (!agent || !agent.shell_id) return false
    for (var i = 0; i < shells.length; i++)
      if (shells[i].node_id === agent.node_id && shells[i].id === agent.shell_id) return true
    return false
  }

  function agentIsCurrent(agent) {
    if (!agent || !agent.shell_id || !agent.run_id) return false
    for (var i = 0; i < shells.length; i++) {
      var shell = shells[i]
      if (shell.node_id === agent.node_id && shell.id === agent.shell_id
          && shell.run && resourceId(shell.run.id) === agent.run_id)
        return true
    }
    return false
  }

  function agentIsScheduleOwned(agent) {
    if (!agent || !agent.shell_id) return false
    for (var i = 0; i < shells.length; i++)
      if (shells[i].node_id === agent.node_id && shells[i].id === agent.shell_id)
        return shells[i].owner === "schedule"
    return false
  }

  function agentIsProjectedCurrent(agent) {
    if (!agentIsCurrent(agent)) return false
    var observedAt = agent.observation ? Number(agent.observation.observed_at_ms || 0) : 0
    var startedAt = Number(agent.started_at_ms || 0)
    for (var i = 0; i < agents.length; i++) {
      var candidate = agents[i]
      var state = candidate.observation ? candidate.observation.state : "unknown"
      if (candidate.key === agent.key || candidate.node_id !== agent.node_id
          || candidate.shell_id !== agent.shell_id
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
      pendingAction = { kind: "invoke-launcher", key: item.key, nodeId: item.node_id }
      actionMessage = "Launching " + String(item.name) + "..."
      actionProcess.command = ["boomux", "launcher", "invoke", String(item.id)]
      var args = nodeArgs(item.node_id, "remote_launcher_invocation")
      if (args === null) return
      actionProcess.command = actionProcess.command.concat(args)
      actionProcess.running = true
      return
    }
    openShell(item.shell, item.agent)
  }

  function requestRemoveItem(item) {
    var node = item ? nodeFor(item.node_id) : null
    if (!item || !node || !node.local
        || actionProcess.running || openProcess.running || executionOpenProcess.running) return
    removeItemDialog.selectedIndex = 0
    itemToRemove = item
  }

  function cancelRemoveItem() {
    itemToRemove = null
  }

  function removeItemMessage(item) {
    if (!item) return ""
    if (item.kind === "launcher")
      return "Remove launcher " + String(item.name)
        + "? This deletes its workspace definition. Applications it already launched keep running."
    return "Remove " + String(item.kind) + " " + String(item.name)
      + "? This terminates it if running and deletes its shell definition and retained terminal state. Durable Agent history may remain."
  }

  function confirmRemoveItem() {
    var item = itemToRemove
    itemToRemove = null
    if (!item || !workspaceDetail || actionProcess.running) return
    pendingAction = { kind: item.kind === "launcher" ? "remove-launcher" : "remove-shell",
      key: item.key, nodeId: item.node_id }
    actionMessage = "Removing " + String(item.name) + "..."
    actionProcess.command = item.kind === "launcher"
      ? ["boomux", "launcher", "remove", String(item.id), "--workspace", String(workspaceDetail.id)]
      : ["boomux", "shell", "close", String(item.shell.id), "--workspace", String(workspaceDetail.id)]
    actionProcess.running = true
  }

  function openDashboard() {
    if (!bar) return
    bar.run("omarchy-launch-tui --app-id=org.omarchy.boomux boomux")
    close()
  }

  function addNode() {
    if (!bar || !federationAvailable) return
    bar.run("omarchy-launch-tui --app-id=org.omarchy.boomux-node-add boomux node add")
    close()
  }

  function openExecution(execution) {
    if (!execution || executionOpenProcess.running || actionProcess.running
        || !nodeIsActionable(execution.node_id, "remote_scheduled_execution_observation")) return
    actionMessage = "Opening last Schedule run..."
    pendingExecutionOpenKey = execution.key
    executionOpenProcess.command = ["boomux", "execution", "open", String(execution.id), "--json"]
    var args = nodeArgs(execution.node_id, "remote_scheduled_execution_observation")
    if (args === null) return
    executionOpenProcess.command = executionOpenProcess.command.concat(args)
    executionOpenProcess.running = true
  }

  function executionCanOpen(execution) {
    if (!execution || !nodeIsActionable(execution.node_id,
        "remote_scheduled_execution_observation")) return false
    return !!execution.agent_id
      || ((execution.state === "starting" || execution.state === "active")
        && daemonProtocolVersion >= 26 && !!execution.shell_id && !!execution.run_id)
  }

  function runSchedule(schedule) {
    if (!schedule || actionProcess.running || executionOpenProcess.running
        || !nodeIsActionable(schedule.node_id, "remote_agent_schedule_management")) return
    pendingAction = { kind: "run-schedule", key: schedule.key, nodeId: schedule.node_id }
    actionMessage = "Starting " + String(schedule.name) + "..."
    actionProcess.command = ["boomux", "schedule", "run", String(schedule.id), "--json"]
    var args = nodeArgs(schedule.node_id, "remote_agent_schedule_management")
    if (args === null) return
    actionProcess.command = actionProcess.command.concat(args)
    actionProcess.running = true
  }

  function setSchedulePaused(schedule, paused) {
    if (!schedule || actionProcess.running || executionOpenProcess.running
        || !nodeIsActionable(schedule.node_id, "remote_agent_schedule_management")) return
    pendingAction = { kind: paused ? "pause-schedule" : "resume-schedule",
      key: schedule.key, nodeId: schedule.node_id }
    actionMessage = (paused ? "Pausing " : "Resuming ") + String(schedule.name) + "..."
    actionProcess.command = ["boomux", "schedule", paused ? "pause" : "resume",
      String(schedule.id), "--json"]
    var args = nodeArgs(schedule.node_id, "remote_agent_schedule_management")
    if (args === null) return
    actionProcess.command = actionProcess.command.concat(args)
    actionProcess.running = true
  }

  function formatTimestamp(timestamp) {
    var value = Number(timestamp || 0)
    return value > 0 ? Qt.formatDateTime(new Date(value), "MMM d, HH:mm") : "unknown"
  }

  function scheduleTiming(schedule) {
    if (!schedule) return ""
    if (schedule.state === "paused") return "no future dispatch"
    if (schedule.next_occurrence && schedule.next_occurrence.scheduled_at_ms)
      return "next " + formatTimestamp(schedule.next_occurrence.scheduled_at_ms)
    var node = nodeFor(schedule.node_id)
    var state = node && node.scheduler ? String(node.scheduler.state || "offline") : "offline"
    return state === "active" ? "next occurrence unavailable" : "scheduler " + state
  }

  function executionDetail(execution) {
    if (!execution) return ""
    if (execution.reason) return String(execution.reason).split("_").join(" ")
    if (execution.outcome) {
      if (execution.outcome.kind === "exit_code") return "exit " + String(execution.outcome.code)
      if (execution.outcome.kind === "signal") return "signal " + String(execution.outcome.signal)
    }
    return execution.dispatch_kind ? String(execution.dispatch_kind) : ""
  }

  function workspaceItemCount(workspace) {
    var count = 0
    for (var i = 0; i < shells.length; i++)
      if (shells[i].node_id === workspace.node_id && shells[i].workspace_id === workspace.id
          && shells[i].owner !== "schedule") count++
    return count + Number(workspace.launcher_count || 0)
  }

  function workspaceActiveAgentCount(workspace) {
    return visibleAgents.filter(function(agent) {
      return agent.node_id === workspace.node_id && agent.workspace_id === workspace.id
    }).length
  }

  function agentDisplayName(agent) {
    if (!agent) return "Agent"
    for (var i = 0; i < shells.length; i++)
      if (shells[i].node_id === agent.node_id && shells[i].id === agent.shell_id) return shells[i].name
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

  function agentCanAcknowledge(agent) {
    var node = agent ? nodeFor(agent.node_id) : null
    return !!node && node.local && nodeIsActionable(agent.node_id, "")
  }

  function acknowledgeAgent(agent, dismissed, automatic) {
    var revision = attentionRevision(agent)
    if (revision <= 0 || !agentCanAcknowledge(agent)) return
    var queue = acknowledgeQueue.slice()
    for (var i = 0; i < queue.length; i++) {
      if (queue[i].agentKey !== agent.key || queue[i].revision !== revision) continue
      if (dismissed) {
        queue[i].dismissed = true
        queue[i].automatic = false
        acknowledgeQueue = queue
      }
      return
    }
    queue.push({
      agentKey: agent.key,
      nodeId: agent.node_id,
      agentId: String(agent.id),
      revision: revision,
      dismissed: !!dismissed,
      automatic: !!automatic
    })
    acknowledgeQueue = queue
    startNextAcknowledgement()
  }

  function dismissAgent(agent) {
    if (!agent || (!completedAgents[agent.key] && attentionRevision(agent) <= 0)
        || !agentCanAcknowledge(agent)) return
    clearCompletedAgent(agent.key)
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
      if (completedAgents[agents[i].key] && agentIsProjectedCurrent(agents[i]))
        completed[agents[i].key] = true
      if (attentionReason(agents[i]) === "completed" && attentionRevision(agents[i]) > 0)
        completed[agents[i].key] = true
    }
    return Object.keys(completed).length
  }

  function clearCompletedAgent(agentKey) {
    if (!completedAgents[agentKey]) return
    var nextCompleted = ({})
    for (var id in completedAgents)
      if (id !== agentKey) nextCompleted[id] = completedAgents[id]
    completedAgents = nextCompleted
  }

  function showForm(mode) {
    var owner = mode === "workspace" ? selectedCreationNode()
      : (workspaceDetail ? nodeFor(workspaceDetail.node_id) : null)
    if (!owner || !owner.local) {
      actionMessage = "Creation is unavailable here; select the local Node"
      return
    }
    formMode = mode
    actionMessage = ""
    nameFieldEdited = false
    nameField.text = ""
    cwdIsExact = !!(mode !== "workspace" && workspaceDetail && workspaceDetail.default_cwd)
    cwdField.text = mode !== "workspace" && workspaceDetail && workspaceDetail.default_cwd
      ? String(workspaceDetail.default_cwd) : ""
    if (mode === "workspace") {
      projectSearchField.text = ""
      projectQuery = ""
      selectedProjectIndex = 0
      workspaceCreationMode = projectListSupported ? "project" : "custom"
      if (projectListSupported) loadProjects()
    } else requestShellNameSuggestion()
    Qt.callLater(function() {
      if (mode === "workspace" && workspaceCreationMode === "project") projectSearchField.forceActiveFocus()
      else nameField.forceActiveFocus()
    })
  }

  function cancelForm() {
    directoryPickerOpen = false
    suggestedNameRequestedWorkspaceKey = ""
    formMode = ""
    if (opened) Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function selectWorkspaceCreationMode(mode) {
    workspaceCreationMode = mode
    actionMessage = ""
    Qt.callLater(function() {
      if (mode === "project") projectSearchField.forceActiveFocus()
      else nameField.forceActiveFocus()
    })
  }

  function openDirectoryPicker() {
    var cwd = cwdIsExact ? cwdField.text : cwdField.text.trim()
    directoryPickerPath = cwd.indexOf("/") === 0 ? cwd : home
    directoryPickerIndex = 0
    directoryPickerOpen = true
    Qt.callLater(function() { directoryPickerKeyHandler.forceActiveFocus() })
  }

  function closeDirectoryPicker() {
    directoryPickerOpen = false
    Qt.callLater(function() { browseButton.forceActiveFocus() })
  }

  function parentDirectory(path) {
    var value = String(path || "/").replace(/\/+$/, "")
    if (value === "") return "/"
    var separator = value.lastIndexOf("/")
    return separator <= 0 ? "/" : value.substring(0, separator)
  }

  function enterDirectory(path) {
    if (String(path || "").indexOf("/") !== 0) return
    directoryPickerPath = String(path)
    directoryPickerIndex = 0
  }

  function moveDirectorySelection(delta) {
    if (directoryModel.count === 0) return
    directoryPickerIndex = Math.max(0,
      Math.min(directoryPickerIndex + delta, directoryModel.count - 1))
    directoryList.positionViewAtIndex(directoryPickerIndex, ListView.Contain)
  }

  function enterSelectedDirectory() {
    if (directoryModel.count === 0) return
    enterDirectory(directoryModel.get(directoryPickerIndex, "filePath"))
  }

  function chooseDirectory() {
    var path = directoryPickerPath
    cwdField.text = path
    cwdIsExact = true
    if (formMode === "workspace" && workspaceCreationMode === "custom"
        && nameField.text.trim() === "") {
      var parts = path.replace(/\/+$/, "").split("/")
      nameField.text = parts.length > 0 ? parts[parts.length - 1] : ""
    }
    directoryPickerOpen = false
    Qt.callLater(function() { cwdField.forceActiveFocus() })
  }

  function submitForm() {
    if (actionProcess.running) return
    var name = nameField.text.trim()
    var cwd = cwdIsExact ? cwdField.text : cwdField.text.trim()
    if (formMode === "workspace" && workspaceCreationMode === "project") {
      if (!selectedProject) {
        actionMessage = "Select a discovered project"
        return
      }
      name = String(selectedProject.name)
      cwd = String(selectedProject.path)
    }
    if (name === "") {
      actionMessage = "A name is required"
      return
    }

    var command
    if (formMode === "workspace") {
      pendingAction = { kind: "create-workspace", key: resourceKey("local", "new:" + name),
        nodeId: "local" }
      pendingWorkspace = { nodeId: "local", name: name }
      command = ["boomux", "workspace", "create", name]
      if (cwd !== "") command.push("--cwd", cwd)
    } else if (formMode === "shell" && workspaceDetail) {
      pendingAction = { kind: "create-shell", key: workspaceDetail.key + "\u001fnew:" + name,
        nodeId: workspaceDetail.node_id }
      command = ["boomux", "shell", "create", String(workspaceDetail.id), "--name", name]
      if (cwd !== "") command.push("--cwd", cwd)
    } else if (formMode === "agent" && workspaceDetail) {
      pendingAction = { kind: "create-agent", key: workspaceDetail.key + "\u001fnew:" + name,
        nodeId: workspaceDetail.node_id }
      pendingShell = { workspaceKey: workspaceDetail.key, nodeId: workspaceDetail.node_id, name: name }
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

  function requestExecutions(schedule) {
    if (!schedule || executionListProcess.running) {
      if (schedule) executionRequestedScheduleKey = schedule.key
      return
    }
    if (!nodeIsActionable(schedule.node_id, "remote_scheduled_execution_observation")) return
    executionRequestedScheduleKey = schedule.key
    executionActiveScheduleKey = schedule.key
    executionListProcess.command = ["boomux", "execution", "list", "--schedule",
      schedule.id, "--limit", "1", "--json"]
    var args = nodeArgs(schedule.node_id, "remote_scheduled_execution_observation")
    if (args === null) return
    executionListProcess.command = executionListProcess.command.concat(args)
    executionListProcess.running = true
  }

  onOpenedChanged: if (opened) {
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  } else {
    itemToRemove = null
    cancelForm()
  }

  Process {
    id: capabilityProcess
    command: ["boomux", "capabilities", "--json"]
    stdout: StdioCollector { id: capabilityStdout; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.parseCapabilities(capabilityStdout.text)
      else {
        root.capabilitiesReady = true
        root.scheduleCommandsSupported = false
        root.projectListSupported = false
        root.federationSupported = false
      }
      if (root.opened && root.activeTab === "schedules") root.refresh()
    }
  }

  Process {
    id: projectListProcess
    command: ["boomux", "project", "list", "--json"]
    stdout: StdioCollector { id: projectListStdout; waitForEnd: true }
    stderr: StdioCollector { id: projectListStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.parseProjects(projectListStdout.text)
      else {
        root.projects = []
        root.projectError = root.processError(projectListStderr.text || projectListStdout.text,
          "Could not discover configured projects")
      }
    }
  }

  Process {
    id: shellNameSuggestionProcess
    stdout: StdioCollector { id: shellNameSuggestionStdout; waitForEnd: true }
    stderr: StdioCollector { id: shellNameSuggestionStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.parseShellNameSuggestion(shellNameSuggestionStdout.text)
      else console.warn("io.github.gardnmi.boomux:", root.processError(
        shellNameSuggestionStderr.text || shellNameSuggestionStdout.text,
        "Could not suggest a shell name"))
      if (root.suggestedNameRequestedWorkspaceKey !== ""
          && root.suggestedNameRequestedWorkspaceKey !== root.suggestedNameActiveWorkspaceKey)
        root.startShellNameSuggestion()
    }
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
    id: nodeSnapshotProcess
    command: ["boomux", "node", "snapshot", "--json"]
    stdout: StdioCollector { id: nodeSnapshotStdout; waitForEnd: true }
    stderr: StdioCollector { id: nodeSnapshotStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root.finishRefresh()
      if (exitCode === 0) root.parseNodeSnapshot(nodeSnapshotStdout.text)
      else {
        root.error = root.processError(nodeSnapshotStderr.text || nodeSnapshotStdout.text,
          "Could not read federated Boomux state")
      }
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
    onExited: function(exitCode) {
      root.finishRefresh()
      if (exitCode === 0 && !agentProcess.running) agentProcess.running = true
      else if (exitCode !== 0) {
        root.agents = []
        root.finishRefresh()
      }
    }
  }

  Process {
    id: agentProcess
    command: ["boomux", "agent", "list", "--json"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseAgents(text) }
    onExited: function(exitCode) { root.finishRefresh() }
  }


  Process {
    id: scheduleListProcess
    command: ["boomux", "schedule", "list", "--json"]
    stdout: StdioCollector { id: scheduleListStdout; waitForEnd: true }
    stderr: StdioCollector { id: scheduleListStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root.finishRefresh()
      if (exitCode === 0) {
        root.parseSchedules(scheduleListStdout.text)
        if (root.selectedSchedule) {
          root.requestExecutions(root.selectedSchedule)
        } else {
          root.executions = []
          root.finishRefresh()
        }
      } else {
        root.schedules = []
        root.executions = []
        root.selectedScheduleKey = ""
        root.scheduleError = root.processError(scheduleListStderr.text || scheduleListStdout.text,
          "Could not read Boomux Schedules")
        root.finishRefresh()
      }
    }
  }

  Process {
    id: executionListProcess
    stdout: StdioCollector { id: executionListStdout; waitForEnd: true }
    stderr: StdioCollector { id: executionListStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root.finishRefresh()
      if (exitCode === 0) root.parseExecutions(executionListStdout.text)
      else {
        root.executionError = root.processError(executionListStderr.text || executionListStdout.text,
          "Could not read the last Schedule run")
      }
      if (root.executionRequestedScheduleKey !== ""
          && root.executionRequestedScheduleKey !== root.executionActiveScheduleKey) {
        for (var i = 0; i < root.schedules.length; i++) {
          if (root.schedules[i].key === root.executionRequestedScheduleKey) {
            root.requestExecutions(root.schedules[i])
            break
          }
        }
      }
    }
  }

  Process {
    id: workspaceInspectProcess
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseWorkspaceDetail(text) }
    onExited: function(exitCode) {
      if (root.inspectRequestedKey !== "" && root.inspectRequestedKey !== root.inspectActiveKey)
        root.inspectWorkspace(root.inspectRequestedKey)
    }
  }

  Process {
    id: actionProcess
    stdout: StdioCollector { id: actionStdout; waitForEnd: true }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var action = root.pendingAction ? root.pendingAction.kind : ""
      root.pendingAction = null
      if (exitCode !== 0) {
        root.pendingShell = null
        root.pendingWorkspace = null
        root.actionMessage = root.processError(actionStderr.text || actionStdout.text, "Boomux action failed")
        return
      }
      root.cancelForm()
      if (action === "create-workspace") root.actionMessage = "Workspace created"
      else if (action === "create-shell") root.actionMessage = "Shell added"
      else if (action === "create-agent") root.actionMessage = "Starting " + root.agentHost + "..."
      else if (action === "invoke-launcher") root.actionMessage = "Launcher started"
      else if (action === "remove-launcher") root.actionMessage = "Launcher removed"
      else if (action === "remove-shell") root.actionMessage = "Workspace item removed"
      else if (action === "run-schedule") root.actionMessage = "Schedule execution started"
      else if (action === "pause-schedule") root.actionMessage = "Schedule paused"
      else if (action === "resume-schedule") root.actionMessage = "Schedule resumed"
      else root.actionMessage = "Workspace opened"
      root.refresh()
    }
  }

  Process {
    id: openProcess
    onExited: function(exitCode) {
      var agent = root.pendingOpenAgent
      root.pendingOpenAgent = null
      root.pendingOpenKey = ""
      if (exitCode !== 0) {
        root.actionMessage = "Could not open terminal"
        return
      }
      if (agent) {
        root.clearCompletedAgent(agent.key)
        root.acknowledgeAgent(agent)
      }
      root.actionMessage = ""
      root.close()
    }
  }

  Process {
    id: executionOpenProcess
    stdout: StdioCollector { id: executionOpenStdout; waitForEnd: true }
    stderr: StdioCollector { id: executionOpenStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root.pendingExecutionOpenKey = ""
      if (exitCode !== 0) {
        root.actionMessage = root.processError(executionOpenStderr.text || executionOpenStdout.text,
          "Could not open the last Schedule run")
        return
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

  FolderListModel {
    id: directoryModel
    folder: root.directoryPickerOpen ? Util.fileUrl(root.directoryPickerPath || root.home) : ""
    showDirs: true
    showFiles: false
    showDotAndDotDot: false
    showHidden: false
    showOnlyReadable: true
    sortField: FolderListModel.Name
    sortReversed: false
    caseSensitive: false
    onCountChanged: root.directoryPickerIndex = Math.max(0,
      Math.min(root.directoryPickerIndex, count - 1))
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
        if (root.itemToRemove && (dx !== 0 || dy !== 0))
          removeItemDialog.selectedIndex = removeItemDialog.selectedIndex === 0 ? 1 : 0
        else if (dy !== 0) root.moveSelection(dy)
      }
      onActivateRequested: {
        if (root.itemToRemove) {
          if (removeItemDialog.selectedIndex === 0) root.cancelRemoveItem()
          else root.confirmRemoveItem()
        } else root.activateSelected()
      }
      onCloseRequested: {
        if (root.itemToRemove) root.cancelRemoveItem()
        else root.close()
      }
      onTabRequested: function(direction) {
        if (root.itemToRemove)
          removeItemDialog.selectedIndex = removeItemDialog.selectedIndex === 0 ? 1 : 0
        else root.cycleTab(direction)
      }
      onTextKey: function(text) {
        if (root.itemToRemove) return
        if (text === "r" || text === "R") root.refresh()
        else if (text === "1") root.selectTab("agents")
        else if (text === "2") root.selectTab("workspaces")
        else if (text === "3") root.selectTab("schedules")
        else if ((text === "a" || text === "A") && root.federationAvailable) root.addNode()
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
            Row {
              spacing: Style.space(4)
              Button {
                visible: root.federationAvailable
                text: "Add Node"
                iconText: "+"
                tooltipText: "Open guided Node setup"
                bordered: true
                foreground: root.foreground
                fontSize: Style.font.caption
                horizontalPadding: Style.space(5)
                verticalPadding: Style.space(2)
                onClicked: root.addNode()
              }
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
        }

        Row {
          width: parent.width
          spacing: Style.space(6)
          Button {
            width: (parent.width - parent.spacing * 2) / 3
            text: "Agents"
            iconText: ""
            selected: root.activeTab === "agents"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.selectTab("agents")
          }
          Button {
            width: (parent.width - parent.spacing * 2) / 3
            text: "Workspaces"
            iconText: ""
            selected: root.activeTab === "workspaces"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.selectTab("workspaces")
          }
          Button {
            width: (parent.width - parent.spacing * 2) / 3
            text: "Schedules"
            iconText: ""
            selected: root.activeTab === "schedules"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.selectTab("schedules")
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
              text: root.directoryPickerOpen ? "CHOOSE DIRECTORY"
                : (root.formMode === "workspace" ? "NEW WORKSPACE"
                  : (root.formMode === "shell" ? "ADD SHELL" : "START AGENT"))
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              visible: root.directoryPickerOpen
              width: parent.width
              spacing: Style.space(6)

              Item {
                id: directoryPickerKeyHandler
                width: 1
                height: 1
                focus: root.directoryPickerOpen
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    root.moveDirectorySelection(1)
                  } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    root.moveDirectorySelection(-1)
                  } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                      || event.key === Qt.Key_Right) {
                    root.enterSelectedDirectory()
                  } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backspace) {
                    root.enterDirectory(root.parentDirectory(root.directoryPickerPath))
                  } else if (event.key === Qt.Key_Space) {
                    root.chooseDirectory()
                  } else if (event.key === Qt.Key_Escape) {
                    root.closeDirectoryPicker()
                  } else if (event.key === Qt.Key_Tab) {
                    directoryChooseButton.forceActiveFocus()
                  } else if (event.key === Qt.Key_Backtab) {
                    directoryCancelButton.forceActiveFocus()
                  } else {
                    return
                  }
                  event.accepted = true
                }
              }

              Text {
                width: parent.width
                text: root.compactPath(root.directoryPickerPath)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideMiddle
              }

              Text {
                width: parent.width
                text: "Enter opens · Left goes up · Space chooses this directory"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }

              Item {
                width: parent.width
                height: Style.space(190)

                Text {
                  visible: directoryModel.count === 0
                  anchors.centerIn: parent
                  text: "No readable subdirectories"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }

                ListView {
                  id: directoryList
                  anchors.fill: parent
                  model: directoryModel
                  spacing: Style.space(3)
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds
                  ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                  delegate: Rectangle {
                    required property string fileName
                    required property string filePath
                    required property int index
                    width: ListView.view.width
                    height: Style.space(40)
                    radius: Style.cornerRadius
                    color: index === root.directoryPickerIndex
                      ? Style.selectedFillFor(root.foreground, Color.accent)
                      : (directoryMouse.containsMouse
                        ? Util.alpha(root.foreground, 0.06) : "transparent")
                    Text {
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.margins: Style.space(9)
                      anchors.verticalCenter: parent.verticalCenter
                      text: "▸  " + fileName
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      elide: Text.ElideRight
                    }
                    MouseArea {
                      id: directoryMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      onEntered: root.directoryPickerIndex = index
                      onClicked: root.directoryPickerIndex = index
                      onDoubleClicked: root.enterDirectory(filePath)
                    }
                  }
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(6)
                Button {
                  width: (parent.width - parent.spacing * 2) / 3
                  text: "Up"
                  focusable: true
                  bordered: true
                  foreground: root.foreground
                  onClicked: root.enterDirectory(root.parentDirectory(root.directoryPickerPath))
                }
                Button {
                  id: directoryCancelButton
                  width: (parent.width - parent.spacing * 2) / 3
                  text: "Cancel"
                  focusable: true
                  bordered: true
                  foreground: root.foreground
                  onClicked: root.closeDirectoryPicker()
                }
                Button {
                  id: directoryChooseButton
                  width: (parent.width - parent.spacing * 2) / 3
                  text: "Choose Here"
                  focusable: true
                  bordered: true
                  active: true
                  foreground: root.foreground
                  onClicked: root.chooseDirectory()
                }
              }
            }

            Row {
              visible: !root.directoryPickerOpen && root.formMode === "workspace"
                && root.projectListSupported
              width: parent.width
              spacing: Style.space(6)
              Button {
                width: (parent.width - parent.spacing) / 2
                text: "Projects"
                selected: root.workspaceCreationMode === "project"
                focusable: true
                bordered: true
                foreground: root.foreground
                onClicked: root.selectWorkspaceCreationMode("project")
              }
              Button {
                id: customModeButton
                width: (parent.width - parent.spacing) / 2
                text: "Custom"
                selected: root.workspaceCreationMode === "custom"
                focusable: true
                bordered: true
                foreground: root.foreground
                onClicked: root.selectWorkspaceCreationMode("custom")
              }
            }

            Column {
              visible: !root.directoryPickerOpen && root.formMode === "workspace"
                && root.workspaceCreationMode === "project"
              width: parent.width
              spacing: Style.space(6)

              TextField {
                id: projectSearchField
                width: parent.width
                placeholderText: "Search configured projects"
                foreground: root.foreground
                onTextChanged: root.projectQuery = text
                onAccepted: root.submitForm()
                Keys.onDownPressed: function(event) {
                  root.moveProjectSelection(1)
                  event.accepted = true
                }
                Keys.onUpPressed: function(event) {
                  root.moveProjectSelection(-1)
                  event.accepted = true
                }
                Keys.onTabPressed: function(event) {
                  customModeButton.forceActiveFocus()
                  event.accepted = true
                }
                Keys.onEscapePressed: root.cancelForm()
              }

              Text {
                visible: root.visibleProjects.length === 0
                width: parent.width
                text: projectListProcess.running ? "Discovering projects..."
                  : (root.projectError !== "" ? root.projectError
                    : (root.projectRootsConfigured ? "No projects match"
                      : "No project roots configured · use Custom"))
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                topPadding: Style.space(14)
                bottomPadding: Style.space(14)
              }

              ListView {
                id: projectList
                visible: root.visibleProjects.length > 0
                width: parent.width
                implicitHeight: Math.min(contentHeight, Style.space(180))
                model: root.visibleProjects
                spacing: Style.space(3)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Rectangle {
                  required property var modelData
                  required property int index
                  width: ListView.view.width
                  height: Style.space(56)
                  radius: Style.cornerRadius
                  color: index === root.selectedProjectIndex
                    ? Style.selectedFillFor(root.foreground, Color.accent)
                    : (projectMouse.containsMouse
                      ? Util.alpha(root.foreground, 0.06) : "transparent")
                  Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Style.space(9)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(1)
                    Text {
                      width: parent.width
                      text: String(modelData.name)
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: index === root.selectedProjectIndex
                      elide: Text.ElideRight
                    }
                    Text {
                      width: parent.width
                      text: String(modelData.group) + " · " + root.compactPath(modelData.path)
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideMiddle
                    }
                  }
                  MouseArea {
                    id: projectMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.selectedProjectIndex = index
                    onClicked: root.selectedProjectIndex = index
                    onDoubleClicked: {
                      root.selectedProjectIndex = index
                      root.submitForm()
                    }
                  }
                }
              }

              Text {
                visible: root.visibleProjects.length > 0 && root.projectError !== ""
                width: parent.width
                text: root.projectError
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
              }
            }

            TextField {
              id: nameField
              visible: !root.directoryPickerOpen && (root.formMode !== "workspace"
                || root.workspaceCreationMode === "custom")
              width: parent.width
              placeholderText: root.formMode === "workspace" ? "Workspace name" : "Shell name"
              foreground: root.foreground
              onTextEdited: root.nameFieldEdited = true
              onAccepted: cwdField.forceActiveFocus()
              Keys.onEscapePressed: root.cancelForm()
            }
            Row {
              visible: !root.directoryPickerOpen && (root.formMode !== "workspace"
                || root.workspaceCreationMode === "custom")
              width: parent.width
              spacing: Style.space(6)
              TextField {
                id: cwdField
                width: parent.width - browseButton.width - parent.spacing
                placeholderText: root.formMode === "workspace" ? "Default directory (optional)" : "Directory (optional)"
                foreground: root.foreground
                onTextEdited: root.cwdIsExact = false
                onAccepted: root.submitForm()
                Keys.onEscapePressed: root.cancelForm()
              }
              Button {
                id: browseButton
                width: Style.space(88)
                text: "Browse"
                tooltipText: "Choose a directory"
                focusable: true
                bordered: true
                foreground: root.foreground
                onClicked: root.openDirectoryPicker()
              }
            }
            Row {
              visible: !root.directoryPickerOpen && root.formMode === "agent"
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
              visible: !root.directoryPickerOpen
              width: parent.width
              spacing: Style.space(6)
              Button {
                width: (parent.width - parent.spacing) / 2
                text: "Cancel"
                focusable: true
                bordered: true
                foreground: root.foreground
                onClicked: root.cancelForm()
              }
              Button {
                width: (parent.width - parent.spacing) / 2
                text: root.formMode === "agent" ? "Create & Open"
                  : (root.formMode === "workspace" && root.workspaceCreationMode === "project"
                    ? "Create from Project" : "Create")
                bordered: true
                focusable: true
                active: true
                enabled: !actionProcess.running && (root.formMode === "workspace"
                  && root.workspaceCreationMode === "project"
                    ? root.selectedProject !== null : nameField.text.trim() !== "")
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
              visible: root.visibleWorkspaces.length === 0
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
              visible: root.visibleWorkspaces.length > 0
              width: parent.width
              implicitHeight: Math.min(contentHeight, Style.space(150))
              model: root.visibleWorkspaces
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
                opacity: modelData.node_stale ? 0.66 : 1
                color: modelData.key === root.selectedWorkspaceKey
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
                    text: root.nodeName(modelData) + " / " + String(modelData.name)
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: modelData.key === root.selectedWorkspaceKey
                    elide: Text.ElideRight
                  }
                  Text {
                    width: parent.width
                    text: root.workspaceItemCount(modelData) + " items · "
                      + Number(modelData.schedule_count || 0) + " schedules · "
                      + root.workspaceActiveAgentCount(modelData) + " active agents · "
                      + String(modelData.node_health).split("_").join(" ")
                    color: modelData.attention_count > 0 ? root.urgent : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }
                MouseArea {
                  id: workspaceMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  onEntered: root.selectedIndex = index
                  onClicked: root.selectWorkspace(modelData.key)
                  onDoubleClicked: if (root.nodeIsActionable(modelData.node_id,
                    "guarded_remote_management")) root.openWorkspace(modelData)
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
                  text: root.workspaceDetail
                    ? root.nodeName(root.workspaceDetail) + " / " + String(root.workspaceDetail.name) : ""
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
                    enabled: root.workspaceDetail
                      && root.nodeIsActionable(root.workspaceDetail.node_id, "guarded_remote_management")
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
                    enabled: root.workspaceDetail && root.nodeFor(root.workspaceDetail.node_id).local
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
                    enabled: root.workspaceDetail && root.nodeFor(root.workspaceDetail.node_id).local
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
                      anchors.right: removeItemButton.left
                      anchors.rightMargin: Style.space(8)
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
                      enabled: root.nodeIsActionable(modelData.node_id,
                        modelData.kind === "launcher" ? "remote_launcher_invocation" : "remote_pty_attachment")
                      onClicked: root.openWorkspaceItem(modelData)
                    }
                    Button {
                      id: removeItemButton
                      z: 1
                      anchors.right: parent.right
                      anchors.rightMargin: Style.space(8)
                      anchors.verticalCenter: parent.verticalCenter
                      text: "Remove"
                      tooltipText: modelData.kind === "launcher"
                        ? "Remove launcher definition"
                        : "Close and remove backing shell"
                      bordered: true
                      enabled: root.nodeFor(modelData.node_id) && root.nodeFor(modelData.node_id).local
                        && !actionProcess.running
                        && !openProcess.running && !executionOpenProcess.running
                      foreground: root.urgent
                      fontSize: Style.font.caption
                      horizontalPadding: Style.space(6)
                      verticalPadding: Style.space(2)
                      onClicked: root.requestRemoveItem(modelData)
                    }
                  }
                }
              }
            }
          }
        }

        Item {
          visible: root.activeTab === "schedules" && !root.editing
          width: parent.width
          implicitHeight: scheduleColumn.implicitHeight

          Column {
            id: scheduleColumn
            width: parent.width
            spacing: Style.space(6)

            Row {
              width: parent.width
              PanelSectionHeader {
                width: parent.width - schedulerStatus.width
                anchors.verticalCenter: parent.verticalCenter
                text: "SCHEDULES"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }
              Text {
                id: schedulerStatus
                anchors.verticalCenter: parent.verticalCenter
                text: root.selectedSchedule && root.nodeFor(root.selectedSchedule.node_id)
                  ? (root.nodeFor(root.selectedSchedule.node_id).scheduler.state === "active"
                    ? Number(root.nodeFor(root.selectedSchedule.node_id).scheduler.active_executions || 0)
                      + "/" + Number(root.nodeFor(root.selectedSchedule.node_id).scheduler.max_concurrent || 0)
                      + " active · " + root.nodeName(root.selectedSchedule)
                    : String(root.nodeFor(root.selectedSchedule.node_id).scheduler.state)
                      + " · " + root.nodeName(root.selectedSchedule))
                  : root.nodes.length + " Nodes"
                color: root.selectedSchedule && root.nodeFor(root.selectedSchedule.node_id)
                  && root.nodeFor(root.selectedSchedule.node_id).scheduler.state === "active"
                  ? Color.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Text {
              visible: !root.capabilitiesReady || !root.scheduleAvailable || !root.online
              width: parent.width
              text: !root.capabilitiesReady ? "Checking Boomux Schedule support..."
                : (!root.scheduleCommandsSupported ? "Upgrade Boomux to a Schedule-capable release"
                  : (root.daemonProtocolVersion < 25 ? "Restart Boomux with daemon protocol 25 or newer"
                    : (root.error !== "" ? root.error : "Boomux daemon is stopped")))
              color: root.daemonProtocolVersion > 0 && root.daemonProtocolVersion < 25 ? root.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              topPadding: Style.space(24)
              bottomPadding: Style.space(24)
              wrapMode: Text.Wrap
            }

            Text {
              visible: root.scheduleAvailable && root.online && root.visibleSchedules.length === 0
              width: parent.width
              text: root.scheduleError !== "" ? root.scheduleError : "No Boomux Schedules"
              color: root.scheduleError !== "" ? root.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              topPadding: Style.space(20)
              bottomPadding: Style.space(20)
              wrapMode: Text.Wrap
            }

            ListView {
              id: scheduleList
              visible: root.scheduleAvailable && root.online && root.visibleSchedules.length > 0
              width: parent.width
              implicitHeight: Math.min(contentHeight, Style.space(190))
              model: root.visibleSchedules
              spacing: Style.space(3)
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              currentIndex: root.activeTab === "schedules" ? root.selectedIndex : -1
              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
              delegate: Rectangle {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: Style.space(58)
                radius: Style.cornerRadius
                opacity: modelData.node_stale ? 0.66 : 1
                color: modelData.key === root.selectedScheduleKey
                  ? Style.selectedFillFor(root.foreground, Color.accent)
                  : (scheduleMouse.containsMouse
                    ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                    : "transparent")
                Text {
                  id: scheduleGlyph
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.state === "enabled" ? "●" : "○"
                  color: modelData.state === "enabled" ? Color.accent : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
                Column {
                  anchors.left: scheduleGlyph.right
                  anchors.leftMargin: Style.space(10)
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)
                  Text {
                    width: parent.width
                    text: root.nodeName(modelData) + " / " + String(modelData.workspace_name)
                      + " / " + String(modelData.name)
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: modelData.key === root.selectedScheduleKey
                    elide: Text.ElideRight
                  }
                  Text {
                    width: parent.width
                    text: String(modelData.state) + " · " + root.scheduleTiming(modelData)
                    color: modelData.state === "enabled" ? Color.accent : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }
                MouseArea {
                  id: scheduleMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  onEntered: root.selectedIndex = index
                  onClicked: root.selectSchedule(modelData.key)
                }
              }
            }

            BorderSurface {
              visible: root.selectedSchedule !== null && root.scheduleAvailable && root.online
              width: parent.width
              implicitHeight: scheduleDetailColumn.implicitHeight + Style.space(18)
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.025)
              borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
              radius: Style.cornerRadius

              Column {
                id: scheduleDetailColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(9)
                spacing: Style.space(5)

                Text {
                  width: parent.width
                  text: root.selectedSchedule ? String(root.selectedSchedule.name) : ""
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                  elide: Text.ElideRight
                }
                Text {
                  width: parent.width
                  text: root.selectedSchedule
                    ? root.compactPath(root.selectedSchedule.cwd) + " · "
                      + String(root.selectedSchedule.integration) + " · "
                      + String(root.selectedSchedule.session_mode)
                    : ""
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideMiddle
                }
                Text {
                  width: parent.width
                  text: root.selectedSchedule
                    ? String(root.selectedSchedule.cron) + " · " + String(root.selectedSchedule.timezone)
                    : ""
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }

                Row {
                  width: parent.width
                  spacing: Style.space(6)
                  Button {
                    width: (parent.width - parent.spacing) / 2
                    text: "Run Now"
                    iconText: "▶"
                    tooltipText: "Start one execution now"
                    bordered: true
                    active: true
                    enabled: root.selectedSchedule
                      && root.nodeIsActionable(root.selectedSchedule.node_id,
                        "remote_agent_schedule_management")
                      && !actionProcess.running && !executionOpenProcess.running
                    foreground: root.foreground
                    fontSize: Style.font.caption
                    iconSize: Style.font.caption
                    onClicked: root.runSchedule(root.selectedSchedule)
                  }
                  Button {
                    width: (parent.width - parent.spacing) / 2
                    text: root.selectedSchedule && root.selectedSchedule.state === "paused" ? "Resume" : "Pause"
                    iconText: root.selectedSchedule && root.selectedSchedule.state === "paused" ? "▶" : "Ⅱ"
                    tooltipText: root.selectedSchedule && root.selectedSchedule.state === "paused"
                      ? "Enable future timed dispatch" : "Pause future timed dispatch"
                    bordered: true
                    enabled: root.selectedSchedule
                      && root.nodeIsActionable(root.selectedSchedule.node_id,
                        "remote_agent_schedule_management")
                      && !actionProcess.running && !executionOpenProcess.running
                    foreground: root.foreground
                    fontSize: Style.font.caption
                    iconSize: Style.font.caption
                    onClicked: root.setSchedulePaused(root.selectedSchedule,
                      root.selectedSchedule && root.selectedSchedule.state !== "paused")
                  }
                }

                PanelSectionHeader {
                  width: parent.width
                  text: "LAST RUN"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                }
                Text {
                  visible: root.executionError !== ""
                  width: parent.width
                  text: root.executionError
                  color: root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.Wrap
                }
                Text {
                  visible: root.latestExecution === null && root.executionError === ""
                  width: parent.width
                  text: "No runs yet"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  horizontalAlignment: Text.AlignHCenter
                  topPadding: Style.space(8)
                  bottomPadding: Style.space(8)
                }
                Rectangle {
                  visible: root.latestExecution !== null
                  width: parent.width
                  height: Style.space(54)
                  radius: Style.cornerRadius
                  color: lastRunMouse.containsMouse && root.executionCanOpen(root.latestExecution)
                    ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                    : "transparent"
                  Text {
                    id: executionGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(7)
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.latestExecution
                      && (root.latestExecution.state === "active" || root.latestExecution.state === "starting") ? "●" : "○"
                    color: root.latestExecution
                      && (root.latestExecution.state === "dispatch_failed" || root.latestExecution.state === "interrupted")
                      ? root.urgent
                      : (root.latestExecution
                        && (root.latestExecution.state === "active" || root.latestExecution.state === "starting")
                        ? Color.accent : root.dim)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                  Column {
                    anchors.left: executionGlyph.right
                    anchors.leftMargin: Style.space(9)
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(7)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(1)
                    Text {
                      width: parent.width
                      text: root.latestExecution ? String(root.latestExecution.state) + " · "
                        + root.formatTimestamp(root.latestExecution.started_at_ms || root.latestExecution.requested_at_ms) : ""
                      color: root.latestExecution
                        && (root.latestExecution.state === "dispatch_failed" || root.latestExecution.state === "interrupted")
                        ? root.urgent : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                    Text {
                      width: parent.width
                      text: root.latestExecution
                        ? root.executionDetail(root.latestExecution)
                          + (root.executionCanOpen(root.latestExecution) ? " · click to open" : " · unavailable")
                        : ""
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }
                  MouseArea {
                    id: lastRunMouse
                    anchors.fill: parent
                    enabled: root.executionCanOpen(root.latestExecution)
                      && !executionOpenProcess.running && !actionProcess.running
                    hoverEnabled: true
                    onClicked: root.openExecution(root.latestExecution)
                  }
                }
              }
            }

            Text {
              visible: root.scheduleAvailable && root.online && root.visibleSchedules.length > 0
              width: parent.width
              text: "Enter selects · Tab switches · R refreshes"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
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

      ConfirmDialog {
        id: removeItemDialog
        anchors.fill: parent
        opened: root.itemToRemove !== null
        z: 10
        message: root.removeItemMessage(root.itemToRemove)
        confirmText: "Remove"
        background: Color.background
        foreground: root.foreground
        scrim: Util.alpha(Color.background, 0.72)
        selectedBackground: Util.alpha(root.foreground, 0.08)
        selectedText: Color.accent
        fontFamily: root.fontFamily
        cornerRadius: Style.cornerRadius
        onCanceled: root.cancelRemoveItem()
        onConfirmed: root.confirmRemoveItem()
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
      ? !!root.completedAgents[agent.key] || root.attentionReason(agent) === "completed" : false
    readonly property bool dismissible: agent
      ? !!root.completedAgents[agent.key] || root.attentionRevision(agent) > 0 : false
    readonly property bool actionable: agent && root.nodeIsActionable(agent.node_id,
      "remote_pty_attachment")

    height: Style.space(66)
    radius: Style.cornerRadius
    color: selected ? Style.selectedFillFor(root.foreground, Color.accent)
      : (agentMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06) : "transparent")
    opacity: agent && agent.node_stale ? 0.66 : 1
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
        text: agent ? root.nodeName(agent) + " / " + String(agent.workspace_name)
          + " / " + root.agentDisplayName(agent) : "Agent"
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
          + (agent && (agent.node_stale || !agent.node_current)
            ? " · " + root.nodeHealthLabel(root.nodeFor(agent.node_id)) : "")
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
      enabled: agentRow.actionable || (agentRow.dismissible
        && root.agentCanAcknowledge(agent))
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
      enabled: root.agentCanAcknowledge(agent)
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
