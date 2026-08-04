#!/usr/bin/env bash
set -euo pipefail

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
FEATURE_NAME="${1:-}"

if [ -z "$FEATURE_NAME" ]; then
  if [[ "$CURRENT_BRANCH" =~ ^feature/ ]]; then
    BRANCH_NAME="$CURRENT_BRANCH"
  else
    echo "Error: Debes indicar el nombre de la feature o estar en una rama feature/*."
    echo "Uso: $0 <nombre-feature>"
    exit 1
  fi
else
  FEATURE_NAME="${FEATURE_NAME#feature/}"
  BRANCH_NAME="feature/$FEATURE_NAME"
fi

echo "=== Finalizando feature: $BRANCH_NAME ==="

if ! git rev-parse --verify "$BRANCH_NAME" &>/dev/null; then
  echo "Error: La rama '$BRANCH_NAME' no existe."
  exit 1
fi

git checkout develop
git pull origin develop
git merge --no-ff "$BRANCH_NAME" -m "Merge '$BRANCH_NAME' into develop"
git push origin develop

git branch -d "$BRANCH_NAME" || git branch -D "$BRANCH_NAME"
if git rev-parse --verify "origin/$BRANCH_NAME" &>/dev/null; then
  git push origin --delete "$BRANCH_NAME" || true
fi

echo "✅ Feature '$BRANCH_NAME' integrada en 'develop', publicada y eliminada."
