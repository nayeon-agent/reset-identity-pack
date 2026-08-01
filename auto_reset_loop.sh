#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  auto_reset_loop.sh — Daemon loop reset identity periodik
#  Usage : bash auto_reset_loop.sh [interval_detik]
#          default = 600 detik (10 menit)
#  Stop  : killall auto_reset_loop.sh
# ============================================================

INTERVAL="${1:-600}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESET_SCRIPT="$SCRIPT_DIR/reset_identity.sh"
PIDFILE="/data/local/tmp/auto_reset_loop.pid"
LOG="/data/local/tmp/reset_identity.log"

trap 'rm -f "$PIDFILE"; echo "[$(date +%H:%M:%S)] daemon stopped" >> "$LOG"; exit 0' INT TERM

echo "$$" > "$PIDFILE"
echo "=============================================="
echo "  Auto Reset Daemon Started"
echo "  Interval: ${INTERVAL}s"
echo "  PID: $$"
echo "  Stop: killall auto_reset_loop.sh"
echo "=============================================="

while true; do
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Auto-reset triggered" >> "$LOG"
  # Pakai IP method 'wifi' default; ganti ke 'airplane' lebih reliable
  bash "$RESET_SCRIPT" wifi >> "$LOG" 2>&1
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sleep ${INTERVAL}s..." >> "$LOG"
  sleep "$INTERVAL"
done
