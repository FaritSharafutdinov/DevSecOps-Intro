#!/usr/bin/env bash
set -euo pipefail

# Build Kata Containers 3.x (runtime-rs) Rust runtime (containerd-shim-kata-v2)
# inside a temporary Rust toolchain container, and place the binary
# into the provided output directory. This avoids installing build
# dependencies on the host.
#
# Usage:
#   bash labs/lab12/setup/build-kata-runtime.sh
#   # result: labs/lab12/setup/kata-out/containerd-shim-kata-v2

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
WORK_DIR="${ROOT_DIR}/lab12/setup/kata-build"
OUT_DIR="${ROOT_DIR}/lab12/setup/kata-out"

mkdir -p "${WORK_DIR}" "${OUT_DIR}"

echo "Building Kata runtime in Docker..." >&2
CONTAINER_RUNNER="${CONTAINER_RUNNER:-docker}"

# Podman on Fedora commonly runs with SELinux enforcing; bind mounts need relabeling.
MOUNT_SUFFIX=""
RUN_OPTS=()
if [[ "${CONTAINER_RUNNER}" == *podman* ]]; then
  MOUNT_SUFFIX=":Z"
  RUN_OPTS+=(--security-opt label=disable)
fi

"${CONTAINER_RUNNER}" run --rm "${RUN_OPTS[@]}" \
  -e CARGO_NET_GIT_FETCH_WITH_CLI=true \
  -v "${WORK_DIR}":/work${MOUNT_SUFFIX} \
  -v "${OUT_DIR}":/out${MOUNT_SUFFIX} \
  rust:1.75-bookworm bash -lc '
    set -euo pipefail
    apt-get update && apt-get install -y --no-install-recommends \
      git make gcc g++ cmake pkg-config ca-certificates musl-tools libseccomp-dev && \
      update-ca-certificates || true

    # Some build deps expect a MUSL C++ compiler name.
    if ! command -v x86_64-linux-musl-g++ >/dev/null 2>&1 && command -v x86_64-linux-musl-gcc >/dev/null 2>&1; then
      cat >/usr/local/bin/x86_64-linux-musl-g++ <<'\''EOS'\''
#!/usr/bin/env bash
exec /usr/bin/x86_64-linux-musl-gcc -x c++ \"$@\"
EOS
      chmod +x /usr/local/bin/x86_64-linux-musl-g++
    fi

    # Ensure cargo/rustup are available
    export PATH=/usr/local/cargo/bin:$PATH
    rustc --version; cargo --version; rustup --version || true

    cd /work

    # Clone repo if missing or incomplete.
    # NOTE: /work may be a bind-mount; removing old dirs can fail due to host permissions.
    KATA_DIR="kata-containers"
    if [ ! -d "${KATA_DIR}/.git" ] || [ ! -d "${KATA_DIR}/src" ]; then
      if [ -e "${KATA_DIR}" ]; then
        chmod -R u+w "${KATA_DIR}" 2>/dev/null || true
        rm -rf "${KATA_DIR}" 2>/dev/null || true
      fi
      if [ -e "${KATA_DIR}" ]; then
        # Fallback: clone into a fresh directory (avoid permission issues on bind mounts).
        KATA_DIR="kata-containers.$(date +%s)"
      fi
      git clone --depth 1 https://github.com/kata-containers/kata-containers.git "${KATA_DIR}"
    fi

    # Locate runtime-rs directory (layout may vary slightly across releases).
    if [ -d "${KATA_DIR}/src/runtime-rs" ]; then
      cd "${KATA_DIR}/src/runtime-rs"
    elif [ -d "${KATA_DIR}/src/runtime" ]; then
      cd "${KATA_DIR}/src/runtime"
    else
      echo "ERROR: cannot find runtime sources under kata-containers/src/ (expected runtime-rs)" >&2
      echo "Repo tree (top-level):" >&2
      ls -la "${KATA_DIR}" >&2 || true
      echo "Repo tree (src):" >&2
      ls -la "${KATA_DIR}/src" >&2 || true
      exit 1
    fi

    # Add MUSL target for static build expected by runtime Makefile
    rustup target add x86_64-unknown-linux-musl || true

    # Build the runtime (shim v2)
    make

    # Collect the produced binary (path depends on how Makefile invokes cargo)
    f=$(
      (find target ../../target -type f -name containerd-shim-kata-v2 2>/dev/null || true) | head -n1
    )
    if [ -z "$f" ]; then
      echo "ERROR: built binary not found" >&2; exit 1
    fi
    install -m 0755 "$f" /out/containerd-shim-kata-v2
    strip /out/containerd-shim-kata-v2 || true
    /out/containerd-shim-kata-v2 --version || true
  '

echo "Done. Binary saved to: ${OUT_DIR}/containerd-shim-kata-v2" >&2
