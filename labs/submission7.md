# Lab 7 — Container Security: Submission

**Image:** `bkimminich/juice-shop:v19.0.0`  
**Evidence:** `labs/lab7/scanning/`, `labs/lab7/hardening/`, `labs/lab7/analysis/`

---

## Task 1 — Image vulnerability and configuration analysis

### 1. Top 5 Critical / High vulnerabilities (Docker Scout)

Scout summary for this image: **11 Critical, 65 High, 30 Medium, 5 Low** (see `labs/lab7/scanning/scout-cves.txt`).

| # | CVE / ID | Package | Severity | Impact (short) |
|---|----------|---------|----------|----------------|
| 1 | CVE-2023-37466 / CVE-2023-37903 / CVE-2026-22709 (examples) | **vm2** 3.9.17 (npm) | Critical | Sandbox escape / code or command execution where untrusted code is evaluated — full compromise of the Node process. |
| 2 | CVE-2025-55130 (+ related Node CVEs) | **Node.js** 22.18.0 (runtime) | Critical / High | Unpatched runtime: memory-safety / V8-class issues affecting confidentiality, integrity, availability. |
| 3 | CVE-2019-10744 | **lodash** 2.4.2 (npm) | Critical | Prototype pollution → logic bypass and RCE chains with other gadgets. |
| 4 | CVE-2023-46233 / CVE-2015-9235 (jwt stack) | **jsonwebtoken** / related deps | Critical / High | Weak crypto or validation → token forgery / auth bypass. |
| 5 | Multiple High (path traversal / ReDoS families) | Various **npm** dependencies | High | Path traversal → arbitrary file read; ReDoS → CPU exhaustion (DoS). |

**Remediation themes:** upgrade Node to a patched 22.x line; remove or replace `vm2`; bump lodash and JWT-related packages; rebuild after `npm audit fix` / dependency upgrades.

### 2. Dockle configuration findings

From `labs/lab7/scanning/dockle-results.txt`:

- **FATAL:** none reported for this image.
- **WARN:** none reported for this image.

**INFO (still worth fixing):**

| Code | Finding | Why it matters |
|------|---------|----------------|
| CIS-DI-0005 | Content trust not used for pull/build | Without DCT, registry compromise or MITM could substitute a malicious image. |
| CIS-DI-0006 | No `HEALTHCHECK` in image | No automatic unhealthy-instance detection for orchestrators. |
| DKL-LI-0003 | Unnecessary files (e.g. `.DS_Store` under `node_modules`) | Bloat and metadata leakage; tighten `.dockerignore` and multi-stage builds. |

### 3. Security posture assessment

- **Runs as root?** **No.** Image `User: 65532` (dedicated non-root UID).
- **Recommendations:** patch dependencies; add `HEALTHCHECK`; verify image digests in CI; use capability drops, limits, and seccomp in production (Task 3).

### Snyk — access blocked; Trivy and Grype as comparison scanners

**Snyk:** The site `https://snyk.io` returns **Access Denied** (Akamai / CDN, reference id in browser). VPN and DNS changes did not help — likely regional or provider filtering. A full Snyk CLI run was therefore not possible.

**Substitute tools (lab goal: second opinion vs Scout):**

| Scanner | Command / artifact | Role |
|---------|-------------------|------|
| **Trivy** | `labs/lab7/scanning/trivy-results.txt` | HIGH+CRITICAL image scan; Debian base + per-`package.json` targets; also flagged **embedded RSA test keys** in Juice Shop sources (expected for this app). |
| **Grype** | `labs/lab7/scanning/grype-results.txt` | Image SBOM-style scan; many **Critical/High** npm, deb, and **Node binary** findings; EPSS column helps prioritize. |

**Scout vs Trivy vs Grype (high level):**

- **Overlap:** All three highlight **vm2**, **lodash@2.4.2**, **jsonwebtoken** / JWT ecosystem, **Node 22.18.0** CVEs, and risky npm transitive deps (e.g. **tar**, **multer**, **minimatch**).
- **Differences:** Trivy splits results per manifest path and runs secret scanning; Grype merges EPSS/risk scoring; Scout integrates with Docker Hub and shows fix versions per package. Counts differ because of deduplication, severity sources, and which layers/files each scanner attributes to a “target.”
- **Action:** Treat findings as a **set** — triage by exploitability in your deployment, not by the highest headline count from a single vendor.

---

## Task 2 — Docker host security benchmarking (CIS Docker Benchmark)

### How the audit was run

The official `docker/docker-bench-security` **container image** bundles **Docker CLI 18.06**, which cannot speak to **Engine 29.x** (API mismatch).  

**Working setup:** custom image `lab7-bench-runner` (`labs/lab7/hardening/Dockerfile.bench-runner`: Alpine + `bash` + `docker-cli` 26.x) + upstream scripts from `docker/docker-bench-security` mounted at `/opt/bench`, with **LF** line endings (Windows CRLF breaks the shell scripts). See `labs/lab7/hardening/README-bench.md`.

Full log: `labs/lab7/hardening/docker-bench-results.txt`.

### Summary statistics (this run)

Counted from the log (CIS Docker Bench v1.6.0 style — scored problems appear as **[WARN]**, not **[FAIL]**):

| Result | Count |
|--------|------:|
| **PASS** | 34 |
| **WARN** | 63 |
| **FAIL** | 0 (not used in this script output) |
| **NOTE** | 11 |
| **INFO** | many (section headers, N/A checks, file-not-found on Docker Desktop paths) |

Footer in log: **Checks: 117**, **Score: 0** (bench scoring formula; low score is common on dev/Desktop setups).

### Analysis of WARNs (representative)

**Host / daemon hardening**

- **1.1.3–1.1.5 (auditd):** No audit rules for Docker paths — weaker **forensics** after incident; add `auditd` rules per CIS for `/var/lib/docker`, daemon, etc.
- **2.2:** Unrestricted **container-to-container** traffic on default bridge — lateral movement; use custom networks, firewall, or Kubernetes network policies.
- **2.9:** **User namespaces** not enabled — larger blast radius if container boundary fails; enable rootless / userns-remap where supported.
- **2.12 / 2.13:** No **auth plugin** / **remote logging** — weak multi-tenant control and log centralization.
- **2.14:** Daemon not enforcing **no-new-privileges** globally — rely on per-container flags (as in Task 3) or `daemon.json`.
- **2.15 / 2.16:** **Live restore** off; **userland proxy** on — trade-offs for availability vs attack surface; tune for production Linux servers.

**Docker Desktop–specific**

- **3.x “File not found”** for `docker.service`, `/etc/docker`, etc. — expected on Desktop VM layout; not comparable 1:1 to bare-metal Linux CIS hardening.

**Images (4.x)**

- **4.5–4.6:** No **DCT** / **HEALTHCHECK** on many local images (including security tools and Juice Shop) — supply-chain and operability gaps.

**Runtime (5.x) — includes self-scan artifact**

Many **5.x** WARNs reference container **`competent_fermi`** — that was the **bench runner itself** (`--net host`, `--pid host`, `CAP_AUDIT_CONTROL`, **docker.sock** mounted). Those WARNs illustrate why the audit container is privileged; they are **not** judgments on your Juice Shop workloads. For production services, apply memory/CPU/PID limits, avoid host network/PID, do not mount the socket, use **read-only rootfs** where possible, and set **health checks**.

---

## Task 3 — Deployment security configuration analysis

### Environment notes

- **Docker Desktop (Windows):** `docker run ... --security-opt=seccomp=default` fails because the Windows CLI treats `default` as a **missing file path**.  
- **Workaround (equivalent to Linux `seccomp=default`):** Moby’s `default.json` is stored at `labs/lab7/analysis/seccomp-default.json` (from `moby/moby` v27.5.1). Production profile uses:

  `--security-opt seccomp=C:/Users/Ivenho/DevSecOps/DevSecOps-Intro/labs/lab7/analysis/seccomp-default.json`

  On native Linux you can keep **`--security-opt seccomp=default`** or point to the same JSON file.

- **CPU:** `--cpus=1.0` → **NanoCpus: 1000000000** in `docker inspect`.

### 1. Configuration comparison table

| Profile | Cap drop | Cap add | Security options | Memory limit | CPU | PIDs limit | Restart |
|---------|----------|---------|------------------|--------------|-----|------------|---------|
| **Default** | — | — | — | none (host pool) | unlimited | none | `no` |
| **Hardened** | `ALL` | — | `no-new-privileges` | 512 MiB | 1 CPU | none | `no` |
| **Production** | `ALL` | `NET_BIND_SERVICE` | `no-new-privileges` + **seccomp** (Moby default profile) | 512 MiB; swap capped 512 MiB | 1 CPU | 100 | `on-failure` (max 3) |

**Functional check** (`labs/lab7/analysis/deployment-comparison.txt`): HTTP **200** on ports 3001–3003.

### 2. Security measure analysis

**(a) `--cap-drop=ALL` / `--cap-add=NET_BIND_SERVICE`:** Linux **capabilities** split root privileges. Dropping all reduces kernel attack surface after compromise. `NET_BIND_SERVICE` is for ports &lt; 1024; Juice Shop uses **3000**, so the add is often unnecessary but illustrates least-privilege tuning.

**(b) `--security-opt=no-new-privileges`:** Sets `no_new_privs`, blocking many **setuid**-based escalations inside the container. Can break rare images that rely on setuid.

**(c) `--memory` / `--cpus`:** Prevents **noisy neighbor** and **resource exhaustion** DoS; too low limits hurt availability.

**(d) `--pids-limit`:** Mitigates **fork bombs**; set from baseline + margin.

**(e) `--restart=on-failure:3`:** Restarts only on failure, capped — avoids infinite flapping; **`always`** also restarts clean exits (different ops trade-off).

### 3. Critical thinking

1. **Development:** **Default** or **Hardened** without aggressive swap/PID caps — fastest iteration.  
2. **Production:** **Production** profile + orchestrator policies (TLS ingress, secrets, network policy).  
3. **Resource limits:** Fair sharing, predictable capacity, containment of leaks and DoS.  
4. **Default vs production if exploited:** Production removes default capabilities, blocks new privileges, enforces cgroup limits, and applies **seccomp** — blocking many syscalls needed for container breakout tooling; default leaves the standard capability set and no cgroup fence.  
5. **More hardening:** read-only rootfs + tmpfs writes, AppArmor/SELinux, rootless, digest-pinned images, egress restrictions, centralized logging.

---

## References

- Scout: `labs/lab7/scanning/scout-cves.txt`
- Dockle: `labs/lab7/scanning/dockle-results.txt`
- Trivy: `labs/lab7/scanning/trivy-results.txt`
- Grype: `labs/lab7/scanning/grype-results.txt`
- CIS bench log: `labs/lab7/hardening/docker-bench-results.txt`
- Bench how-to: `labs/lab7/hardening/README-bench.md`
- Deployment comparison: `labs/lab7/analysis/deployment-comparison.txt`
- Seccomp profile file: `labs/lab7/analysis/seccomp-default.json`
- Host info: `labs/lab7/hardening/docker-info.txt`
