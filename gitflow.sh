#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Uso: ./gitflow.sh <comando> [subcomando] [nombre]"
  echo ""
  echo "Comandos disponibles:"
  echo "  feature start <nombre>   Crea una nueva rama feature/<nombre> desde develop"
  echo "  feature finish [nombre]  Integra feature en develop, sube a origin y elimina la rama"
  echo "  bugfix start <nombre>    Crea una nueva rama bugfix/<nombre> desde develop"
  echo "  bugfix finish [nombre]   Integra bugfix en develop, sube a origin y elimina la rama"
  echo "  release                  Promociona develop a master y sube a origin"
  echo "  status                   Muestra la rama actual y el estado de Git"
  exit 1
}

CMD="${1:-}"
SUBCMD="${2:-}"
NAME="${3:-}"

case "$CMD" in
  feature)
    case "$SUBCMD" in
      start)  "$SCRIPT_DIR/scripts/gitflow/feature-start.sh" "$NAME" ;;
      finish) "$SCRIPT_DIR/scripts/gitflow/feature-finish.sh" "$NAME" ;;
      *) usage ;;
    esac
    ;;
  bugfix|fix)
    case "$SUBCMD" in
      start)  "$SCRIPT_DIR/scripts/gitflow/bugfix-start.sh" "$NAME" ;;
      finish) "$SCRIPT_DIR/scripts/gitflow/bugfix-finish.sh" "$NAME" ;;
      *) usage ;;
    esac
    ;;
  release)
    "$SCRIPT_DIR/scripts/gitflow/release-master.sh"
    ;;
  status)
    git status
    ;;
  *)
    usage
    ;;
esac
