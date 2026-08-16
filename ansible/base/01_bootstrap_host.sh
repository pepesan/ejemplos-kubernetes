#!/usr/bin/env bash
set -euo pipefail

# Script para automatizar la inicialización y preparación de LXD en la máquina local

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# check_and_fix_sudo() vive en lib_sudo.sh (compartida con 00_instalar_ansible.sh).
source "$SCRIPT_DIR/lib_sudo.sh"

check_and_fix_sudo

echo "════════════════════════════════════════════════════════════════"
echo "  Iniciando preparación del Host Local (LXD Bootstrap)..."
echo "  Este script instalará LXD, configurará redes y almacenamiento"
echo "  y cargará los módulos del kernel requeridos."
echo "════════════════════════════════════════════════════════════════"
echo ""

# Ejecutar el playbook de Ansible. Sin --ask-become-pass: check_and_fix_sudo
# ya garantizó arriba que "sudo -n" funciona sin contraseña, así que Ansible
# escala privilegios de forma transparente. Pedirla aquí también sería una
# segunda contraseña redundante — confirmado en vivo: con --ask-become-pass
# el usuario tecleaba la contraseña dos veces en la misma ejecución.
ansible-playbook "$SCRIPT_DIR/00_bootstrap_host_lxd.yml"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  ¡Proceso finalizado!"
echo "  RECUERDA: Ejecuta el comando 'newgrp lxd' o reinicia tu"
echo "  terminal para poder ejecutar comandos 'lxc' sin sudo."
echo "════════════════════════════════════════════════════════════════"
