#!/usr/bin/env bash
set -euo pipefail

# Script para instalar Ansible en el host vía pipx (aislado del Python del sistema)
# y lanzar a continuación la comprobación de requisitos previos (check_requisitos.yml).
#
# Multidistribución: probado en vivo (contenedores LXD) sobre las 2 últimas versiones
# estables de Ubuntu, Debian, Rocky Linux (solo 9: no hay imagen de LXD para la 10
# todavía), Fedora y openSUSE (Leap 16.0 y Tumbleweed, ya que no hay imagen de LXD para
# ninguna 15.x). Ver ansible/scripts/test_instalar_ansible_distros.sh.
#
# SKIP_CHECK_REQUISITOS=true evita el paso final (usado por ese test multidistro, donde
# no hay LXD real dentro del contenedor de prueba).

SKIP_CHECK_REQUISITOS="${SKIP_CHECK_REQUISITOS:-false}"

run_priv() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

# Los mirrors de los gestores de paquetes fallan de forma intermitente
# (DNS/red), sobre todo justo tras arrancar una máquina/contenedor nuevo.
retry() {
  local attempt=1 max=3
  until "$@"; do
    if [ "$attempt" -ge "$max" ]; then
      return 1
    fi
    echo "Fallo de red instalando paquetes, reintentando ($attempt/$max)..." >&2
    attempt=$((attempt + 1))
    sleep 5
  done
}

echo "════════════════════════════════════════════════════════════════"
echo "  Instalando Ansible mediante pipx..."
echo "════════════════════════════════════════════════════════════════"
echo ""

if command -v apt-get &>/dev/null; then
  PKG_MANAGER=apt
elif command -v dnf &>/dev/null; then
  PKG_MANAGER=dnf
elif command -v zypper &>/dev/null; then
  PKG_MANAGER=zypper
else
  echo "No se reconoce el gestor de paquetes de esta distro (se esperaba apt, dnf o zypper)." >&2
  exit 1
fi

if ! command -v curl &>/dev/null; then
  echo "curl no está instalado. Instalando..."
  case "$PKG_MANAGER" in
    apt) retry run_priv apt-get update && retry run_priv apt-get install -y curl ;;
    dnf) retry run_priv dnf install -y curl ;;
    zypper) retry run_priv zypper --non-interactive install curl ;;
  esac
fi

# openssl y tar los necesita el instalador oficial de helm (get-helm-4) para
# verificar el checksum y extraer el tarball. Confirmado en vivo que faltan
# por defecto: Fedora no trae openssl, Rocky Linux 9 no trae tar.
if ! command -v openssl &>/dev/null || ! command -v tar &>/dev/null; then
  echo "openssl/tar no están instalados. Instalando (los necesita el instalador de helm)..."
  case "$PKG_MANAGER" in
    apt) retry run_priv apt-get update && retry run_priv apt-get install -y openssl tar ;;
    dnf) retry run_priv dnf install -y openssl tar ;;
    zypper) retry run_priv zypper --non-interactive install openssl tar ;;
  esac
fi

if ! command -v python3 &>/dev/null; then
  echo "python3 no está instalado. Instalando..."
  case "$PKG_MANAGER" in
    apt) retry run_priv apt-get update && retry run_priv apt-get install -y python3 ;;
    dnf) retry run_priv dnf install -y python3 ;;
    zypper) retry run_priv zypper --non-interactive install python3 ;;
  esac
fi

if ! command -v pipx &>/dev/null; then
  echo "pipx no está instalado. Intentando vía el gestor de paquetes nativo..."
  case "$PKG_MANAGER" in
    apt)
      retry run_priv apt-get update
      retry run_priv apt-get install -y pipx
      ;;
    dnf)
      # No falla el script si no existe (p. ej. Rocky Linux 9 no publica
      # "pipx" en sus repos): cae al fallback de pip de más abajo.
      retry run_priv dnf install -y pipx || true
      ;;
    zypper)
      # openSUSE no publica un paquete "pipx" con nombre estable (va versionado con
      # el Python del sistema, p.ej. python313-pipx), así que en vez de adivinar el
      # nombre exacto se recurre directamente al fallback de pip de más abajo.
      ;;
  esac
fi

if ! command -v pipx &>/dev/null; then
  echo "pipx sigue sin estar disponible vía el gestor de paquetes; instalando con pip --user..."
  if ! python3 -m pip --version &>/dev/null; then
    # Se instala pip como paquete de la propia distro en vez de con
    # "ensurepip": en openSUSE el pip que arranca ensurepip está marcado
    # como "externally-managed" (PEP 668) y rechaza "pip install --user";
    # el pip empaquetado por zypper no tiene esa restricción.
    case "$PKG_MANAGER" in
      apt) retry run_priv apt-get install -y python3-pip ;;
      dnf) retry run_priv dnf install -y python3-pip ;;
      zypper) retry run_priv zypper --non-interactive install python3-pip ;;
    esac
  fi
  if ! python3 -m pip --version &>/dev/null; then
    python3 -m ensurepip --user --upgrade
  fi
  # openSUSE Tumbleweed marca su propio pip empaquetado como
  # "externally-managed" (PEP 668) pese a no venir de ensurepip; pip >= 23.0.1
  # acepta "--break-system-packages" para saltárselo deliberadamente (justo lo
  # que se quiere aquí: es la propia distro pidiendo ese flag en su mensaje de
  # error). El pip 21.x de Rocky Linux 9 no lo necesita ni lo entiende, así
  # que solo se usa como fallback si la instalación normal falla.
  python3 -m pip install --user pipx || python3 -m pip install --user --break-system-packages pipx
fi

export PATH="$HOME/.local/bin:$PATH"

# --include-deps: en distros con un Python del sistema antiguo (p. ej. Rocky Linux 9
# con Python 3.9), pip resuelve una versión de "ansible" más vieja cuyo propio paquete
# solo declara "ansible-community" como script propio, delegando el resto
# (ansible-playbook, ansible-galaxy...) en su dependencia "ansible-core". pipx no
# expone los scripts de las dependencias salvo que se pida explícitamente.
if pipx list --short 2>/dev/null | grep -qx ansible; then
  pipx upgrade --include-deps ansible
else
  pipx install --include-deps ansible
fi

pipx ensurepath

# pipx ejecuta Ansible en un venv aislado que no ve las librerías Python del
# sistema (python3-kubernetes, python3-jsonpatch, python3-yaml instaladas por
# 00_bootstrap_host_lxd.yml). Sin esto, cualquier tarea kubernetes.core.k8s
# (p. ej. 07_desplegar_headlamp.yml) falla con "Failed to import the required
# Python library (kubernetes)" — un fallo que check_requisitos.yml no detecta,
# porque solo comprueba que la colección esté instalada, no que la librería
# sea importable desde el intérprete que usará Ansible.
pipx inject --force ansible kubernetes jsonpatch pyyaml

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Ansible instalado."
echo "════════════════════════════════════════════════════════════════"

# kubectl y helm se instalan aquí a partir de sus binarios oficiales (mismo
# método en cualquier distro) en vez de depender de snap/apt/dnf/zypper: así
# quedan disponibles en el host nada más instalar Ansible, sin esperar al
# aprovisionamiento completo de LXD en 01_bootstrap_host.sh.
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Instalando kubectl y helm en el host..."
echo "════════════════════════════════════════════════════════════════"
echo ""

case "$(uname -m)" in
  x86_64) HOST_ARCH=amd64 ;;
  aarch64) HOST_ARCH=arm64 ;;
  *)
    echo "Arquitectura '$(uname -m)' no soportada para la instalación binaria de kubectl/helm." >&2
    exit 1
    ;;
esac

if command -v kubectl &>/dev/null; then
  echo "kubectl ya está instalado ($(kubectl version --client 2>/dev/null | head -1))."
else
  KUBECTL_TMPDIR="$(mktemp -d)"
  KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
  curl -L -s -o "$KUBECTL_TMPDIR/kubectl" \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${HOST_ARCH}/kubectl"
  curl -L -s -o "$KUBECTL_TMPDIR/kubectl.sha256" \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${HOST_ARCH}/kubectl.sha256"
  (cd "$KUBECTL_TMPDIR" && echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check --status)
  run_priv install -o root -g root -m 0755 "$KUBECTL_TMPDIR/kubectl" /usr/local/bin/kubectl
  rm -rf "$KUBECTL_TMPDIR"
  echo "kubectl ${KUBECTL_VERSION} instalado en /usr/local/bin/kubectl."
fi

if command -v helm &>/dev/null; then
  echo "helm ya está instalado ($(helm version --short 2>/dev/null))."
else
  HELM_TMPDIR="$(mktemp -d)"
  curl -fsSL -o "$HELM_TMPDIR/get_helm.sh" https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
  chmod +x "$HELM_TMPDIR/get_helm.sh"
  run_priv "$HELM_TMPDIR/get_helm.sh"
  rm -rf "$HELM_TMPDIR"
fi

if [ "$SKIP_CHECK_REQUISITOS" = "true" ]; then
  exit 0
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Lanzando comprobación de requisitos..."
echo "════════════════════════════════════════════════════════════════"
echo ""

ANSIBLE_PLAYBOOK="$HOME/.local/bin/ansible-playbook"
if ! command -v ansible-playbook &>/dev/null && [ -x "$ANSIBLE_PLAYBOOK" ]; then
  "$ANSIBLE_PLAYBOOK" check_requisitos.yml
else
  ansible-playbook check_requisitos.yml
fi
