// Slow reference derived verbatim from the snapshot/view helpers at 8f4ff709.
// Test/benchmark oracle only; never imported by Panel.qml.
function referenceViews(snapshot, completedAgents) {
  const agents = snapshot.agents, shells = snapshot.shells
function agentHasPrivateOwner(agent, shells) {
  if (!agent || !agent.shell_id) return false
  for (var i = 0; i < shells.length; i++) {
    var shell = shells[i]
    if (shell && shell.node_id === agent.node_id && shell.id === agent.shell_id)
      return shellOwner(shell.owner) === "schedule"
  }
  return false
}

function shellOwner(owner) {
  if (typeof owner === "string") return owner
  return owner && owner.kind === "schedule" ? "schedule" : "user"
}

function agentMatchesShell(agent, shell) {
  if (!agent || !shell || agent.node_id !== shell.node_id || agent.shell_id !== shell.id)
    return false
  var runId = shell.run ? shell.run.id : shell.run_id
  return !!runId && agent.run_id === runId
}

function shellStatus(status) {
  if (typeof status === "string") return status
  return status && status.exited !== undefined ? "exited" : "unknown"
}

function workspaceTreeItems(workspace) {
  if (!workspace) return []
  var items = []
  var shells = workspace.shells || []
  var agents = workspace.agents || []
  for (var s = 0; s < shells.length; s++) {
    var shell = shells[s]
    if (!shell || shellOwner(shell.owner) === "schedule") continue
    var activeAgent = null
    for (var a = 0; a < agents.length; a++) {
      var candidate = agents[a]
      var state = candidate && candidate.observation
        ? String(candidate.observation.state || "unknown") : "unknown"
      if (agentMatchesShell(candidate, shell) && candidate.ended_at_ms == null
          && state !== "inactive" && state !== "done") {
        activeAgent = candidate
        break
      }
    }
    items.push({
      key: String(shell.key || resourceKey(shell.node_id, shell.id)),
      kind: activeAgent ? "agent"
        : (shell.command && shell.command.length > 0 ? "command" : "shell"),
      name: String(shell.name || "unnamed"),
      status: shellStatus(shell.status),
      detail: shell.command && shell.command.length > 0
        ? shell.command.join(" ") : String(shell.cwd || ""),
      node_id: String(shell.node_id || ""),
      node_alias: String(shell.node_alias || "local"),
      placement_state: String(shell.placement_state || "active"),
      workspace: workspace,
      shell: shell,
      launcher: null
    })
  }
  var launchers = workspace.launchers || []
  for (var l = 0; l < launchers.length; l++) {
    var launcher = launchers[l]
    if (!launcher) continue
    items.push({
      key: String(launcher.key || resourceKey(launcher.node_id, launcher.id)),
      id: String(launcher.id || ""),
      kind: "launcher",
      name: String(launcher.name || "unnamed"),
      status: "on open",
      detail: launcher.command ? launcher.command.join(" ") : "",
      node_id: String(launcher.node_id || ""),
      node_alias: String(launcher.node_alias || "local"),
      node_local: !!launcher.node_local,
      placement_state: String(launcher.placement_state || "active"),
      workspace: workspace,
      shell: null,
      launcher: launcher
    })
  }
  return items
}

function workspaceTreeModelSignature(workspaces) {
  return JSON.stringify((workspaces || []).map(function(workspace) {
    return {
      row: [workspace.key, workspace.id, workspace.name, !!workspace.is_global,
        !!workspace.is_external, !!workspace.closing, !!workspace.available,
        workspace.node_id, workspace.node_current, workspace.node_stale,
        workspace.default_cwd, Number(workspace.attention_count || 0),
        Number(workspace.shell_count || 0)],
      placements: (workspace.placements || []).map(function(placement) {
        return [placement.node_id, placement.workspace_id, placement.state,
          placement.default_cwd, !!placement.available,
          !!placement.node_current, !!placement.node_stale]
      }),
      items: workspaceTreeItems(workspace).map(function(item) {
        var resource = item.kind === "launcher" ? item.launcher : item.shell
        return [item.key, item.kind, item.name, item.status, item.detail,
          item.node_id, item.node_alias, item.placement_state,
          resource ? resource.id : "", resource ? resource.owner : "",
          resource ? !!resource.node_current : false,
          resource ? !!resource.node_stale : false]
      })
    }
  }))
}

function agentsByLastUpdated(agents) {
  return agents.slice().sort(function(left, right) {
    var difference = agentUpdatedAt(right) - agentUpdatedAt(left)
    if (difference !== 0) return difference
    var leftKey = String(left.key || left.id || "")
    var rightKey = String(right.key || right.id || "")
    return leftKey < rightKey ? -1 : (leftKey > rightKey ? 1 : 0)
  })
}

function agentUpdatedAt(agent) {
  if (!agent) return 0
  var observation = agent.observation
    ? Number(agent.observation.observed_at_ms || 0) : Number(agent.observed_at_ms || 0)
  var attention = agent.attention && agent.attention.observation
    ? Number(agent.attention.observation.observed_at_ms || 0) : 0
  return Math.max(observation, attention, Number(agent.started_at_ms || 0))
}

function resourceKey(nodeId, value) {
  return String(nodeId || "") + "\u001f" + resourceId(value)
}

function resourceId(value) {
  return value && typeof value === "object" ? String(value.inner_id || "") : String(value || "")
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

  function attentionRevision(agent) {
    return agent && agent.attention && agent.attention.observation
      ? Number(agent.attention.observation.revision) : 0
  }

  function attentionReason(agent) {
    return agent && agent.attention && agent.attention.reason ? String(agent.attention.reason) : ""
  }

  function countCompletedAgents() {
    var completed = ({})
    for (var i = 0; i < agents.length; i++) {
      if (agentHasPrivateOwner(agents[i], shells)) continue
      if (completedAgents[agents[i].key] && agentIsProjectedCurrent(agents[i]))
        completed[agents[i].key] = true
      if (attentionReason(agents[i]) === "completed" && attentionRevision(agents[i]) > 0)
        completed[agents[i].key] = true
    }
    return Object.keys(completed).length
  }
  // The Panel helper closes over shells, while the model helper takes them.
  const isPrivate = agent => agentHasPrivateOwner(agent, shells)
  return {
    visible: agentsByLastUpdated(agents.filter(agent => {
      const state = agent.observation ? agent.observation.state : "unknown"
      return !isPrivate(agent)
        && ((agentIsProjectedCurrent(agent) && state !== "inactive" && state !== "done")
          || attentionRevision(agent) > 0)
    })),
    completed: countCompletedAgents(),
    signature: workspaceTreeModelSignature(snapshot.workspaces),
    items: snapshot.workspaces.map(workspaceTreeItems)
  }
}

module.exports = { referenceViews }
