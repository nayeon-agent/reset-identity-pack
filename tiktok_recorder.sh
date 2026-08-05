#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  tiktok_recorder.sh — TikTok Activity + Network Recorder
#  Rekam semua signal yang TikTok kirim/terima
#  Untuk analisa kapan "new user" eligibility server-side trigger
#
#  Usage (di HP, via su):
#    su -c "/data/data/com.termux/files/home/spoof/tiktok_recorder.sh start"
#    ... buka TikTok, scroll, daftar akun, klaim voucher ...
#    su -c "/data/data/com.termux/files/home/spoof/tiktok_recorder.sh stop"
#    su -c "/data/data/com.termux/files/home/spoof/tiktok_recorder.sh status"
#    su -c "/data/data/com.termux/files/home/spoof/tiktok_recorder.sh dump"
#
#  Output:
#    /sdcard/tiktok_recorder/<session-TS>/
#      - activity.log      (app transitions, login events)
#      - network.log       (TCP/HTTPS endpoints + response codes)
#      - events.log        (key events: login, voucher claim, register)
#      - summary.txt       (ringkasan sesi)
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_ROOT="/sdcard/tiktok_recorder"
TIKTOK_PKG="com.ss.android.ugc.trill"

mkdir -p "$OUT_ROOT"

# Reuse running session if exists
SESSION_DIR=""
for d in "$OUT_ROOT"/*/; do
  if [ -f "$d/.running" ]; then
    SESSION_DIR="${d%/}"
    break
  fi
done

if [ -z "$SESSION_DIR" ]; then
  ts_id="$(date '+%Y%m%d_%H%M%S')"
  SESSION_DIR="$OUT_ROOT/$ts_id"
  mkdir -p "$SESSION_DIR"
fi

# State files
ACTIVITY_LOG="$SESSION_DIR/activity.log"
NETWORK_LOG="$SESSION_DIR/network.log"
EVENTS_LOG="$SESSION_DIR/events.log"
SUMMARY="$SESSION_DIR/summary.txt"
LOGCAT_RAW="$SESSION_DIR/logcat_raw.log"
TCPDUMP_PCAP="$SESSION_DIR/network.pcap"

# Process IDs
LOGCAT_PID=""
TCPDUMP_PID=""

# ---------- Self-escalate ----------
if [ "$(id -u)" != "0" ]; then
  echo "→ Re-running via su..."
  exec su -c "/data/data/com.termux/files/usr/bin/bash $0 $*"
fi

ACTION="${1:-help}"

start_recording() {
  if [ -f "$SESSION_DIR/.running" ]; then
    echo "Recorder udah jalan di: $SESSION_DIR"
    return 0
  fi

  echo "=============================================="
  echo "  TIKTOK RECORDER — START"
  echo "  Session: $SESSION_DIR"
  echo "=============================================="

  touch "$SESSION_DIR/.running"
  echo "Session start: $(date)" > "$SUMMARY"
  echo "TikTok package: $TIKTOK_PKG" >> "$SUMMARY"
  echo "" >> "$SUMMARY"

  # [1] Logcat: filter ke TikTok activity
  logcat -c  # clear buffer
  logcat -v threadtime \
    "*:S" \
    "ActivityTaskManager:I" \
    "ActivityManager:I" \
    "PackageManager:I" \
    "AwemeApp:I" \
    "TT-Voucher:V" \
    "TT-Login:V" \
    "TikTok:V" \
    "$TIKTOK_PKG:V" \
    "com.ss.android.ugc:V" \
    "Bytedance:V" \
    > "$LOGCAT_RAW" 2>/dev/null &
  LOGCAT_PID=$!
  echo $LOGCAT_PID > "$SESSION_DIR/.logcat_pid"

  # [2] Activity monitor: track app foreground/background + activity transitions
  (
    while [ -f "$SESSION_DIR/.running" ]; do
      TOP_ACTIVITY="$(dumpsys activity activities 2>/dev/null | grep -oE "topResumedActivity=ActivityRecord\{[a-z0-9]+ u0 $TIKTOK_PKG/[a-zA-Z0-9.]+}" | head -1)"
      if [ -n "$TOP_ACTIVITY" ]; then
        TS="$(date '+%Y-%m-%d %H:%M:%S')"
        ACTIVITY_NAME="$(echo "$TOP_ACTIVITY" | grep -oE "[a-zA-Z0-9.]+$")"
        PREV_ACTIVITY="$(tail -1 "$ACTIVITY_LOG" 2>/dev/null | awk '{print $NF}')"
        if [ "$ACTIVITY_NAME" != "$PREV_ACTIVITY" ]; then
          echo "$TS [ACTIVITY] top=$ACTIVITY_NAME" >> "$ACTIVITY_LOG"
        fi
      else
        # cek background/foreground
        TS="$(date '+%Y-%m-%d %H:%M:%S')"
        PREV="$(tail -1 "$ACTIVITY_LOG" 2>/dev/null | awk '{print $NF}')"
        if [ "$PREV" != "BACKGROUND" ] && [ -n "$PREV" ]; then
          echo "$TS [ACTIVITY] top=BACKGROUND" >> "$ACTIVITY_LOG"
        fi
      fi
      sleep 1
    done
  ) &
  ACTIVITY_PID=$!
  echo $ACTIVITY_PID > "$SESSION_DIR/.activity_pid"

  # [3] Network monitor: tcpdump capture (semua ke/dari TikTok process)
  TIKTOK_PID="$(pidof $TIKTOK_PKG 2>/dev/null)"
  if [ -n "$TIKTOK_PID" ]; then
    tcpdump -i any \
      -w "$TCPDUMP_PCAP" \
      -Z root \
      "host not 127.0.0.1 and (tcp or udp)" \
      > /dev/null 2>&1 &
    TCPDUMP_PID=$!
    echo $TCPDUMP_PID > "$SESSION_DIR/.tcpdump_pid"
    echo "[$ts_id] [NET] tcpdump PID=$TCPDUMP_PID for app PID=$TIKTOK_PID" >> "$NETWORK_LOG"
  else
    echo "[$ts_id] [NET] TikTok belum jalan, tcpdump global capture" >> "$NETWORK_LOG"
    tcpdump -i any -w "$TCPDUMP_PCAP" -Z root > /dev/null 2>&1 &
    TCPDUMP_PID=$!
    echo $TCPDUMP_PID > "$SESSION_DIR/.tcpdump_pid"
  fi

  echo ""
  echo "✅ Recorder running. Buka TikTok & lakukan tindakan."
  echo "   Activity log:  $ACTIVITY_LOG"
  echo "   Network pcap:  $TCPDUMP_PCAP"
  echo "   Events log:    $EVENTS_LOG"
  echo ""
  echo "   Stop dengan:  bash $SCRIPT_DIR/tiktok_recorder.sh stop"
}

stop_recording() {
  echo "=============================================="
  echo "  TIKTOK RECORDER — STOP"
  echo "=============================================="
  if [ ! -f "$SESSION_DIR/.running" ]; then
    echo "Recorder gak jalan."
    return 1
  fi

  # Stop processes
  [ -f "$SESSION_DIR/.logcat_pid" ] && kill "$(cat "$SESSION_DIR/.logcat_pid")" 2>/dev/null || true
  [ -f "$SESSION_DIR/.activity_pid" ] && kill "$(cat "$SESSION_DIR/.activity_pid")" 2>/dev/null || true
  [ -f "$SESSION_DIR/.tcpdump_pid" ] && kill "$(cat "$SESSION_DIR/.tcpdump_pid")" 2>/dev/null || true
  rm -f "$SESSION_DIR/.running" "$SESSION_DIR/"*.pid

  # Generate summary
  DURATION="$(stat -c %Y "$LOGCAT_RAW" 2>/dev/null) - $(stat -c %W "$LOGCAT_RAW" 2>/dev/null)" || true
  echo "Session end: $(date)" >> "$SUMMARY"
  echo "" >> "$SUMMARY"
  echo "=== ACTIVITY TRANSITIONS ===" >> "$SUMMARY"
  cat "$ACTIVITY_LOG" 2>/dev/null | tail -50 >> "$SUMMARY"
  echo "" >> "$SUMMARY"
  echo "=== KEY EVENTS ===" >> "$SUMMARY"
  grep -E "login|voucher|register|claim|signup" "$EVENTS_LOG" 2>/dev/null >> "$SUMMARY" || echo "(none captured)" >> "$SUMMARY"
  echo "" >> "$SUMMARY"
  echo "=== FILE SIZES ===" >> "$SUMMARY"
  ls -la "$SESSION_DIR" >> "$SUMMARY"

  echo ""
  echo "✅ Recording stopped."
  echo "   Session: $SESSION_DIR"
  echo "   Summary: $SUMMARY"
  echo ""
  echo "   Kirim folder ini ke aku untuk analisa:"
  echo "   ls -la $SESSION_DIR"
}

status_recording() {
  if [ -f "$SESSION_DIR/.running" ]; then
    echo "Recorder RUNNING. Session: $SESSION_DIR"
    [ -f "$SESSION_DIR/.logcat_pid" ] && echo "  logcat PID: $(cat "$SESSION_DIR/.logcat_pid")"
    [ -f "$SESSION_DIR/.tcpdump_pid" ] && echo "  tcpdump PID: $(cat "$SESSION_DIR/.tcpdump_pid")"
  else
    echo "Recorder NOT running."
    echo "Last session: $SESSION_DIR"
  fi
}

dump_recording() {
  echo "=== ACTIVITY LOG (last 30) ==="
  tail -30 "$ACTIVITY_LOG" 2>/dev/null || echo "(empty)"
  echo ""
  echo "=== EVENTS LOG ==="
  cat "$EVENTS_LOG" 2>/dev/null || echo "(empty)"
  echo ""
  echo "=== SUMMARY ==="
  cat "$SUMMARY" 2>/dev/null || echo "(empty)"
}

case "$ACTION" in
  start)
    start_recording
    ;;
  stop)
    stop_recording
    ;;
  status)
    status_recording
    ;;
  dump)
    dump_recording
    ;;
  *)
    echo "Usage: $0 {start|stop|status|dump}"
    echo ""
    echo "  start — mulai recording TikTok activity + network"
    echo "  stop  — stop recording + generate summary"
    echo "  status — cek status recorder"
    echo "  dump  — tampilkan log terakhir"
    ;;
esac