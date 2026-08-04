#!/usr/bin/env bash
set -euo pipefail

FEATURE_NAME="${1:-}"

if [ -z "$FEATURE_NAME" ]; then
  echo "Error: Debes indicar el nombre de la feature."
  echo "Uso: $0 <nombre-feature>"
  exit 1
fi

FEATURE_NAME="${FEATURE_NAME#feature/}"
BRANCH_NAME="feature/$FEATURE_NAME"

echo "=== Iniciando nueva feature: $BRANCH_NAME ==="
git checkout develop
git pull origin develop
git checkout -b "$BRANCH_NAME"
echo "✅ Rama '$BRANCH_NAME' creada y lista para trabajar."
