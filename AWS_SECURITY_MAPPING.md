# Local Compliance Checks → AWS Native Services

This memo maps each rule enforced by the local Docker compliance audit
([CHECKLIST.md](./CHECKLIST.md)) to its closest equivalent in AWS-native
security services: Security Hub, AWS Config, GuardDuty, IAM Access
Analyzer, and Trusted Advisor.

The local tool exists to audit hosts at the operating-system and Docker
layer — what runs as root, which ports are published, which images are
trusted. Once workloads move to AWS-managed services (ECS Fargate, EKS,
Lambda), most of those controls shift from "things we run on a server"
to "things AWS configures on our behalf." The mapping below shows where
each control lands when that shift happens, and where the local tool
remains the right answer.

## AWS service glossary

| Service | What it is | Relates to this audit by... |
|---|---|---|
| **AWS Security Hub** | Aggregator that collects findings from other AWS security services and third-party tools into one prioritized view. | Functions like the *report layer* of this audit — what your `reports/audit-*.json` is, but for an entire AWS account. |
| **AWS Config** | Continuous evaluation engine: records the state of every supported AWS resource and runs rules against it. | Functions like the *individual checks* — each Config rule asks one question about one resource type, the same shape as `checks/c*.sh`. |
| **Amazon GuardDuty** | Threat detection from CloudTrail events, VPC flow logs, and DNS logs. Catches active malicious behavior, not misconfiguration. | Largely *out of scope* — this audit catches misconfig (a static problem). GuardDuty catches intrusion (a dynamic problem). Different layer. |
| **IAM Access Analyzer** | Reasons over resource policies and reports anything reachable from outside your account or organization. | Maps to the *external-exposure* family of checks — published ports (C03), trusted registries (C04), and unauthenticated APIs (C12) all become "is this AWS resource exposed?" questions. |
| **AWS Trusted Advisor** | Best-practice scanner across cost, performance, and security. Coarse-grained, lots of overlap with Config and Access Analyzer. | Closest to a *first-pass triage* tool. The local audit is finer-grained; Trusted Advisor is what you'd run before adopting any of the others. |

## Per-check mapping

For each rule in [`CHECKLIST.md`](./CHECKLIST.md), the table below names the
closest AWS-native equivalent. Where AWS Config rules apply, the specific
managed rule identifier is given so a security team can enable it directly.

| ID | Local check | Primary AWS equivalent | Specific rule / mechanism |
|---|---|---|---|
| C01 | No containers as root | AWS Config | `ecs-no-environment-variables` is the closest built-in for ECS; for EKS, use the `kubernetes-no-root-user` Gatekeeper policy. EC2 has no native rule — root inside an EC2-launched container is invisible to AWS. |
| C02 | Healthcheck defined | AWS Config | `elb-healthcheck-required` for load balancers; `ecs-task-definition-nonroot-user` does not cover this directly. ECS service definitions can require healthchecks via task-definition Config rules. |
| C03 | No unexpected published ports | IAM Access Analyzer + AWS Config | Access Analyzer flags publicly-reachable resources; Config rule `restricted-common-ports` blocks security groups that expose 22, 3389, etc. Together they cover "is this port reachable from the internet." |
| C04 | Trusted registries only | AWS Config (custom) | No built-in rule. Implement as a custom Config rule with a Lambda that inspects `Image` fields on ECS task definitions and EKS pod specs against an allowlist. ECR repository policies can also enforce this at pull time. |
| C05 | No plaintext secrets in env vars | AWS Config + Secrets Manager | Config rule `ecs-no-environment-variables-secrets` flags ECS task definitions whose env vars match secret-like names. The remediation is to migrate to Secrets Manager or Parameter Store and reference values via task-definition `secrets` blocks. |
| C06 | Disk usage below threshold | CloudWatch Alarms | Not a compliance check in AWS terms — a runtime metric. CloudWatch agent emits `disk_used_percent` from EC2 instances; alarm fires when over threshold. AWS Config doesn't cover this. |
| C07 | CPU limits on containers | AWS Config | `ecs-task-definition-memory-hard-limit` exists; CPU limits are enforced by the Fargate platform automatically. On EKS, use Gatekeeper or Kyverno policies for `requests`/`limits`. |
| C08 | Memory limits on containers | AWS Config | Same as C07 — `ecs-task-definition-memory-hard-limit`. Fargate enforces these natively at the platform layer. |
| C09 | No `--privileged` containers | AWS Config | `ecs-containers-nonprivileged` flags ECS task definitions with `privileged: true`. EKS handled via Pod Security Standards (`restricted` or `baseline` profile). |
| C10 | Read-only root filesystem | AWS Config | `ecs-containers-readonly-access` flags ECS containers without `readonlyRootFilesystem: true`. EKS handled via Pod Security Standards. |
| C11 | No host network mode | AWS Config | `ecs-task-definition-pid-mode-check` covers PID; for network mode, the Config rule `ecs-task-definition-host-networking-disabled` flags `networkMode: host`. |
| C12 | Docker API not on TCP 2375 | IAM Access Analyzer + Security Group rules | On AWS, the equivalent risk is an exposed Docker daemon on a self-managed EC2 host. Detected by combining VPC security-group analysis (Config rule `restricted-common-ports`) with Access Analyzer for resource-level exposure. |
| C13 | No host PID namespace | AWS Config | `ecs-task-definition-pid-mode-check` flags `pidMode: host`. |
| C14 | Images younger than 90 days | Amazon ECR + AWS Config | ECR has built-in image scanning and lifecycle policies. Use ECR lifecycle rules to expire images older than N days; pair with `ecr-private-image-scanning-enabled` Config rule. AWS does not enforce a max age on running tasks directly — you'd write a custom Config rule. |
| C15 | Docker Content Trust enabled | Amazon ECR + IAM | ECR supports image signing via AWS Signer. Combine with an IAM-based deployment policy that requires signed images. The local `DOCKER_CONTENT_TRUST` env var has no direct AWS analog — the equivalent control is "deployment pipelines reject unsigned images." |

## Local checks → AWS equivalents

| Local check | What it asks | AWS equivalent | Notes |
|---|---|---|---|
| **C01** No root user | Container's `USER` is non-zero | AWS Config: `ecs-task-definition-nonroot-user` | Direct ECS analog. For EKS, enforce via Pod Security Admission (`restricted` profile) — Config can detect non-compliant clusters but not pods individually. |
| **C02** Healthcheck defined | Image has a `HEALTHCHECK` instruction | (no clean equivalent) | ECS and ALB target groups handle health *at runtime*, not at definition time. Closest practice is requiring an ALB/NLB health check on every service — enforced via tagging policy, not Config. |
| **C03** No unexpected published ports | Host port mappings outside the allowlist | AWS Config: `restricted-ssh`, `vpc-sg-open-only-to-authorized-ports`; IAM Access Analyzer for resource exposure | The cloud version asks "which security groups allow inbound from 0.0.0.0/0?" — same family of question, different mechanism. |
| **C04** Trusted registries only | Image source is on the allowlist | AWS Config: `ecr-private-image-scanning-enabled`, plus ECR repository policies and IAM permissions controlling which registries tasks can pull from | In AWS, the answer is usually "lock down to ECR private repos in your account." Stronger than an allowlist because pulls outside ECR can be denied by IAM. |
| **C05** No plaintext secrets in env vars | Env var names matching secret patterns | AWS Config: `secretsmanager-using-cmk`, plus org-level SCPs blocking `RegisterTaskDefinition` calls that include sensitive env keys | The proper AWS pattern is Secrets Manager + ECS `secrets` field (decrypted at runtime, never visible in `describe-task-definition`). The local heuristic becomes irrelevant once you adopt this — but useful as a regression check during migration. |
| **C06** Disk usage below threshold | Host filesystem fill % | CloudWatch alarm on `DiskSpaceUtilization`, or Trusted Advisor "Service Limits" | Not a Config rule — disk usage is operational telemetry, not configuration. The AWS analog lives in CloudWatch, not the security tooling. |
| **C07** CPU limits set | Container has a CPU limit | AWS Config: `ecs-task-definition-memory-hard-limit` (memory only — no equivalent for CPU) | ECS task definitions can't omit CPU at the *task* level (it's required), but containers within can. No managed Config rule covers this; would need a custom rule. |
| **C08** Memory limits set | Container has a memory limit | AWS Config: `ecs-task-definition-memory-hard-limit` | Direct match. |
| **C09** No privileged containers | `--privileged` flag | AWS Config: `ecs-containers-nonprivileged` | Direct match. CIS AWS Foundations Benchmark explicitly requires this. |
| **C10** Read-only root filesystem | Container rootfs is read-only | AWS Config: `ecs-containers-readonly-access` | Direct match. |
| **C11** No host network mode | Container shares host network | AWS Config: `ecs-task-definition-pid-mode-check`; manual review for `networkMode: host` in task definitions | Indirect. The closest managed rule covers PID mode, not network mode — you'd need a custom Config rule for the network case. |
| **C12** No Docker API on TCP 2375 | Unauthenticated daemon socket exposed | (no Docker analog in managed AWS) | When workloads run on ECS/EKS/Fargate, there's no exposed Docker daemon — AWS manages the runtime. The closest cloud concern is the EKS public API endpoint: AWS Config: `eks-endpoint-no-public-access`. |
| **C13** No host PID namespace | `--pid=host` flag | AWS Config: `ecs-task-definition-pid-mode-check` | Direct match. |
| **C14** Image age < 90 days | Build time on the image | Amazon Inspector (continuous CVE scanning of ECR images, replaces the age heuristic) | Inspector is strictly better here: instead of "is the image old?" it asks "does the image have known CVEs?" The local age check is a proxy — Inspector measures the actual signal. |
| **C15** Docker Content Trust enabled | `DOCKER_CONTENT_TRUST=1` | ECR Image Signing (AWS Signer + Notation), enforced via ECS Task Definition signature verification | The cloud equivalent is image signing at the registry level, validated at pull time. More robust than the env-var check because verification happens regardless of who's pulling. |

## Gaps and recommendation

### Where the local tool stays valuable

The local audit covers ground that the AWS services don't, or that they cover only partially:

- **Self-managed Docker hosts.** ECS, EKS, and Fargate replace the Docker daemon with AWS-managed equivalents. Anywhere you still run Docker yourself — a CI runner, a developer workstation, a legacy EC2 host with `docker run` — Config rules don't reach. The local audit does.
- **Pre-deployment validation.** Config rules evaluate resources *after* they're created. The local audit runs in CI before merge, catching misconfigured images and task definitions before they're deployed. The two are complementary, not redundant.
- **Air-gapped or hybrid environments.** On-prem Kubernetes clusters, edge devices, or air-gapped networks can't talk to AWS Config. Wherever your compliance posture has to be evaluated without an AWS control plane, the local tool is the only option.

### Where AWS services replace the local tool

Once a workload runs on ECS/EKS/Fargate against ECR, several local checks become redundant:

- **C09 (privileged), C10 (read-only rootfs), C13 (host PID), C08 (memory limits)** — covered exactly by managed Config rules. Drop the local versions for ECS workloads.
- **C12 (Docker API on 2375)** — impossible by construction in managed runtimes. The local check loses its target.
- **C14 (image age)** — superseded by Amazon Inspector's continuous CVE scanning. Age is a proxy for vulnerability; Inspector measures vulnerability directly.
- **C05 (plaintext secrets)** — replaced by Secrets Manager + the ECS `secrets` field. The local heuristic catches a class of mistake the AWS pattern eliminates entirely.

### Genuine gaps in the AWS coverage

Three areas where AWS-managed rules don't fully cover the local audit:

- **C07 (CPU limits)** — no managed Config rule. Would need a custom Lambda-backed rule to enforce.
- **C02 (healthchecks)** — handled at runtime by load balancers, not as a build-time requirement. No Config rule fits; closest practice is a tagging policy that requires every ECS service to be fronted by an ALB target group.
- **C11 (host network mode)** — `ecs-task-definition-pid-mode-check` covers PID, not network. Custom Config rule needed for `networkMode: host`.

### Recommendation

Treat the local tool as a **CI-time and self-managed-host control**, and AWS Config + Security Hub as the **production cloud control**. Specifically:

1. Run this audit in CI on every change to any Dockerfile or task definition. It catches issues at PR review time, before resources exist in AWS.
2. Run this audit on hourly schedule against any self-managed Docker host (CI runners, bastion hosts, on-prem nodes).
3. In AWS, enable the matching Config rules and forward findings to Security Hub. Build the security team's day-to-day dashboard there, not in the local tool.
4. For the three gaps (C07, C02, C11), either build custom Config rules or document an accepted risk. Don't pretend the AWS coverage is complete when it isn't.

The local tool and AWS services are not competitors. They cover different lifecycle stages — pre-deployment vs post-deployment — and different environments — self-managed vs AWS-managed. A mature compliance program runs both.