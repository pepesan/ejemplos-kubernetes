#!/usr/bin/env bash
set -euo pipefail

# Script para automatizar la inicialización y preparación de LXD en la máquina local

echo "════════════════════════════════════════════════════════════════"
echo "  Iniciando preparación del Host Local (LXD Bootstrap)..."
echo "  Este script instalará LXD, configurará redes y almacenamiento"
echo "  y cargará los módulos del kernel requeridos."
echo "════════════════════════════════════════════════════════════════"
echo ""

# Ejecutar el playbook de Ansible
ansible-playbook 00_bootstrap_host_lxd.yml --ask-become-pass

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  ¡Proceso finalizado!"
echo "  RECUERDA: Ejecuta el comando 'newgrp lxd' o reinicia tu"
echo "  terminal para poder ejecutar comandos 'lxc' sin sudo."
echo "════════════════════════════════════════════════════════════════"
