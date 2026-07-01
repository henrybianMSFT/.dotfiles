#!/usr/bin/env bash
set -euo pipefail

# Podman-first WSL bootstrap:
# - Enables systemd in WSL (required for healthy rootless runtime dirs)
# - Installs Podman toolchain (podman/buildah/skopeo + docker->podman shim)
# - Installs ORAS + Kubernetes CLIs
#
# Usage:
#   chmod +x ./setup-wsl-containers.sh
#   ./setup-wsl-containers.sh
#
# If script reports "WSL restart required", run in Windows PowerShell:
#   wsl --shutdown
# then start distro again and rerun script.

need_restart=0

log() { echo -e "\033[1;34m[setup]\033[0m $*"; }
warn() { echo -e "\033[1;33m[warn]\033[0m  $*"; }
err() { echo -e "\033[1;31m[error]\033[0m $*" >&2; }

if [[ "$(uname -s)" != "Linux" ]]; then
  err "This script must run inside Linux/WSL."
  exit 1
fi

if ! grep -qi microsoft /proc/version 2>/dev/null; then
  warn "Not detecting WSL from /proc/version; continuing anyway."
fi

if ! command -v sudo >/dev/null 2>&1; then
  err "sudo is required."
  exit 1
fi

arch="$(uname -m)"
case "$arch" in
  x86_64) arch_k8s="amd64"; arch_oras="amd64"; arch_kind="amd64"; arch_kubelogin="amd64" ;;
  aarch64|arm64) arch_k8s="arm64"; arch_oras="arm64"; arch_kind="arm64"; arch_kubelogin="arm64" ;;
  *) err "Unsupported architecture: $arch"; exit 1 ;;
esac

# Ensure systemd in WSL
if [[ ! -f /etc/wsl.conf ]] || ! grep -Eq '^\s*systemd\s*=\s*true\s*$' /etc/wsl.conf; then
  log "Configuring /etc/wsl.conf with systemd=true"
  sudo mkdir -p /etc
  if [[ ! -f /etc/wsl.conf ]]; then
    printf "[boot]\nsystemd=true\n" | sudo tee /etc/wsl.conf >/dev/null
  elif grep -Eq '^\[boot\]' /etc/wsl.conf; then
    if ! grep -Eq '^\s*systemd\s*=' /etc/wsl.conf; then
      printf "\nsystemd=true\n" | sudo tee -a /etc/wsl.conf >/dev/null
    else
      sudo sed -i -E 's/^\s*systemd\s*=.*/systemd=true/' /etc/wsl.conf
    fi
  else
    printf "\n[boot]\nsystemd=true\n" | sudo tee -a /etc/wsl.conf >/dev/null
  fi
  need_restart=1
fi

source /etc/os-release

install_common_bins() {
  sudo install -d -m 0755 /usr/local/bin
}

install_oras() {
  local v="1.2.3"
  log "Installing oras ${v}"
  curl -fsSL -o /tmp/oras.tar.gz \
    "https://github.com/oras-project/oras/releases/download/v${v}/oras_${v}_linux_${arch_oras}.tar.gz"
  tar -xzf /tmp/oras.tar.gz -C /tmp oras
  sudo install -m 0755 /tmp/oras /usr/local/bin/oras
}

install_kubectl() {
  log "Installing kubectl (latest stable)"
  local v
  v="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  curl -fsSL -o /tmp/kubectl "https://dl.k8s.io/release/${v}/bin/linux/${arch_k8s}/kubectl"
  sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
}

install_helm() {
  local v="3.16.4"
  log "Installing helm v${v}"
  curl -fsSL -o /tmp/helm.tar.gz "https://get.helm.sh/helm-v${v}-linux-${arch_k8s}.tar.gz"
  tar -xzf /tmp/helm.tar.gz -C /tmp
  sudo install -m 0755 "/tmp/linux-${arch_k8s}/helm" /usr/local/bin/helm
}

install_kustomize() {
  local v="5.4.3"
  log "Installing kustomize v${v}"
  curl -fsSL -o /tmp/kustomize.tar.gz \
    "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${v}/kustomize_v${v}_linux_${arch_k8s}.tar.gz"
  tar -xzf /tmp/kustomize.tar.gz -C /tmp
  sudo install -m 0755 /tmp/kustomize /usr/local/bin/kustomize
}

install_kind() {
  local v="0.24.0"
  log "Installing kind v${v}"
  curl -fsSL -o /tmp/kind "https://kind.sigs.k8s.io/dl/v${v}/kind-linux-${arch_kind}"
  sudo install -m 0755 /tmp/kind /usr/local/bin/kind
}

install_kubelogin() {
  local v="0.1.0"
  log "Installing kubelogin v${v}"
  curl -fsSL -o /tmp/kubelogin.zip \
    "https://github.com/Azure/kubelogin/releases/download/v${v}/kubelogin-linux-${arch_kubelogin}.zip"
  sudo apt-get -y install unzip >/dev/null 2>&1 || true
  unzip -o /tmp/kubelogin.zip -d /tmp/kubelogin >/dev/null
  local bin
  bin="$(find /tmp/kubelogin -type f -name kubelogin | head -n1)"
  sudo install -m 0755 "$bin" /usr/local/bin/kubelogin
}

if command -v apt-get >/dev/null 2>&1; then
  log "Installing packages via apt"
  sudo apt-get update -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates curl jq tar gzip unzip \
    uidmap slirp4netns fuse-overlayfs netavark aardvark-dns \
    podman podman-docker buildah skopeo containernetworking-plugins
elif command -v dnf >/dev/null 2>&1; then
  log "Installing packages via dnf"
  sudo dnf install -y \
    ca-certificates curl jq tar gzip unzip shadow-utils \
    slirp4netns fuse-overlayfs netavark aardvark-dns \
    podman podman-docker buildah skopeo cri-tools containernetworking-plugins
else
  err "Unsupported distro: need apt or dnf."
  exit 1
fi

install_common_bins
install_oras
install_kubectl
install_helm
install_kustomize
install_kind
install_kubelogin

# Rootless podman prerequisites
if ! grep -q "^${USER}:" /etc/subuid; then
  log "Configuring /etc/subuid for ${USER}"
  sudo usermod --add-subuids 100000-165535 "${USER}"
fi
if ! grep -q "^${USER}:" /etc/subgid; then
  log "Configuring /etc/subgid for ${USER}"
  sudo usermod --add-subgids 100000-165535 "${USER}"
fi

if (( need_restart == 1 )); then
  warn "WSL restart required to activate systemd."
  warn "Run: wsl --shutdown   (from Windows PowerShell), then start WSL and rerun this script."
  exit 2
fi

log "Versions:"
podman --version || true
docker --version || true   # podman-docker shim
oras version || true
kubectl version --client --output=yaml | sed -n '1,8p' || true
helm version --short || true
kustomize version || true
kind version || true
kubelogin --version || true

log "Done."
