# Submission 12 — Kata Containers: VM-backed Container Sandboxing

> Repo: `DevSecOps-Intro`  
> Lab: `labs/lab12.md`  
> Branch: `feature/lab12`  

## Environment

- **Host OS**: _(e.g., Ubuntu 24.04 / Debian 12 / WSL2 Ubuntu 24.04)_  
- **CPU virtualization**: `egrep -c '(vmx|svm)' /proc/cpuinfo` = `___`  
- **containerd**: `containerd --version` = `___`  
- **nerdctl**: `sudo nerdctl --version` = `___`  

Working dirs created:

```bash
mkdir -p labs/lab12/{setup,runc,kata,isolation,bench,analysis}
```

---

## Task 1 — Install and Configure Kata (2 pts)

### 1.1 Build Kata shim (runtime-rs)

Commands:

```bash
bash labs/lab12/setup/build-kata-runtime.sh
sudo install -m 0755 labs/lab12/setup/kata-out/containerd-shim-kata-v2 /usr/local/bin/
command -v containerd-shim-kata-v2
containerd-shim-kata-v2 --version | tee labs/lab12/setup/kata-built-version.txt
```

Evidence (paste output):

```text
<containerd-shim-kata-v2 --version output>
```

### 1.2 Install Kata guest assets + default config

Commands:

```bash
sudo bash labs/lab12/scripts/install-kata-assets.sh
ls -la /etc/kata-containers/runtime-rs/configuration.toml
readlink -f /etc/kata-containers/runtime-rs/configuration.toml
```

Evidence (paste output):

```text
<ls/readlink outputs>
```

### 1.3 Configure containerd runtime `io.containerd.kata.v2`

Commands:

```bash
sudo bash labs/lab12/scripts/configure-containerd-kata.sh
sudo systemctl restart containerd
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 uname -a
```

Evidence (paste output):

```text
<uname -a from inside kata container>
```

---

## Task 2 — Run and Compare Containers (runc vs kata) (3 pts)

### 2.1 Run Juice Shop under runc (default)

Commands:

```bash
sudo nerdctl run -d --name juice-runc -p 3012:3000 bkimminich/juice-shop:v19.0.0
sleep 10
curl -s -o /dev/null -w "juice-runc: HTTP %{http_code}\n" http://localhost:3012 | tee labs/lab12/runc/health.txt
```

Evidence (paste file content `labs/lab12/runc/health.txt`):

```text
juice-runc: HTTP ___
```

Cleanup (after tests):

```bash
sudo nerdctl rm -f juice-runc || true
```

### 2.2 Kata short-lived containers (Alpine)

Commands:

```bash
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 uname -a | tee labs/lab12/kata/test1.txt
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 uname -r | tee labs/lab12/kata/kernel.txt
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 sh -c "grep 'model name' /proc/cpuinfo | head -1" | tee labs/lab12/kata/cpu.txt
```

Evidence (paste outputs):

```text
<test1.txt>
<kernel.txt>
<cpu.txt>
```

### 2.3 Kernel comparison (host vs kata guest)

Commands:

```bash
echo "=== Kernel Version Comparison ===" | tee labs/lab12/analysis/kernel-comparison.txt
echo -n "Host kernel (runc uses this): " | tee -a labs/lab12/analysis/kernel-comparison.txt
uname -r | tee -a labs/lab12/analysis/kernel-comparison.txt
echo -n "Kata guest kernel: " | tee -a labs/lab12/analysis/kernel-comparison.txt
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 cat /proc/version | tee -a labs/lab12/analysis/kernel-comparison.txt
```

Key observation:

- **runc** uses the **host kernel** (same as `uname -r` on the host).
- **Kata** uses a **separate guest kernel** (kernel string differs; often a Kata-provided kernel).

### 2.4 CPU model comparison (real vs virtualized)

Commands:

```bash
echo "=== CPU Model Comparison ===" | tee labs/lab12/analysis/cpu-comparison.txt
echo "Host CPU:" | tee -a labs/lab12/analysis/cpu-comparison.txt
grep "model name" /proc/cpuinfo | head -1 | tee -a labs/lab12/analysis/cpu-comparison.txt
echo "Kata VM CPU:" | tee -a labs/lab12/analysis/cpu-comparison.txt
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 sh -c "grep 'model name' /proc/cpuinfo | head -1" | tee -a labs/lab12/analysis/cpu-comparison.txt
```

Key observation:

- **runc** reports the **real host CPU**.
- **Kata** typically reports a **virtual CPU model** (QEMU/virtio / hypervisor-present), indicating execution inside a VM.

### Isolation implications (analysis)

- **runc**:
  - Shares the **same kernel** with the host; isolation is primarily **namespaces + cgroups + seccomp/AppArmor/SELinux**.
  - Kernel bugs / misconfig can make “container escape” a **host compromise boundary** (same kernel).
- **Kata**:
  - Adds a **hardware virtualization boundary**: container workload runs in a lightweight VM with its own kernel.
  - A breakout must usually cross the **guest kernel + hypervisor boundary** to reach the host.

---

## Task 3 — Isolation Tests (3 pts)

### 3.1 `dmesg` access

Commands:

```bash
echo "=== dmesg Access Test ===" | tee labs/lab12/isolation/dmesg.txt
echo "Kata VM (separate kernel boot logs):" | tee -a labs/lab12/isolation/dmesg.txt
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 dmesg 2>&1 | head -5 | tee -a labs/lab12/isolation/dmesg.txt
```

Evidence (paste first lines):

```text
<dmesg output>
```

Interpretation:

- Seeing VM/guest boot logs strongly suggests the container is running in a **separate kernel** (Kata VM).

### 3.2 `/proc` visibility

Commands:

```bash
echo "=== /proc Entries Count ===" | tee labs/lab12/isolation/proc.txt
echo -n "Host: " | tee -a labs/lab12/isolation/proc.txt
ls /proc | wc -l | tee -a labs/lab12/isolation/proc.txt
echo -n "Kata VM: " | tee -a labs/lab12/isolation/proc.txt
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 sh -c "ls /proc | wc -l" | tee -a labs/lab12/isolation/proc.txt
```

Observation notes:

- Counts and visible proc entries can differ; Kata shows the guest’s `/proc` view inside the VM.

### 3.3 Network interfaces inside Kata VM

Commands:

```bash
echo "=== Network Interfaces ===" | tee labs/lab12/isolation/network.txt
echo "Kata VM network:" | tee -a labs/lab12/isolation/network.txt
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 ip addr | tee -a labs/lab12/isolation/network.txt
```

Evidence (paste excerpt):

```text
<ip addr output>
```

### 3.4 Kernel modules (host vs guest)

Commands:

```bash
echo "=== Kernel Modules Count ===" | tee labs/lab12/isolation/modules.txt
echo -n "Host kernel modules: " | tee -a labs/lab12/isolation/modules.txt
ls /sys/module | wc -l | tee -a labs/lab12/isolation/modules.txt
echo -n "Kata guest kernel modules: " | tee -a labs/lab12/isolation/modules.txt
sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 sh -c "ls /sys/module 2>/dev/null | wc -l" | tee -a labs/lab12/isolation/modules.txt
```

Interpretation:

- Kata guest kernel usually has a **different (often smaller) module set**, reflecting a VM‑tailored kernel and device model.

### Isolation boundary differences (analysis)

- **runc**: “escape” typically means reaching the host kernel context; impact can be **host-level** if combined with kernel vuln/capabilities misconfig.
- **Kata**: “escape” first compromises the **guest VM**; to reach the host you generally need an additional **VM/hypervisor escape** (harder; different attack surface).

Security implications:

- **Container escape in runc** = often **host kernel boundary broken** → higher blast radius (same kernel).
- **Container escape in Kata** = typically **guest boundary broken** first → requires **second-stage** escape to host (stronger isolation, but added complexity).

---

## Task 4 — Performance Comparison (2 pts)

### 4.1 Startup time (runc vs Kata)

Commands:

```bash
echo "=== Startup Time Comparison ===" | tee labs/lab12/bench/startup.txt
echo "runc:" | tee -a labs/lab12/bench/startup.txt
time sudo nerdctl run --rm alpine:3.19 echo "test" 2>&1 | grep real | tee -a labs/lab12/bench/startup.txt
echo "Kata:" | tee -a labs/lab12/bench/startup.txt
time sudo nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 echo "test" 2>&1 | grep real | tee -a labs/lab12/bench/startup.txt
```

Result summary:

- **runc startup**: `___` (expected: sub-second on most hosts)
- **Kata startup**: `___` (expected: a few seconds due to VM boot/init)

### 4.2 HTTP latency baseline (Juice Shop under runc)

Commands:

```bash
sudo nerdctl run -d --name juice-runc -p 3012:3000 bkimminich/juice-shop:v19.0.0
sleep 10
echo "=== HTTP Latency Test (juice-runc) ===" | tee labs/lab12/bench/http-latency.txt
out="labs/lab12/bench/curl-3012.txt"
: > "$out"
for i in $(seq 1 50); do
  curl -s -o /dev/null -w "%{time_total}\n" http://localhost:3012/ >> "$out"
done
echo "Results for port 3012 (juice-runc):" | tee -a labs/lab12/bench/http-latency.txt
awk '{s+=$1; n+=1} END {if(n>0) printf "avg=%.4fs min=%.4fs max=%.4fs n=%d\n", s/n, min, max, n}' \
  min=$(sort -n "$out" | head -1) max=$(sort -n "$out" | tail -1) "$out" | tee -a labs/lab12/bench/http-latency.txt
sudo nerdctl rm -f juice-runc
```

Result summary:

- **avg/min/max**: `___`

### Performance trade-offs (analysis)

- **Startup overhead**:
  - Kata pays VM boot/init + guest kernel bring-up → noticeably slower cold start.
- **Runtime overhead**:
  - Often small for many workloads, but depends on IO, networking, and virtualization path.
- **CPU overhead**:
  - Additional virtualization layers can add overhead; can be mitigated by CPU pinning, hugepages, and tuned hypervisor settings.

Recommendations:

- **Use runc when**:
  - You need fastest startup, lowest overhead, simplest ops, and you trust your kernel hardening and workload isolation controls.
- **Use Kata when**:
  - You run untrusted/multi-tenant workloads, want a stronger boundary than namespaces, or need to reduce blast radius of container escapes.

---

## Notes / Troubleshooting (what I hit)

- _(Optional)_ Any errors encountered and how they were resolved:
  - `___`

