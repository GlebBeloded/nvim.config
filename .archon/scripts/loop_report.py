#!/usr/bin/env python3
"""Build a local, read-only report from persisted Archon run evidence."""

from __future__ import annotations

import argparse
import html
import json
import re
import sqlite3
import subprocess
import sys
import tempfile
from collections import deque
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Sequence


class ReportError(Exception):
    """An expected operator-facing report error."""


@dataclass(frozen=True)
class RunRecord:
    id: str
    codebase_id: str | None
    workflow_name: str
    user_message: str
    status: str
    outcome: str | None
    metadata: dict[str, object]
    started_at: str
    completed_at: str | None
    last_activity_at: str
    working_path: Path
    output_root: Path
    repository_path: Path | None


@dataclass(frozen=True)
class EventRecord:
    event_order: int
    event_type: str
    step_name: str | None
    data: dict[str, object]
    created_at: str


@dataclass(frozen=True)
class NodeRow:
    name: str
    status: str
    invocations: int
    duration_ms: int


@dataclass(frozen=True)
class GateRecord:
    name: str
    reason: str
    decision: str
    comment: str


@dataclass(frozen=True)
class AttemptRecord:
    number: int
    passed: bool
    failures: str


@dataclass(frozen=True)
class ArtifactRecord:
    name: str
    content: str


@dataclass(frozen=True)
class ShipRecord:
    commit: str | None
    diff_stat: str | None


@dataclass(frozen=True)
class Report:
    run: RunRecord
    nodes: list[NodeRow]
    gates: list[GateRecord]
    attempts: list[AttemptRecord]
    artifacts: list[ArtifactRecord]
    ship: ShipRecord
    missing: str


def database_path(home: Path) -> Path:
    return home / ".archon" / "archon.db"


def open_database(path: Path) -> sqlite3.Connection:
    if not path.is_file():
        raise ReportError(f"Archon database not found: {path}")
    connection = sqlite3.connect(f"{path.resolve().as_uri()}?mode=ro", uri=True)
    connection.row_factory = sqlite3.Row
    connection.execute("BEGIN")
    return connection


def parse_json_object(raw: str) -> dict[str, object]:
    try:
        value = json.loads(raw)
    except (TypeError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def _run_from_row(row: sqlite3.Row) -> RunRecord:
    return RunRecord(
        id=row["id"],
        codebase_id=row["codebase_id"],
        workflow_name=row["workflow_name"],
        user_message=row["user_message"],
        status=row["status"],
        outcome=row["outcome"],
        metadata=parse_json_object(row["metadata"]),
        started_at=row["started_at"],
        completed_at=row["completed_at"],
        last_activity_at=row["last_activity_at"],
        working_path=Path(row["working_path"]),
        output_root=Path(row["output_root"]),
        repository_path=Path(row["repository_path"]) if row["repository_path"] else None,
    )


def load_named_run(connection: sqlite3.Connection, run_id: str) -> RunRecord:
    row = connection.execute(
        """SELECT id, codebase_id, workflow_name, user_message, status, outcome,
                  metadata, started_at, completed_at, last_activity_at,
                  working_path, output_root,
                  (SELECT default_cwd FROM remote_agent_codebases
                   WHERE id = remote_agent_workflow_runs.codebase_id) AS repository_path
           FROM remote_agent_workflow_runs WHERE id = ?""",
        (run_id,),
    ).fetchone()
    if row is None:
        raise ReportError(f"Unknown Archon run: {run_id}")
    return _run_from_row(row)


def git_common_dir(path: Path) -> Path:
    try:
        result = _git(["rev-parse", "--path-format=absolute", "--git-common-dir"], path)
    except OSError as error:
        raise ReportError(f"Cannot inspect Git checkout {path}: {error}") from error
    if result.returncode != 0:
        raise ReportError(f"Not a Git checkout: {path}")
    return Path(result.stdout.strip()).resolve()


def resolve_codebase(connection: sqlite3.Connection, cwd: Path) -> str:
    try:
        current_common = git_common_dir(cwd)
    except ReportError:
        raise ReportError(f"No Archon codebase matches this checkout: {cwd}") from None
    rows = connection.execute("SELECT id, default_cwd FROM remote_agent_codebases ORDER BY id").fetchall()
    for row in rows:
        registered = Path(row["default_cwd"])
        if not registered.is_dir():
            continue
        try:
            registered_common = git_common_dir(registered)
        except ReportError:
            continue
        if registered_common == current_common:
            return row["id"]
    raise ReportError(f"No Archon codebase matches this checkout: {cwd}")


def load_latest_run(connection: sqlite3.Connection, codebase_id: str) -> RunRecord:
    row = connection.execute(
        """SELECT id, codebase_id, workflow_name, user_message, status, outcome,
                  metadata, started_at, completed_at, last_activity_at,
                  working_path, output_root,
                  (SELECT default_cwd FROM remote_agent_codebases
                   WHERE id = remote_agent_workflow_runs.codebase_id) AS repository_path
           FROM remote_agent_workflow_runs WHERE codebase_id = ?
           ORDER BY started_at DESC, id DESC LIMIT 1""",
        (codebase_id,),
    ).fetchone()
    if row is None:
        raise ReportError(f"No Archon run found for codebase: {codebase_id}")
    return _run_from_row(row)


def load_events(connection: sqlite3.Connection, run_id: str) -> list[EventRecord]:
    rows = connection.execute(
        """SELECT event_order, event_type, step_name, data, created_at
           FROM remote_agent_workflow_events
           WHERE workflow_run_id = ? ORDER BY event_order""",
        (run_id,),
    ).fetchall()
    return [
        EventRecord(
            event_order=row["event_order"],
            event_type=row["event_type"],
            step_name=row["step_name"],
            data=parse_json_object(row["data"]),
            created_at=row["created_at"],
        )
        for row in rows
    ]


def _object(value: object) -> dict[str, object]:
    return value if isinstance(value, dict) else {}


def _string(value: object) -> str:
    return value if isinstance(value, str) else ""


def _integer(value: object) -> int | None:
    return value if isinstance(value, int) and not isinstance(value, bool) else None


def _terminal_nodes(run: RunRecord) -> list[str]:
    graph = _object(run.metadata.get("terminal_graph"))
    node_ids = graph.get("node_ids")
    if not isinstance(node_ids, list):
        return []
    return [node for node in node_ids if isinstance(node, str)]


def _datetime(value: object) -> datetime | None:
    if not isinstance(value, str):
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed.replace(tzinfo=parsed.tzinfo or timezone.utc)


NodeState = tuple[str, int, datetime | None]


def _fold_node_event(
    event: EventRecord,
    order: list[str],
    invocations: dict[str, dict[str, NodeState]],
    skipped: dict[str, int],
) -> None:
    node_events = {
        "node_started",
        "node_completed",
        "node_failed",
        "node_suspended",
        "node_skipped",
        "node_skipped_prior_success",
    }
    if not event.step_name or event.event_type not in node_events:
        return
    name = event.step_name
    if name not in invocations:
        order.append(name)
        invocations[name] = {}
    if event.event_type == "node_skipped_prior_success":
        return
    if event.event_type == "node_skipped":
        skipped[name] = _integer(event.data.get("duration_ms")) or 0
        return
    invocation = _object(event.data.get("invocation"))
    invocation_id = _string(invocation.get("id"))
    if not invocation_id:
        return
    _, prior_duration, prior_started = invocations[name].get(invocation_id, ("running", 0, None))
    if event.event_type == "node_started":
        timing = _object(event.data.get("timing"))
        started = _datetime(timing.get("startedAt")) or _datetime(invocation.get("startedAt"))
        invocations[name].setdefault(invocation_id, ("running", 0, started))
        return
    timing = _object(event.data.get("timing"))
    duration = _integer(event.data.get("duration_ms"))
    duration = duration if duration is not None else (_integer(timing.get("durationMs")) or prior_duration)
    status = {"node_completed": "completed", "node_failed": "failed", "node_suspended": "waiting"}[
        event.event_type
    ]
    invocations[name][invocation_id] = (status, duration, prior_started)


def _node_row(
    name: str,
    states: Sequence[NodeState],
    skipped: dict[str, int],
    live: bool,
    run_status: str,
    elapsed_until: datetime,
) -> NodeRow:
    if not states:
        return NodeRow(
            name=name,
            status="skipped" if name in skipped else "waiting",
            invocations=0,
            duration_ms=skipped.get(name, 0),
        )
    status = "skipped" if name in skipped else states[-1][0]
    if status == "running" and not live:
        status = run_status if run_status in {"cancelled", "canceled", "failed"} else "incomplete"
    duration_ms = skipped.get(name, 0)
    for invocation_status, duration, started in states:
        if invocation_status == "running" and started is not None:
            duration_ms += max(0, int((elapsed_until - started).total_seconds() * 1000))
        else:
            duration_ms += duration
    return NodeRow(name=name, status=status, invocations=len(states), duration_ms=duration_ms)


def fold_nodes(run: RunRecord, events: Sequence[EventRecord], now: datetime) -> list[NodeRow]:
    live = run.status in {"pending", "running", "paused"}
    terminal_at = _datetime(run.completed_at) or _datetime(run.last_activity_at)
    elapsed_until = now if live else terminal_at or now
    order = list(dict.fromkeys(_terminal_nodes(run)))
    invocations: dict[str, dict[str, NodeState]] = {name: {} for name in order}
    skipped: dict[str, int] = {}
    for event in events:
        _fold_node_event(event, order, invocations, skipped)
    return [
        _node_row(name, list(invocations[name].values()), skipped, live, run.status, elapsed_until) for name in order
    ]


def fold_gates(events: Sequence[EventRecord]) -> list[GateRecord]:
    pending: deque[tuple[str, str]] = deque()
    gates: list[GateRecord] = []
    for event in events:
        if event.event_type == "approval_requested":
            pending.append((event.step_name or "Approval", _string(event.data.get("message"))))
        elif event.event_type == "approval_received" and pending:
            name, reason = pending.popleft()
            decision = _string(event.data.get("decision"))
            comment_key = "reason" if decision == "rejected" else "comment"
            gates.append(
                GateRecord(
                    name=name,
                    reason=reason,
                    decision=decision,
                    comment=_string(event.data.get(comment_key)),
                )
            )
    gates.extend(
        GateRecord(name=name, reason=reason, decision="pending", comment="Pending") for name, reason in pending
    )
    return gates


def fold_attempts(events: Sequence[EventRecord]) -> list[AttemptRecord]:
    attempts: dict[int, AttemptRecord] = {}
    for event in events:
        if event.event_type != "node_completed":
            continue
        output = _object(event.data.get("structured_output"))
        number = _integer(output.get("attempt"))
        if number is None:
            continue
        prior = attempts.get(number)
        new_failures = _string(output.get("failures")) or _string(output.get("failed_gates"))
        failures = prior.failures if prior and prior.failures else new_failures
        passed_value = output.get("passed", output.get("green"))
        passed = prior.passed if prior and not isinstance(passed_value, bool) else passed_value is True
        attempts[number] = AttemptRecord(number=number, passed=passed and not failures, failures=failures)
    return [attempts[number] for number in sorted(attempts)]


def _duration(duration_ms: int) -> str:
    return f"{duration_ms / 1000:.1f}s"


def load_artifacts(run: RunRecord) -> list[ArtifactRecord]:
    root = run.output_root / "artifacts" / "runs" / run.id
    if not root.is_dir():
        return []
    recognized = re.compile(r"^(?:root-cause|escalation)\.md$|^(?:check|validate|archive)-\d+\.log$")
    artifacts: list[ArtifactRecord] = []
    for path in sorted(root.iterdir(), key=lambda item: item.name):
        if path.is_file() and recognized.fullmatch(path.name):
            artifacts.append(ArtifactRecord(name=path.name, content=path.read_text(encoding="utf-8", errors="replace")))
    return artifacts


def _git(args: Sequence[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def load_ship(run: RunRecord, events: Sequence[EventRecord]) -> ShipRecord:
    commit = ""
    for event in reversed(events):
        if event.event_type != "node_completed" or not event.step_name:
            continue
        if not (event.step_name.endswith("ship") or event.step_name.endswith("shipped")):
            continue
        output = _object(event.data.get("structured_output"))
        candidate = _string(output.get("commit"))
        if output.get("merged") is True and candidate:
            commit = candidate
            break
    if not commit:
        return ShipRecord(commit=None, diff_stat=None)

    for repository in dict.fromkeys((run.repository_path, run.working_path, run.output_root)):
        if repository is None or not repository.is_dir():
            continue
        resolved = _git(["rev-parse", "--verify", "--end-of-options", f"{commit}^{{commit}}"], repository)
        if resolved.returncode != 0:
            continue
        full_commit = resolved.stdout.strip()
        stat = _git(["diff", "--stat", "--no-ext-diff", "--no-color", f"{full_commit}^1", full_commit, "--"], repository)
        if stat.returncode == 0:
            return ShipRecord(commit=full_commit, diff_stat=stat.stdout.strip())
    return ShipRecord(commit=commit, diff_stat=None)


def missing_label(run: RunRecord) -> str:
    return "Pending" if run.status in {"pending", "running", "paused"} else "Unavailable"


def build_report(run: RunRecord, events: Sequence[EventRecord], now: datetime) -> Report:
    return Report(
        run=run,
        nodes=fold_nodes(run, events, now),
        gates=fold_gates(events),
        attempts=fold_attempts(events),
        artifacts=load_artifacts(run),
        ship=load_ship(run, events),
        missing=missing_label(run),
    )


def _render_nodes(report: Report) -> str:
    return "".join(
        "<tr><td>{}</td><td>{}</td><td>{}</td><td>{}</td></tr>".format(
            html.escape(node.name),
            html.escape(node.status),
            html.escape(f"{node.invocations} invocation" + ("s" if node.invocations != 1 else "")),
            html.escape(_duration(node.duration_ms)),
        )
        for node in report.nodes
    )


def _render_gates(report: Report) -> str:
    return "".join(
        "<article><h3>{}</h3><p>{}</p><p>{}: {}</p></article>".format(
            html.escape(gate.name),
            html.escape(gate.reason),
            html.escape(gate.decision),
            html.escape(gate.comment),
        )
        for gate in report.gates
    ) or f"<p>{html.escape(report.missing)}</p>"


def _render_attempts(report: Report) -> str:
    attempt_parts: list[str] = []
    for attempt in report.attempts:
        has_evidence = any(artifact.name.endswith(f"-{attempt.number}.log") for artifact in report.artifacts)
        evidence = "" if has_evidence else f"<p>Supporting evidence: {html.escape(report.missing)}</p>"
        attempt_parts.append(
            "<article><h3>Attempt {}</h3><p>{}</p>{}</article>".format(
                attempt.number,
                html.escape("passed" if attempt.passed else attempt.failures or "failed"),
                evidence,
            )
        )
    return "".join(attempt_parts) or f"<p>{html.escape(report.missing)}</p>"


def _render_artifacts(report: Report) -> str:
    return "".join(
        "<details><summary>{}</summary><pre>{}</pre></details>".format(
            html.escape(artifact.name),
            html.escape(artifact.content),
        )
        for artifact in report.artifacts
    ) or f"<p>{html.escape(report.missing)}</p>"


def _render_ship(report: Report) -> str:
    if report.ship.commit:
        return "<p>Merge {}</p><pre>{}</pre>".format(
            html.escape(report.ship.commit),
            html.escape(report.ship.diff_stat or report.missing),
        )
    return f"<p>{html.escape(report.missing)}</p>"


def render_html(report: Report) -> str:
    return """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Archon run {run_id}</title>
<style>body{{font:15px system-ui;max-width:1100px;margin:2rem auto;padding:0 1rem}}table{{border-collapse:collapse;width:100%}}th,td{{border-bottom:1px solid #ccc;padding:.5rem;text-align:left}}article{{border:1px solid #ccc;padding:0 1rem;margin:.5rem 0}}pre{{white-space:pre-wrap}}</style></head>
<body><header><h1>Archon run {run_id}</h1><p>{workflow} · {status}</p><p>{message}</p></header>
<main><section><h2>Nodes</h2><table><thead><tr><th>Node</th><th>Status</th><th>Invocations</th><th>Duration</th></tr></thead><tbody>{nodes}</tbody></table></section>
<section><h2>Gates</h2>{gates}</section><section><h2>Attempts</h2>{attempts}</section>
<section><h2>Artifacts</h2>{artifacts}</section><section><h2>Ship</h2>{ship}</section></main></body></html>""".format(
        run_id=html.escape(report.run.id),
        workflow=html.escape(report.run.workflow_name),
        status=html.escape(report.run.status),
        message=html.escape(report.run.user_message),
        nodes=_render_nodes(report),
        gates=_render_gates(report),
        attempts=_render_attempts(report),
        artifacts=_render_artifacts(report),
        ship=_render_ship(report),
    )


def write_atomic(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as temporary:
            temporary.write(content)
            temporary.flush()
            temporary_path = Path(temporary.name)
        temporary_path.replace(path)
    finally:
        if temporary_path is not None and temporary_path.exists():
            temporary_path.unlink()


def summary_lines(report: Report, report_path: Path) -> tuple[str, str]:
    merge = f"merge {report.ship.commit}" if report.ship.commit else report.missing.lower()
    identity = (
        f"{report.run.id} · {report.run.workflow_name} · {report.run.status} · "
        f"{len(report.nodes)} nodes · {len(report.attempts)} attempts · {merge}"
    )
    return identity, f"Report: {report_path.resolve().as_uri()}"


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", help="Archon workflow run id")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        with open_database(database_path(Path.home())) as connection:
            run = (
                load_named_run(connection, args.run)
                if args.run
                else load_latest_run(connection, resolve_codebase(connection, Path.cwd()))
            )
            events = load_events(connection, run.id)
        now = datetime.now(timezone.utc)
        report = build_report(run, events, now)
        report_path = run.output_root / "artifacts" / "runs" / run.id / "report.html"
        write_atomic(report_path, render_html(report))
        print(*summary_lines(report, report_path), sep="\n")
        return 0
    except (ReportError, sqlite3.Error) as error:
        print(error, file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
