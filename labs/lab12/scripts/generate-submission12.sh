#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../.. && pwd)"
cd "$ROOT_DIR"

f() {
  local p="$1"
  if [[ -f "$p" ]]; then
    cat "$p"
  else
    echo "<missing: $p>"
  fi
}

host_uname="$(uname -a 2>/dev/null || true)"
virt_count="$(egrep -c '(vmx|svm)' /proc/cpuinfo 2>/dev/null || true)"
containerd_ver="$(cat labs/lab12/setup/containerd-version.txt 2>/dev/null || containerd --version 2>/dev/null || true)"
nerdctl_ver="$(cat labs/lab12/setup/nerdctl-version.txt 2>/dev/null || nerdctl --version 2>/dev/null || true)"

cat > labs/submission12.md <<EOF
# Submission 12 — Kata Containers: VM-backed Container Sandboxing

> Repo: \`DevSecOps-Intro\`  
> Lab: \`labs/lab12.md\`

## Environment

- **Host OS / kernel**: \`${host_uname}\`
- **CPU virtualization flags count**: \`${virt_count}\`
- **containerd**: \`${containerd_ver}\`
- **nerdctl**: \`${nerdctl_ver}\`

---

## Task 1 — Install and Configure Kata (2 pts)

### Shim version

\`\`\`text
$(f labs/lab12/setup/kata-built-version.txt)
\`\`\`

### Kata test run

\`\`\`text
$(f labs/lab12/setup/kata-test-uname.txt)
\`\`\`

---

## Task 2 — Run and Compare Containers (runc vs kata) (3 pts)

### Juice Shop (runc) health check

\`\`\`text
$(f labs/lab12/runc/health.txt)
\`\`\`

### Kata container evidence

\`\`\`text
$(f labs/lab12/kata/test1.txt)
$(f labs/lab12/kata/kernel.txt)
$(f labs/lab12/kata/cpu.txt)
\`\`\`

### Kernel comparison

\`\`\`text
$(f labs/lab12/analysis/kernel-comparison.txt)
\`\`\`

### CPU comparison

\`\`\`text
$(f labs/lab12/analysis/cpu-comparison.txt)
\`\`\`

### Isolation implications (brief)

- **runc**: uses the **host kernel**; isolation is namespaces/cgroups/seccomp/LSM. Kernel escape can become a **host compromise boundary**.
- **Kata**: workload runs in a **VM with its own guest kernel**; escape typically needs a **guest + hypervisor boundary** break for host impact.

---

## Task 3 — Isolation Tests (3 pts)

### dmesg (guest kernel evidence)

\`\`\`text
$(f labs/lab12/isolation/dmesg.txt)
\`\`\`

### /proc visibility

\`\`\`text
$(f labs/lab12/isolation/proc.txt)
\`\`\`

### Network interfaces (Kata VM)

\`\`\`text
$(f labs/lab12/isolation/network.txt)
\`\`\`

### Kernel modules count (host vs guest)

\`\`\`text
$(f labs/lab12/isolation/modules.txt)
\`\`\`

### Security interpretation

- **Container escape in runc**: same kernel boundary → higher blast radius if attacker reaches kernel context.
- **Container escape in Kata**: usually compromises guest VM first → needs **second-stage** hypervisor/host escape for host impact.

---

## Task 4 — Performance Comparison (2 pts)

### Startup time (runc vs Kata)

\`\`\`text
$(f labs/lab12/bench/startup.txt)
\`\`\`

### HTTP latency baseline (Juice Shop under runc)

\`\`\`text
$(f labs/lab12/bench/http-latency.txt)
\`\`\`

### Recommendations

- **Use runc when**: fastest startup, simplest ops, low overhead, trusted workloads or strong kernel hardening.
- **Use Kata when**: multi-tenant/untrusted workloads, need stronger isolation boundary than namespaces.

EOF

echo "Wrote labs/submission12.md"

