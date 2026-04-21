#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
cd "$ROOT_DIR"

mkdir -p labs/lab12/{setup,runc,kata,isolation,bench,analysis}

ensure_containerd() {
  mkdir -p /run/containerd
  if pgrep -x containerd >/dev/null 2>&1; then
    return 0
  fi
  nohup containerd --config /etc/containerd/config.toml >/var/log/containerd.log 2>&1 &
  echo $! >/run/containerd/containerd.pid
  sleep 2
}

ensure_containerd

# Fedora minimal installs may not include seq by default.
if ! command -v seq >/dev/null 2>&1; then
  echo "ERROR: 'seq' not found (install coreutils)." >&2
  exit 1
fi

echo "[lab12] Task1: verify kata runtime works"
nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 uname -a | tee labs/lab12/setup/kata-test-uname.txt

echo "[lab12] Task2: juice-shop under runc"
nerdctl pull bkimminich/juice-shop:v19.0.0
nerdctl run -d --name juice-runc -p 3012:3000 bkimminich/juice-shop:v19.0.0
sleep 15
curl -s -o /dev/null -w "juice-runc: HTTP %{http_code}\n" http://localhost:3012 | tee labs/lab12/runc/health.txt

echo "[lab12] Task2: kata short-lived containers"
nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 uname -a | tee labs/lab12/kata/test1.txt
nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 uname -r | tee labs/lab12/kata/kernel.txt
nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 sh -c "grep 'model name' /proc/cpuinfo | head -1" | tee labs/lab12/kata/cpu.txt

echo "[lab12] Task2: kernel + cpu comparisons"
{
  echo "=== Kernel Version Comparison ==="
  echo -n "Host kernel (runc uses this): "
  uname -r
  echo -n "Kata guest kernel: "
  nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 cat /proc/version
} | tee labs/lab12/analysis/kernel-comparison.txt

{
  echo "=== CPU Model Comparison ==="
  echo "Host CPU:"
  grep "model name" /proc/cpuinfo | head -1
  echo "Kata VM CPU:"
  nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 sh -c "grep 'model name' /proc/cpuinfo | head -1"
} | tee labs/lab12/analysis/cpu-comparison.txt

echo "[lab12] Task3: isolation tests"
{
  echo "=== dmesg Access Test ==="
  echo "Kata VM (separate kernel boot logs):"
  nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 dmesg 2>&1 | head -5
} | tee labs/lab12/isolation/dmesg.txt

{
  echo "=== /proc Entries Count ==="
  echo -n "Host: "
  ls /proc | wc -l
  echo -n "Kata VM: "
  nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 sh -c "ls /proc | wc -l"
} | tee labs/lab12/isolation/proc.txt

{
  echo "=== Network Interfaces ==="
  echo "Kata VM network:"
  nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 ip addr
} | tee labs/lab12/isolation/network.txt

{
  echo "=== Kernel Modules Count ==="
  echo -n "Host kernel modules: "
  ls /sys/module | wc -l
  echo -n "Kata guest kernel modules: "
  nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 sh -c "ls /sys/module 2>/dev/null | wc -l"
} | tee labs/lab12/isolation/modules.txt

echo "[lab12] Task4: performance snapshot"
{
  echo "=== Startup Time Comparison ==="
  echo "runc:"
  (time nerdctl run --rm alpine:3.19 echo test) 2>&1 | grep real
  echo "Kata:"
  (time nerdctl run --rm --runtime io.containerd.kata.v2 alpine:3.19 echo test) 2>&1 | grep real
} | tee labs/lab12/bench/startup.txt

out="labs/lab12/bench/curl-3012.txt"
: >"$out"
for i in $(seq 1 50); do
  curl -s -o /dev/null -w "%{time_total}\n" http://localhost:3012/ >>"$out"
done
awk 'BEGIN{min=1e9;max=0}{s+=$1;n+=1;if($1<min)min=$1;if($1>max)max=$1}END{printf "avg=%.4fs min=%.4fs max=%.4fs n=%d\n", s/n, min, max, n}' \
  "$out" | tee labs/lab12/bench/http-latency.txt

nerdctl rm -f juice-runc >/dev/null 2>&1 || true

echo "[lab12] done"

