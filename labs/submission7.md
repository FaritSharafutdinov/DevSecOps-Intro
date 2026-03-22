# Lab 7 — Container Security: Submission

**Image:** `bkimminich/juice-shop:v19.0.0`  
**Evidence:** `labs/lab7/scanning/`, `labs/lab7/hardening/`, `labs/lab7/analysis/`

---

## Task 1 — Image vulnerability and configuration analysis

### 1. Top 5 Critical / High vulnerabilities (Docker Scout)

Scout summary for this image: **11 Critical, 65 High, 30 Medium, 5 Low** (see `labs/lab7/scanning/scout-cves.txt`).

| # | CVE / ID | Package | Severity | Impact (short) |
|---|----------|---------|----------|----------------|
| 1 | CVE-2023-37466 / CVE-2023-37903 / CVE-2026-22709 (examples) | **vm2** 3.9.17 (npm) | Critical | Sandbox escape / code or command execution in contexts where untrusted code is evaluated — full compromise of the Node process. |
| 2 | CVE-2025-55130 (+ related) | **Node.js** 22.18.0 (runtime) | Critical / High | Security fixes in the JS runtime; unpatched versions may allow memory safety or V8-level issues affecting confidentiality, integrity, availability. |
| 3 | CVE-2019-10744 | **lodash** 2.4.2 (npm) | Critical | Prototype pollution can alter object prototypes app-wide → logic bypass, RCE chains with other gadgets. |
| 4 | CVE-2023-46233 / CVE-2021-44906 (transitive jwt/jsonwebtoken chain) | **jsonwebtoken** / related deps | Critical / High | Weak crypto or validation flaws can break token integrity → auth bypass or token forgery. |
| 5 | Multiple High (path traversal / ReDoS families) | Various **npm** dependencies | High | Path traversal → arbitrary file read; ReDoS → CPU exhaustion (DoS). |

**Remediation themes:** upgrade Node to a patched 22.x line; remove or replace `vm2` (deprecated; avoid unsafe eval patterns); bump lodash and JWT-related packages; rebuild the image after `npm audit fix` / dependency upgrades.

### 2. Dockle configuration findings

From `labs/lab7/scanning/dockle-results.txt`:

- **FATAL:** none reported for this image.
- **WARN:** none reported for this image.

**INFO (still worth fixing for hygiene and trust):**

| Code | Finding | Why it matters |
|------|---------|----------------|
| CIS-DI-0005 | Content trust not used for pull/build | Without DCT, a registry compromise or MITM could substitute a malicious image; signing improves supply-chain assurance. |
| CIS-DI-0006 | No `HEALTHCHECK` in image | Orchestrators and operators cannot automatically detect unhealthy instances; slows incident response and rolling updates. |
| DKL-LI-0003 | Unnecessary files (e.g. `.DS_Store` under `node_modules`) | Bloat and accidental leakage of environment metadata; keep images minimal (multi-stage builds, `.dockerignore`). |

**SKIP:** DKL-LI-0001 (shadow files not detected in this image layout) — informational.

### 3. Security posture assessment

- **Runs as root?** **No.** `docker inspect` shows `User: 65532` for the image — a dedicated non-root UID (good practice).
- **Recommendations:** (1) address Scout findings via base image and dependency updates; (2) add `HEALTHCHECK`; (3) enable image signing / verify digests in CI; (4) continue non-root default and read-only rootfs where the app allows it; (5) run production with dropped capabilities, limits, and seccomp where the platform supports it (see Task 3).

### Snyk comparison

Snyk was **not** executed with a valid `SNYK_TOKEN` in this workspace. See `labs/lab7/scanning/snyk-results-note.txt` for the exact command. Expect overlap with Scout on npm and Node CVEs, with possible differences in severity scoring and reachability.

---

## Task 2 — Docker host security benchmarking (CIS Docker Benchmark)

### Intended command

As in the lab (mount host paths and Docker socket, run `docker/docker-bench-security`).

### What happened here

`docker/docker-bench-security` **failed immediately** with: *Error connecting to docker daemon*.

**Cause:** the image ships **Docker CLI 18.06.1-ce** (API 1.38). The local engine is **29.2.0** (API 1.53). The client is too old to talk to the daemon. Details: `labs/lab7/hardening/docker-bench-results.txt`.

### Summary statistics (PASS / WARN / FAIL / INFO)

**Not available** from an automated run on this host. To satisfy the rubric, re-run on a Linux host with a compatible client or an updated bench image, then paste the script’s totals here.

### Failures and remediation (template)

After a successful run, for each `[FAIL]`:

1. Record the CIS check ID and description from the bench output.
2. **Impact:** e.g. weaker container isolation, excessive daemon privileges, insecure registry settings.
3. **Remediation:** concrete `daemon.json`, systemd override, or operational change (with docs link to CIS Docker Benchmark).

**Host hints from `docker info`** (`labs/lab7/hardening/docker-info.txt`): seccomp **builtin** profile and **cgroupns** are enabled; Docker Desktop / WSL2 — many checks differ from a bare-metal Linux server.

---

## Task 3 — Deployment security configuration analysis

### Environment notes

- **Docker Desktop (Windows):** `juice-production` could not use `--security-opt=seccomp=default` (profile path error). The container was started with the same flags **except** `seccomp=default`. On native Linux, apply the lab’s full command.
- **CPU limit:** `--cpus=1.0` is reflected as **NanoCpus: 1000000000** in `docker inspect` (not always visible as `CpuQuota` in the format string).

### 1. Configuration comparison table

| Profile | Cap drop | Cap add | Security options | Memory limit | CPU | PIDs limit | Restart |
|---------|----------|---------|------------------|--------------|-----|------------|---------|
| **Default** | — | — | — | none (host default) | unlimited | none | `no` |
| **Hardened** | `ALL` | — | `no-new-privileges` | 512 MiB | 1 CPU | none | `no` |
| **Production** (as run here) | `ALL` | `NET_BIND_SERVICE` | `no-new-privileges` | 512 MiB (+ swap capped 512 MiB) | 1 CPU | 100 | `on-failure` (max 3) |
| **Production** (lab target on Linux) | same | same | add **`seccomp=default`** | same | same | same | same |

**Functional check** (`labs/lab7/analysis/deployment-comparison.txt`): HTTP **200** on ports 3001–3003.

**Resource usage:** hardened/production respect **512 MiB** cap; default uses host memory pool (see same file).

### 2. Security measure analysis

**a) `--cap-drop=ALL` and `--cap-add=NET_BIND_SERVICE`**

- **Linux capabilities** split traditional root power into fine-grained privileges (see `capabilities(7)`).
- **Dropping ALL** removes ability to perform privileged operations (mounts, raw sockets, `CAP_SYS_ADMIN`, etc.), shrinking kernel attack surface if the container is compromised.
- **NET_BIND_SERVICE** allows binding to ports **&lt; 1024** as non-root; Juice Shop listens on **3000**, so it is often unnecessary here but is a common pattern for services on 80/443.
- **Trade-off:** if the app truly needs another capability, you must add it explicitly — each add increases risk.

**b) `--security-opt=no-new-privileges`**

- Sets `no_new_privs` so processes cannot gain privileges via `setuid` binaries or file capabilities after exec.
- Mitigates **privilege escalation** after initial code execution inside the container.
- **Downside:** breaks legitimate flows that rely on setuid elevation inside the container (rare for typical web apps).

**c) `--memory=512m` and `--cpus=1.0`**

- Without limits, one container can **starve** others or the host (**noisy neighbor**), and memory exhaustion can trigger OOM affecting other workloads.
- Limits mitigate **resource exhaustion** (DoS or buggy leaks).
- **Too low** limits cause OOM kills or throttling and **availability** issues — tune from metrics.

**d) `--pids-limit=100`**

- A **fork bomb** spawns processes exponentially until PID space is exhausted.
- PID caps bound process count per container.
- **Choosing a limit:** baseline from normal `pids` usage under load, then margin; Juice Shop should need far fewer than 100 under normal traffic.

**e) `--restart=on-failure:3`**

- Restarts the container only **on failure**, at most **3** times (then stops — avoids infinite restart loops).
- **Beneficial** for transient crashes; **risky** if failures are rapid (flapping) or mask persistent compromise.
- **`always`** restarts even after clean exit — good for daemons, bad if you need a failed container to **stay down** for investigation.

### 3. Critical thinking

1. **Development:** **Default** (or hardened without aggressive swap/pid limits) — fastest feedback, fewer surprises when debugging; still use non-root image as provided.
2. **Production:** **Production** profile (full lab flags on Linux, including **seccomp**) plus orchestrator policies (network policy, secrets, ingress TLS).
3. **Resource limits** solve **fair sharing**, **predictable capacity**, and **containment** of DoS or memory leaks.
4. **Default vs production if exploited:** production removes **Linux capabilities**, blocks **new privileges**, restricts **memory/CPU/PIDs**, and (with seccomp) **syscalls** — blocking many post-exploitation paths (e.g. mounting, loading kernel modules from user space is not applicable in-container, but many escalation gadgets require capabilities or syscalls). Default leaves full default capability set and no cgroup resource fence.
5. **Additional hardening:** read-only root filesystem where possible, tmpfs for writable dirs, user namespaces / rootless Docker, AppArmor/SELinux profiles, image digest pinning, network egress restrictions, centralized logging, and admission control in Kubernetes.

---

## References

- Docker Scout output: `labs/lab7/scanning/scout-cves.txt`
- Dockle: `labs/lab7/scanning/dockle-results.txt`
- Deployment comparison: `labs/lab7/analysis/deployment-comparison.txt`
- Host info: `labs/lab7/hardening/docker-info.txt`
