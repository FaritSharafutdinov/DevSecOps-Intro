# Labs 7 Submission - Container Security Analysis

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


## Task 2: Docker Host Security Benchmarking

### Summary Statistics
- Total PASS: 34
- Total WARN: 63
- Total FAIL: 0
- Total INFO: 20

### Analysis of Failures/Warnings
The benchmark results show `competent_fermi` (the runner container) flagging multiple warnings. This is expected as the runner requires high privileges (mounting the docker socket, host network, etc.) to perform the audit itself. 

Key warnings relate to:
- **Host auditing**: Configuration missing for Docker files.
- **Daemon configuration**: Lack of user namespace support and missing authorization plugins.
- **Container runtime**: Running as root, sharing PID/network namespaces, and lack of resource limits in the runner container.

These warnings should be addressed for production workloads by using dedicated audit tools, non-root daemons, and strict container runtime security profiles.

## Task 3: Deployment Security Configuration Analysis

### Configuration Comparison Table

| Feature | Default | Hardened | Production |
| :--- | :--- | :--- | :--- |
| **Capabilities** | All | NONE | NET_BIND_SERVICE |
| **SecurityOpt** | None | no-new-privileges | no-new-privileges, seccomp=default |
| **Memory** | Unlimited | 512m | 512m |
| **CPUs** | Unlimited | 1.0 | 1.0 |
| **Restart** | No | No | on-failure:3 |

### Security Measure Analysis

**a) Capabilities (`--cap-drop=ALL` / `--cap-add=NET_BIND_SERVICE`)**
- **Linux Capabilities**: Subdivide root power into smaller, distinct privileges.
- **Attack Vector**: Dropping `ALL` prevents many privilege escalation attacks (e.g., `CAP_SYS_ADMIN`).
- **NET_BIND_SERVICE**: Needed to bind to ports < 1024.
- **Trade-off**: Improved security vs. potential application breakage if the app requires more privileges.

**b) `--security-opt=no-new-privileges`**
- **Function**: Prevents the process (and its children) from gaining new privileges via `setuid` or `setgid` binaries.
- **Attack Prevention**: Effectively stops many privilege escalation exploits.
- **Downsides**: Rarely breaks legitimate application functionality.

**c) Resource Limits (`--memory=512m`, `--cpus=1.0`)**
- **No Limits**: Risk of resource exhaustion (DoS) affecting the host or other containers.
- **Benefits**: Prevents memory leaks or high CPU usage from impacting the host.
- **Risk**: Too low limits can cause application crashes (OOM kills).

**d) `--pids-limit=100`**
- **Fork Bomb**: An attack where a process spawns unlimited children to crash the system.
- **Benefit**: Restricts the number of processes a container can start.
- **Determination**: Monitor the application baseline and set the limit slightly above peak usage.

**e) `--restart=on-failure:3`**
- **Policy**: Restarts the container only if it crashes (exits with non-zero status), up to 3 times.
- **Benefits**: Provides resiliency without infinitely restarting broken containers.
- **Risks**: Masks underlying issues; `always` might be better for core services.

### Critical Thinking Questions

1. **Development**: Default profile for ease of debugging/development.
2. **Production**: Production profile to enforce security-by-default and resource isolation.
3. **Real-world Problem**: Resource limits prevent "noisy neighbor" scenarios and DoS attacks.
4. **Attacker Action**: In Production, an attacker can't use `setuid` binaries (due to `no-new-privileges`), has no extra capabilities (if limited), and cannot exhaust system resources.
5. **Additional Hardening**: Implement read-only root filesystems, drop `NET_RAW`, and use AppArmor/SELinux profiles.
