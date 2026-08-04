#!/usr/bin/env bash
set -euo pipefail

BUGFIX_NAME="${1:-}"

if [ -z "$BUGFIX_NAME" ]; then
  echo "Error: Debes indicar el nombre del bugfix."
  echo "Uso: $0 <nombre-bugfix>"
  exit 1
fi

BUGFIX_NAME="${BUGFIX_NAME#bugfix/}"
BUGFIX_NAME="${BUGFIX_NAME#fix/}"
BRANCH_NAME="bugfix/$BUGFIX_NAME"

echo "=== Iniciando nuevo bugfix: $BRANCH_NAME ==="
git checkout develop
git pull origin develop
git checkout -b "$BRANCH_NAME"
echo "✅ Rama '$BRANCH_NAME' creada y lista para trabajar."
