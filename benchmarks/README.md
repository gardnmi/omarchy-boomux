# Snapshot-to-view benchmark

Run `bun benchmarks/workspace-model.js` (or `node benchmarks/workspace-model.js`).
Add `--json` for machine-readable results and `--compare-baseline` to time the
pre-index view algorithm as well as checking its output parity.

Each of the 40 / 1,000 / 2,000 / 4,000 / 8,000-Agent fixtures, plus a concentrated
4,000-Agent single-Workspace fixture, gets three warmups and nine measured runs.
Every iteration allocates fresh raw input before the timer. The timed pipeline
includes normalization, qualified Node/Shell/current-run Agent indexes, visible
and completed Agent views, all Workspace child projections, and the structural
tree signature. Fixture allocation, parity assertions and output hashing are
outside the measurement. Cached repeated projections are not substituted for a
fresh snapshot. The baseline uses the same current normalizer, so it isolates
view improvements without attributing normalization improvements to them.

`view-reference.js` retains the previous scan-based view derivation as an
independent test/benchmark oracle. Every fixture must have the same visible
qualified identities/order, completed count, structural signature and child
projection fields. Tests also cover private Shell ownership, historical
attention, missing Shells, run changes, lifecycle states and deterministic ties.
A record-read scaling test guards the concentrated-Workspace case without a
hardware-dependent wall-clock threshold.

Timings are synthetic JavaScript measurements, not live Quickshell frame times,
compositor expansion latency or a production speedup promise. Runtime/version,
platform, architecture and CPU are recorded; medians and p95 values are
informational. Live QML object counts, memory and frame stalls require a separate
compositor smoke/profile run.

## Polling and live-profile limits

The executable polling harness checks the Panel's actual JavaScript scheduling
logic with a simulated clock and process stubs; it launches no daemon. Idle
healthy event-backed reconciliation schedules 12 status reads per simulated
minute rather than 60. Unsupported or failed streams retain the one-second
fallback. Stopped-daemon checks back off to at most 15 seconds, and explicit
refresh bypasses the deadline. Every event-wait renewal first checks passive
daemon status.

Meaningful events coalesce for 100 ms after delivery. Output-only event traffic
renews at most once per second without rebuilding a fresh snapshot. A meaningful
event occurring during that gap can take about 1.1 seconds before refresh begins,
plus CLI and snapshot duration. Backlog can defer delivery until reconciliation;
this is not a 100 ms end-to-end attention guarantee. Full event-backed snapshots
still reconcile every five seconds, and status-only renewals cannot move that
deadline. Web status reads have their own five-second budget.

No real daemon CPU profile, Quickshell/QML delegate or memory profile, compositor
frame measurement, or live attention-latency measurement has been captured in
this environment. Before attributing a production speedup, measure idle and burst
loads on the target desktop, including a stopped daemon, failed event stream,
cursor reset, output-only traffic, closed-pane attention, and 10/100/1,000 expanded
Workspace items. Record actual process counts, CPU, object count, memory and
frame/attention latency alongside these synthetic results.
