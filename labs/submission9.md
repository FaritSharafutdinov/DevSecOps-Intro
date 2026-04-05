Markdown
# Lab 9 Submission: Monitoring & Compliance

**Student:** Farit Sharafutdinov  


---

## Task 1 — Runtime Security Detection with Falco

### 1.1 Baseline Alerts
After launching Falco with the modern eBPF probe, I triggered a standard security event by spawning an interactive shell inside the helper container. Falco successfully detected this activity using its default ruleset.

**Evidence (Standard Rule Alert):**
```json
{
  "hostname": "099a36eca72c",
  "priority": "Notice",
  "rule": "Terminal shell in container",
  "output": "2026-04-05T18:50:32.278392750+0000: Notice A shell was spawned in a container with an attached terminal | user=root container_name=lab9-helper command=sh -c echo hello",
  "source": "syscall",
  "tags": ["T1059", "container", "maturity_stable", "mitre_execution", "shell"]
}
```
1.2 Custom Rule: Write Binary Under UsrLocalBin
To detect potential "Container Drift" and persistence attempts, I implemented a custom rule in labs/lab9/falco/rules/custom-rules.yaml. This rule monitors any write operations directed at common binary directories.

Rule Configuration:

```AML
- rule: Write Binary Under UsrLocalBin
  desc: Detects writes under /usr/local/bin inside any container
  condition: >
    evt.type in (open, openat, openat2, creat) and 
    evt.is_open_write=true and 
    fd.name startswith /usr/local/bin/ and 
    container.id != host
  output: "Falco Custom: File write in /usr/local/bin (container=%container.name user=%user.name file=%fd.name flags=%evt.arg.flags)"
  priority: WARNING
  tags: [container, compliance, drift]
```
Evidence (Custom Rule Trigger):

```JSON
{
  "hostname": "099a36eca72c",
  "priority": "Warning",
  "rule": "Write Binary Under UsrLocalBin",
  "output": "2026-04-05T18:57:24.037379306+0000: Warning Falco Custom: File write in /usr/local/bin (container=lab9-helper user=root file=/usr/local/bin/final_check.txt flags=O_LARGEFILE|O_TRUNC|O_CREAT|O_WRONLY|FD_UPPER_LAYER)",
  "output_fields": {
    "container.name": "lab9-helper",
    "fd.name": "/usr/local/bin/final_check.txt",
    "user.name": "root"
  },
  "time": "2026-04-05T18:57:24.037379306Z"
}
```
Task 2 — Policy-as-Code with Conftest
2.1 Static Analysis Results
I used conftest to evaluate two Kubernetes manifests against security policies. The "unhardened" manifest represents a high-risk configuration, while the "hardened" version implements industry best practices.

Analysis of juice-unhardened.yaml:

```Plaintext
FAIL - /project/manifests/k8s/juice-unhardened.yaml - k8s.security - container "juice" missing resources.limits.cpu
FAIL - /project/manifests/k8s/juice-unhardened.yaml - k8s.security - container "juice" missing resources.limits.memory
FAIL - /project/manifests/k8s/juice-unhardened.yaml - k8s.security - container "juice" must set allowPrivilegeEscalation: false
FAIL - /project/manifests/k8s/juice-unhardened.yaml - k8s.security - container "juice" must set readOnlyRootFilesystem: true
FAIL - /project/manifests/k8s/juice-unhardened.yaml - k8s.security - container "juice" must set runAsNonRoot: true
FAIL - /project/manifests/k8s/juice-unhardened.yaml - k8s.security - container "juice" uses disallowed :latest tag
Summary: 30 tests, 20 passed, 2 warnings, 8 failures
```
Analysis of juice-hardened.yaml:

```Plaintext
Summary: 30 tests, 30 passed, 0 warnings, 0 failures
```
2.2 Hardening Analysis

The following security controls were validated in the hardened manifest:

### Immutable Root FS: Setting readOnlyRootFilesystem: true prevents attackers from installing malware or modifying binaries (mitigating the "drift" detected by Falco in Task 1).

### Resource Constraints: Defining CPU/Memory limits and requests ensures cluster stability and prevents resource exhaustion (DoS) by a single compromised or faulty container.

### Predictable Deployments: Avoiding the :latest tag ensures that the exact, scanned version of an image is deployed, preventing "poisoned" updates.

## Conclusion
This lab demonstrates the necessity of a "Defense in Depth" strategy. While Conftest acts as a proactive gatekeeper by enforcing security standards during the CI/CD phase (Static Analysis), Falco provides essential reactive visibility by detecting suspicious behavior in real-time (Dynamic Analysis).
