#!/usr/bin/env bash
set -euo pipefail

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
BUGFIX_NAME="${1:-}"

if [ -z "$BUGFIX_NAME" ]; then
  if [[ "$CURRENT_BRANCH" =~ ^(bugfix|fix)/ ]]; then
    BRANCH_NAME="$CURRENT_BRANCH"
  else
    echo "Error: Debes indicar el nombre del bugfix o estar en una rama bugfix/*."
    echo "Uso: $0 <nombre-bugfix>"
    exit 1
  fi
else
  BUGFIX_NAME="${BUGFIX_NAME#bugfix/}"
  BUGFIX_NAME="${BUGFIX_NAME#fix/}"
  BRANCH_NAME="bugfix/$BUGFIX_NAME"
fi

echo "=== Finalizando bugfix: $BRANCH_NAME ==="

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

echo "✅ Bugfix '$BRANCH_NAME' integrado en 'develop', publicado y eliminado."
