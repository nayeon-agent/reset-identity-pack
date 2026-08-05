#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  tunnel.sh — Reverse SSH tunnel auto-reconnect (Termux)
#  Connect: HP -> VPS 43.134.224.16
#  Forward: VPS:2222 -> HP:8022 (sshd Termux)
#
#  Usage:
#    bash ~/tunnel.sh start    # start daemon + auto-reconnect
#    bash ~/tunnel.sh stop     # stop daemon
#    bash ~/tunnel.sh status   # cek status
# ============================================================

VPS_HOST="43.134.224.16"
VPS_USER="ubuntu"
VPS_PORT="2222"
HP_SSH_PORT="8022"

TUNNEL_PID_FILE="$HOME/.tunnel.pid"

start_tunnel() {
  # Kill existing tunnel
  stop_tunnel

  echo "Starting tunnel to $VPS_USER@$VPS_HOST (forward $VPS_PORT -> 127.0.0.1:$HP_SSH_PORT)..."

  # Auto-reconnect loop
  nohup bash -c "
    while true; do
      ssh -N -R 127.0.0.1:$VPS_PORT:127.0.0.1:$HP_SSH_PORT \
        -o ServerAliveInterval=30 \
        -o ServerAliveCountMax=3 \
        -o ExitOnForwardFailure=yes \
        -o ConnectTimeout=10 \
        $VPS_USER@$VPS_HOST
      echo \"[\$(date '+%H:%M:%S')] tunnel dropped, reconnect in 5s...\" >> \$HOME/.tunnel.log
      sleep 5
    done
  " > /dev/null 2>&1 &
  TUNNEL_PID=$!
  echo $TUNNEL_PID > "$TUNNEL_PID_FILE"
  echo "Tunnel started (PID $TUNNEL_PID)"
  echo "Log: \$HOME/.tunnel.log"
}

stop_tunnel() {
  if [ -f "$TUNNEL_PID_FILE" ]; then
    kill "$(cat "$TUNNEL_PID_FILE")" 2>/dev/null
    rm -f "$TUNNEL_PID_FILE"
  fi
  pkill -f "ssh -N -R" 2>/dev/null
  echo "Tunnel stopped"
}

status_tunnel() {
  if [ -f "$TUNNEL_PID_FILE" ]; then
    PID="$(cat "$TUNNEL_PID_FILE")"
    if kill -0 "$PID" 2>/dev/null; then
      echo "Tunnel RUNNING (PID $PID)"
    else
      echo "Tunnel process dead (PID $PID)"
    fi
  else
    echo "Tunnel NOT running"
  fi
  echo "--- log tail ---"
  tail -5 "$HOME/.tunnel.log" 2>/dev/null || echo "(no log)"
}

case "${1:-help}" in
  start) start_tunnel ;;
  stop) stop_tunnel ;;
  status) status_tunnel ;;
  *) echo "Usage: $0 {start|stop|status}" ;;
esac