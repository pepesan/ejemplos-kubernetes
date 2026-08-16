#!/usr/bin/env bash
# Librería compartida entre 00_instalar_ansible.sh y 01_bootstrap_host.sh.
# No se ejecuta directamente: se importa con "source".
#
# check_and_fix_sudo: comprueba que "sudo -n" funciona (imprescindible para
# que Ansible pueda escalar privilegios de forma no interactiva con conexión
# local) y, si falla, autoconfigura /etc/sudoers.d/k8s-labs.
#
# DETECCIÓN antes de actuar: distingue sudo-rs de sudo tradicional (legible
# sin privilegios vía "sudo --version") y comprueba si hay TTY disponible.
# Lo que NO se puede detectar de antemano es si "requiretty" está activo en
# el sudo tradicional: /etc/sudoers y /etc/sudoers.d/* son 0440 root:root,
# ilegibles para un usuario normal antes de tener sudo. Por eso, sin TTY, el
# plan se decide con UN sondeo mínimo (un solo intento de "sudo -S -v") que
# distingue sus 3 desenlaces posibles por el mensaje de error:
#   - éxito                          -> ya autenticado, aplicar directamente
#   - "must have a tty"/"no tty"     -> requiretty activo; no hay forma
#                                        fiable de saltárselo sin terminal
#                                        real (ver nota más abajo) -> error
#   - contraseña rechazada           -> error
#
# Por qué NO se usa un pseudo-terminal ("script"/expect) para sortear
# requiretty sin TTY: probado en vivo y descartado por poco fiable y no
# portable —
#   - "script" no está instalado por defecto en imágenes mínimas de Fedora.
#   - En Rocky Linux 9 (util-linux 2.37), "sudo -S" dentro de "script"
#     ignora la contraseña recibida por stdin ("no password was provided"):
#     al detectar un TTY real, sudo prioriza leer de /dev/tty en vez de
#     stdin, y en la sesión de "script" nadie escribe ahí.
# Con requiretty activo y sin TTY, la única vía fiable es pedir al usuario
# que ejecute el script desde una terminal real o desactive requiretty.
#
# IMPORTANTE: el ticket de credenciales de sudo (cacheado tras "sudo -v"/
# "sudo -S -v") no sobrevive a un subproceso nuevo (p. ej. "bash otro.sh"):
# confirmado en vivo en sudo-rs (Ubuntu 26.04), donde una llamada a sudo
# dentro de un script bash lanzado como subproceso separado exige de nuevo
# "a terminal ... to authenticate" pese a la autenticación previa. Por eso
# los comandos "sudo install"/"sudo visudo" se ejecutan en la MISMA función
# (mismo proceso bash), nunca en un script externo aparte.
#
# visudo no siempre está en el PATH del usuario normal (p. ej. openSUSE:
# vive en /usr/sbin, fuera del PATH por defecto de un usuario sin sudo
# todavía). Se busca por ruta absoluta con fallback a varias ubicaciones
# habituales antes de recurrir a "command -v".
#
# Ubuntu 24.10+ trae sudo-rs (reimplementación en Rust) que no reconoce la
# directiva "requiretty"/"!requiretty": si aparece en cualquier archivo de
# /etc/sudoers.d/, sudo-rs deniega sudo por completo (no solo esa regla), y
# nunca exige TTY para autenticar. Por eso el sudoers generado solo incluye
# el bypass "!requiretty" cuando el sudo del sistema NO es sudo-rs.
check_and_fix_sudo() {
  # Si ya corre como root, no necesita nada
  if [ "$(id -u)" -eq 0 ]; then
    return 0
  fi

  # Verificar si sudo -n funciona (no interactivo, sin TTY)
  if sudo -n whoami &>/dev/null; then
    return 0
  fi

  echo "" >&2
  echo "════════════════════════════════════════════════════════════════" >&2
  echo "  ⚠ sudo -n falló. Esto impide la escalada de privilegios" >&2
  echo "  automática de Ansible con conexión local." >&2
  echo "  Se intentará autoconfigurar /etc/sudoers.d/k8s-labs..." >&2
  echo "════════════════════════════════════════════════════════════════" >&2
  echo "" >&2

  if [ ! -d /etc/sudoers.d ]; then
    echo "ERROR: /etc/sudoers.d/ no existe. No se puede autoconfigurar." >&2
    echo "Ejecuta manualmente:" >&2
    echo '  echo "YOURUSER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/k8s-labs' >&2
    echo "  sudo chmod 0440 /etc/sudoers.d/k8s-labs" >&2
    exit 1
  fi

  # /etc/sudoers ausente por completo: confirmado en vivo incluso en la
  # imagen VM oficial de openSUSE Tumbleweed (el paquete "sudo" no activa
  # el fichero de fábrica de /usr/etc/sudoers en el primer arranque). Sudo
  # entra en un estado indefinido y pide la contraseña de ROOT en vez de la
  # del usuario que invoca, algo que K8S_LABS_SUDO_PASS (la contraseña sudo
  # del propio usuario) no puede resolver. Es un sistema sin sudo
  # configurado, no una restricción de sudo — requiere intervención manual
  # con la contraseña de root. NOTA: /usr/etc/sudoers (si existe) NO sirve
  # tal cual como fix — trae "Defaults targetpw" activo, que exige la
  # contraseña de root en vez de la del usuario; por eso se genera aquí un
  # /etc/sudoers mínimo y funcional en su lugar.
  if [ ! -e /etc/sudoers ]; then
    echo "ERROR: /etc/sudoers no existe en este sistema (sudo sin configurar)." >&2
    echo "No se puede autoconfigurar sin la contraseña de root. Ejecuta como root:" >&2
    echo "  cat > /etc/sudoers <<'SUDOERS_EOF'" >&2
    echo "root ALL=(ALL:ALL) ALL" >&2
    echo "%wheel ALL=(ALL:ALL) ALL" >&2
    echo "%sudo ALL=(ALL:ALL) ALL" >&2
    echo "@includedir /etc/sudoers.d" >&2
    echo "SUDOERS_EOF" >&2
    echo "  chmod 0440 /etc/sudoers" >&2
    exit 1
  fi

  if [ -f /etc/sudoers.d/k8s-labs ]; then
    echo "/etc/sudoers.d/k8s-labs ya existe. Reintentando sudo -n..." >&2
    if sudo -n whoami &>/dev/null; then
      return 0
    fi
    echo "El archivo existe pero sudo -n sigue fallando. Verifica su contenido." >&2
    exit 1
  fi

  # Localizar visudo por ruta absoluta: en algunas distros (p. ej. openSUSE)
  # vive en /usr/sbin, fuera del PATH de un usuario sin sudo todavía.
  local visudo_bin=""
  for candidate in /usr/sbin/visudo /sbin/visudo /usr/bin/visudo; do
    if [ -x "$candidate" ]; then
      visudo_bin="$candidate"
      break
    fi
  done
  if [ -z "$visudo_bin" ]; then
    visudo_bin="$(command -v visudo 2>/dev/null || true)"
  fi
  if [ -z "$visudo_bin" ]; then
    echo "ERROR: no se encuentra el binario 'visudo' en este sistema." >&2
    exit 1
  fi

  # -------------------------------------------------------------------------
  # 1. DETECCIÓN: lo que se puede saber sin privilegios (sudo-rs, TTY), más
  #    un sondeo mínimo (si hace falta) para decidir el plan de autenticación.
  # -------------------------------------------------------------------------
  local sudo_is_rs=false
  if sudo --version 2>/dev/null | head -1 | grep -qi 'sudo-rs'; then
    sudo_is_rs=true
  fi

  local has_tty=false
  if [ -t 0 ] && [ -t 1 ]; then
    has_tty=true
  fi

  local auth_plan=""
  if $has_tty; then
    auth_plan="interactive"
  elif [ -z "${K8S_LABS_SUDO_PASS:-}" ]; then
    auth_plan="none"
  else
    # Sondeo: un único intento de autenticar por stdin, EN ESTE MISMO
    # proceso (no en un subshell aparte) para que el ticket resultante siga
    # siendo válido en los "sudo install"/"sudo visudo" de más abajo.
    local probe_err
    probe_err="$(mktemp)"
    if printf '%s\n' "$K8S_LABS_SUDO_PASS" | sudo -S -v 2>"$probe_err"; then
      auth_plan="stdin"
    elif grep -qi 'tty' "$probe_err"; then
      auth_plan="requiretty_no_tty"
    else
      auth_plan="none"
      echo "ERROR: sudo rechazó K8S_LABS_SUDO_PASS (contraseña incorrecta)." >&2
    fi
    rm -f "$probe_err"
  fi

  echo "Plan: sudo_is_rs=$sudo_is_rs has_tty=$has_tty -> auth=$auth_plan" >&2

  if [ "$auth_plan" = "requiretty_no_tty" ]; then
    echo "ERROR: este sudo exige un terminal real (\"Defaults requiretty\") y" >&2
    echo "no hay ninguno disponible en esta sesión. No hay forma fiable de" >&2
    echo "saltárselo sin acceso a una terminal interactiva. Opciones:" >&2
    echo "" >&2
    echo "  1. Ejecuta el script desde una terminal real (ssh/tty)." >&2
    echo "  2. O pide a un administrador que desactive requiretty:" >&2
    echo "       sudo visudo   # comenta/borra la línea 'Defaults requiretty'" >&2
    exit 1
  fi

  if [ "$auth_plan" = "none" ]; then
    if [ -z "${K8S_LABS_SUDO_PASS:-}" ]; then
      echo "ERROR: no hay TTY disponible y K8S_LABS_SUDO_PASS no está definida." >&2
      echo "" >&2
      echo "Esto ocurre al ejecutar el script desde un agente/CI/IDE remoto sin" >&2
      echo "terminal interactiva. Opciones:" >&2
      echo "" >&2
      echo "  1. Ejecuta el script desde una terminal real (ssh/tty)." >&2
      echo "  2. O define la contraseña de sudo en una variable de entorno y reintenta:" >&2
      echo "       K8S_LABS_SUDO_PASS='tu_contraseña' ./00_instalar_ansible.sh" >&2
      echo "  3. O crea el archivo manualmente:" >&2
      echo "       echo '$(id -un) ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/k8s-labs" >&2
      echo "       sudo chmod 0440 /etc/sudoers.d/k8s-labs" >&2
    fi
    exit 1
  fi

  # -------------------------------------------------------------------------
  # 2. PREPARAR el contenido del sudoers: sudo-rs nunca admite "!requiretty"
  #    (se omite, ver cabecera); sudo tradicional lo incluye siempre (inocuo
  #    si requiretty no estaba activo; en este punto ya sabemos que no lo
  #    está, porque auth_plan="stdin" solo se llega sin ese bloqueo).
  # -------------------------------------------------------------------------
  # Se usa el USUARIO concreto (no un grupo): más preciso (solo este usuario
  # necesita el bypass, no cualquier otro miembro de su grupo primario/wheel)
  # y evita depender de que "sudo" resuelva la pertenencia a grupo primario
  # de la misma forma en todas las distros — confirmado en vivo que en
  # openSUSE una regla "%grupo_primario" no concede sudo aunque el usuario
  # pertenezca a ese grupo, mientras que en Debian/Ubuntu sí.
  local target_user content_file
  target_user="$(id -un)"
  content_file="$(mktemp)"
  {
    echo "# k8s-labs: permite ejecución no interactiva de Ansible sobre localhost"
    echo "# Generado automáticamente por 00_instalar_ansible.sh"
    echo "# Ver: ansible/base/README.md"
    if ! $sudo_is_rs; then
      echo "Defaults:${target_user} !requiretty"
    fi
    echo "${target_user} ALL=(ALL) NOPASSWD: ALL"
  } > "$content_file"

  # -------------------------------------------------------------------------
  # 3. EJECUTAR: "interactive" y "stdin" corren los "sudo install"/"sudo
  #    visudo" en ESTE MISMO proceso, reutilizando el ticket recién obtenido
  #    (ver nota de cabecera sobre por qué no se delega a un subproceso).
  # -------------------------------------------------------------------------
  local ok=false
  case "$auth_plan" in
    interactive)
      echo "Se necesita tu contraseña de sudo para crear /etc/sudoers.d/k8s-labs." >&2
      if sudo -v \
        && sudo install -o root -g root -m 0440 "$content_file" /etc/sudoers.d/k8s-labs \
        && sudo "$visudo_bin" -c -f /etc/sudoers.d/k8s-labs &>/dev/null; then
        ok=true
      fi
      ;;
    stdin)
      # El sondeo del paso 1 ya autenticó (sudo -S -v tuvo éxito) EN ESTE
      # PROCESO: el ticket cacheado sigue siendo válido para estos "sudo".
      echo "Sin TTY; K8S_LABS_SUDO_PASS aceptada con sudo -S (sin requiretty)." >&2
      if sudo install -o root -g root -m 0440 "$content_file" /etc/sudoers.d/k8s-labs \
        && sudo "$visudo_bin" -c -f /etc/sudoers.d/k8s-labs &>/dev/null; then
        ok=true
      fi
      ;;
  esac

  rm -f "$content_file"

  if ! $ok; then
    echo "ERROR: no se pudo autoconfigurar /etc/sudoers.d/k8s-labs." >&2
    sudo rm -f /etc/sudoers.d/k8s-labs 2>/dev/null
    exit 1
  fi

  if sudo -n whoami &>/dev/null; then
    echo "✅ /etc/sudoers.d/k8s-labs creado y verificado. sudo -n OK." >&2
    echo "" >&2
    return 0
  fi

  echo "ERROR: El archivo se escribió pero sudo -n sigue fallando." >&2
  echo "Revisa /etc/sudoers.d/k8s-labs manualmente." >&2
  exit 1
}
