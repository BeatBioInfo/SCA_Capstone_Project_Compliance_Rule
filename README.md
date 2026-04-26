# Compliance Audit Tool

A modular Bash tool that audits a Docker host against 15 security and compliance rules. Produces text, JSON, and Prometheus reports on every run, and ships with a Grafana dashboard for tracking compliance over time.

## What it checks

15 rules across container, network, and host scopes — see [`CHECKLIST.md`](./CHECKLIST.md) for the full list with severities and rationales. Highlights:

- No containers running as root or with `--privileged`
- No plaintext secrets in environment variables (heuristic match on var names)
- No host network mode, host PID namespace, or unauthenticated Docker API on TCP 2375
- All containers have CPU and memory limits, healthchecks, and read-only root filesystems
- Host disk usage below threshold; images younger than 90 days; trusted registries only

Each rule is implemented as a single-purpose script in `checks/`. The runner discovers and executes them automatically — adding a new rule is one new file, no other changes.

## Quick start

Requires `docker`, `jq`, and `bash` on the host running the audit.

```bash
git clone <repo-url>
cd compliance-audit-tool
./run_audit.sh
```

You'll see live pass/fail output, plus three artifacts written to disk:

- `reports/audit-<timestamp>.txt` — human-readable findings
- `reports/audit-<timestamp>.json` — structured data for downstream tools
- `metrics/compliance.prom` — Prometheus exposition format

## Configuration

All thresholds and lists are environment variables. Override at runtime:

| Variable | Purpose | Default |
|---|---|---|
| `DISK_THRESHOLD` | Max disk usage % before C06 fails | `80` |
| `MAX_IMAGE_AGE_DAYS` | Max image age in days before C14 fails | `90` |
| `TRUSTED_REGISTRIES` | Comma-separated allowlist of registry prefixes | `docker.io/library,docker.io/myorg,ghcr.io/myorg` |
| `ALLOWED_PORTS` | Comma-separated allowlist of host ports for C03 | `80,443,8080,8443` |
| `SECRET_PATTERNS` | Comma-separated substrings flagged in env var names | `PASSWORD,PASSWD,PWD,SECRET,TOKEN,KEY,APIKEY,CREDENTIAL,CREDS` |
| `REPORT_DIR` | Where to write text/JSON reports | `./reports` |
| `METRICS_DIR` | Where to write `.prom` metrics | `./metrics` |

Example — strict thresholds for a CI environment:

```bash
DISK_THRESHOLD=70 MAX_IMAGE_AGE_DAYS=30 ./run_audit.sh
```

## Scheduled runs

The tool is designed to run on a schedule (cron, systemd timers, Kubernetes CronJob). A typical hourly cron entry: