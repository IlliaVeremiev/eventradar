#!/bin/bash
# EventRadar development server manager.
#
# Runs API and frontend dev servers in a detached tmux session.
# Each service gets its own named window; output is tee'd to ~/.<service>.log.
#
# Usage: start-dev.sh [start|stop|restart|status|logs [api|frontend]|attach|help]
#
# This script lives in the eventradar repo root. API and frontend are expected
# at ./api and ./frontend relative to the script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$SCRIPT_DIR/api"
FRONTEND_DIR="$SCRIPT_DIR/frontend"
SESSION="eventradar"
API_LOG="$HOME/.eventradar-api.log"
FRONTEND_LOG="$HOME/.eventradar-frontend.log"

GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'; BLUE=$'\033[0;34m'; NC=$'\033[0m'
ok()   { echo "${GREEN}✓${NC} $*"; }
info() { echo "${BLUE}→${NC} $*"; }
warn() { echo "${YELLOW}!${NC} $*"; }
err()  { echo "${RED}✗${NC} $*" >&2; }

running() { tmux has-session -t "$SESSION" 2>/dev/null; }

start() {
  if running; then
    warn "Session '$SESSION' already running — use 'restart' to recycle."
    return
  fi

  info "Starting API..."
  tmux new-session -d -s "$SESSION" -n api -c "$API_DIR" \
    "composer run dev 2>&1 | tee -a '$API_LOG'"

  info "Starting frontend..."
  tmux new-window -t "$SESSION" -n frontend -c "$FRONTEND_DIR" \
    "npm run dev 2>&1 | tee -a '$FRONTEND_LOG'"

  tmux select-window -t "$SESSION:api"
  sleep 1

  if running; then
    ok "Started."
    status
  else
    err "Session failed to start — check: $API_LOG"
    exit 1
  fi
}

stop() {
  if running; then
    info "Stopping '$SESSION'..."
    tmux kill-session -t "$SESSION"
    pkill -f "artisan serve"        2>/dev/null || true
    pkill -f "artisan queue:listen" 2>/dev/null || true
    pkill -f "artisan pail"         2>/dev/null || true
    ok "Stopped."
  else
    info "Nothing to stop."
  fi
}

status() {
  echo
  if running; then
    ok "Session '$SESSION' is running"
    echo "   API      → http://localhost:8000"
    echo "   Admin    → http://localhost:8000/admin"
    echo "   Frontend → http://localhost:5174"
    echo "   Logs     → $(basename "$0") logs [api|frontend]"
    echo "   Attach   → $(basename "$0") attach"
  else
    warn "Not running — start with: $(basename "$0") start"
  fi
  echo
}

logs() {
  local svc="${1:-api}"
  local file
  case "$svc" in
    api)      file="$API_LOG" ;;
    frontend) file="$FRONTEND_LOG" ;;
    *)        err "Unknown service: $svc (api|frontend)"; exit 1 ;;
  esac
  [[ -f "$file" ]] || { err "No log file yet: $file — is the session running?"; exit 1; }
  tail -n 100 -f "$file"
}

attach() {
  running || { err "Not running."; exit 1; }
  exec tmux attach -t "$SESSION"
}

usage() {
  cat <<EOF
EventRadar dev server manager

Usage: $(basename "$0") [command]

Commands:
  start               Start API + frontend in a detached tmux session  [default]
  stop                Kill the tmux session
  restart             Stop then start
  status              Show running state and service URLs
  logs [api|frontend] Tail service log (default: api)
  attach              Attach to tmux session (detach: Ctrl-b d)
  help                This message
EOF
}

command -v tmux >/dev/null || { err "tmux is required"; exit 1; }

case "${1:-start}" in
  start)          start ;;
  stop)           stop ;;
  restart)        stop; sleep 1; start ;;
  status)         status ;;
  logs)           logs "${2:-api}" ;;
  attach)         attach ;;
  help|-h|--help) usage ;;
  *)              err "Unknown command: $1"; echo; usage; exit 1 ;;
esac
