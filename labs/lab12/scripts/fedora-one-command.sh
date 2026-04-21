#!/usr/bin/env bash
set -euo pipefail

# Fedora "one command" runner for Lab 12.
# Usage (from repo root):
#   sudo bash labs/lab12/scripts/fedora-one-command.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
cd "$ROOT_DIR"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "ERROR: run as root (use sudo)." >&2
  exit 1
fi

mkdir -p labs/lab12/{setup,runc,kata,isolation,bench,analysis}

echo "[lab12] Preflight: KVM availability"
if [[ ! -e /dev/kvm ]]; then
  echo "ERROR: /dev/kvm not found. Kata needs KVM (enable virtualization in BIOS/UEFI and ensure kvm_intel/kvm_amd loaded)." >&2
  exit 1
fi

echo "[lab12] Install dependencies (dnf)"
dnf -y install \
  containerd \
  jq \
  curl \
  gawk \
  zstd \
  iproute \
  iptables \
  containernetworking-plugins \
  podman \
  git \
  ca-certificates \
  tar \
  gzip \
  coreutils \
  util-linux

echo "[lab12] Start containerd"
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
systemctl enable --now containerd

echo "[lab12] Install nerdctl (download binary)"
NERDCTL_VER="${NERDCTL_VER:-2.2.2}"
curl -fL -o /tmp/nerdctl.tgz "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VER}/nerdctl-${NERDCTL_VER}-linux-amd64.tar.gz"
tar -C /usr/local/bin -xzf /tmp/nerdctl.tgz nerdctl
rm -f /tmp/nerdctl.tgz
nerdctl --version | tee labs/lab12/setup/nerdctl-version.txt
containerd --version | tee labs/lab12/setup/containerd-version.txt

echo "[lab12] Ensure CNI config"
install -d -m 0755 /etc/cni/net.d
install -m 0644 labs/lab12/setup/10-bridge.conflist /etc/cni/net.d/10-bridge.conflist

echo "[lab12] Build Kata shim (runtime-rs) using Podman"
if ! command -v docker >/dev/null 2>&1; then
  # build-kata-runtime.sh uses `docker run ...`; make it work on Fedora by mapping docker->podman.
  cat >/usr/local/bin/docker <<'EOF'
#!/usr/bin/env bash
exec podman "$@"
EOF
  chmod +x /usr/local/bin/docker
fi

bash labs/lab12/setup/build-kata-runtime.sh
install -m 0755 labs/lab12/setup/kata-out/containerd-shim-kata-v2 /usr/local/bin/containerd-shim-kata-v2
containerd-shim-kata-v2 --version | tee labs/lab12/setup/kata-built-version.txt

echo "[lab12] Install Kata guest assets + config"
bash labs/lab12/scripts/install-kata-assets.sh

echo "[lab12] Configure containerd Kata runtime"
bash labs/lab12/scripts/configure-containerd-kata.sh
systemctl restart containerd

echo "[lab12] Run lab workload + capture artifacts"
bash labs/lab12/scripts/run-lab12.sh

echo "[lab12] Generate filled submission markdown"
bash labs/lab12/scripts/generate-submission12.sh

echo "[lab12] Done. Generated: labs/submission12.md"
echo "[lab12] Next: git add labs/lab12/ labs/submission12.md && git commit && git push"

