#!/system/bin/sh
# ============================================================
#  ip_rotator.sh — Rotate IP Address tanpa VPN berbayar
#  Metode:
#    1. WiFi toggle — DHCP lease drop & reconnect (kebanyakan
#       ISP kasih IP baru kalo lease expired)
#    2. Mobile data airplane toggle — modem release IP lama
#  Usage : bash ip_rotator.sh
# ============================================================

LOG_FILE="/data/local/tmp/ip_rotator.log"
TS() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(TS)] $1" | tee -a "$LOG_FILE"; }

if [ "$(id -u)" != "0" ]; then
  echo "→ Butuh root, re-run via su..."
  exec su -c "/data/data/com.termux/files/usr/bin/bash $0"
fi

METHOD="${1:-wifi}"   # default wifi, atau: airplane | all

log "=== IP rotator (method: $METHOD) ==="

# ---------- METODE 1: WiFi DHCP rotation ----------
wifi_rotate() {
  log "  → WiFi DHCP re-connect"
  OLD_IP=$(ip -4 addr show wlan0 2>/dev/null | grep inet | awk '{print $2}' | head -1)
  log "    IP lama: $OLD_IP"

  svc wifi disable 2>>"$LOG_FILE"
  sleep 3
  svc wifi enable 2>>"$LOG_FILE"
  log "  → WiFi disabled, tunggu re-connect..."
  sleep 8

  NEW_IP=$(ip -4 addr show wlan0 2>/dev/null | grep inet | awk '{print $2}' | head -1)
  if [ "$OLD_IP" = "$NEW_IP" ] && [ -n "$OLD_IP" ]; then
    log "    ⚠ IP sama ($NEW_IP) — ISP lock lease. Coba airplane mode..."
    airplane_rotate
  else
    log "    ✓ IP baru: $NEW_IP"
  fi
}

# ---------- METODE 2: Airplane toggle (paling reliable) ----------
airplane_rotate() {
  log "  → Airplane toggle (15s)"
  cmd connectivity airplane-mode enable 2>>"$LOG_FILE"
  sleep 5
  # Reset koneksi data
  svc data disable 2>>"$LOG_FILE"
  svc wifi disable 2>>"$LOG_FILE"
  sleep 5
  cmd connectivity airplane-mode disable 2>>"$LOG_FILE"
  sleep 3
  svc data enable 2>>"$LOG_FILE"
  log "  → Modem reconnecting..."
  sleep 15

  # Force re-dial PDP (dial-up data)
  svc data disable 2>>"$LOG_FILE"
  svc data enable 2>>"$LOG_FILE"
  sleep 8

  NEW_IP=$(ip -4 addr show rmnet_data0 2>/dev/null | grep inet | awk '{print $2}' | head -1)
  log "    ✓ IP cellular baru: ${NEW_IP:-<unknown>}"
}

# ---------- METODE 3: Combo wifi + airplane ----------
all_rotate() {
  wifi_rotate
  log "  → Tunggu 10s..."
  sleep 10
  airplane_rotate
}

# ---------- Pilih metode ----------
case "$METHOD" in
  wifi)      wifi_rotate ;;
  airplane)  airplane_rotate ;;
  all)
    all_rotate
    ;;
  *)
    echo "Usage: $0 [wifi|airplane|all]"
    echo "  wifi       → WiFi DHCP re-connect"
    echo "  airplane   → airplane toggle (paling reliable)"
    echo "  all        → wifi + airplane combo"
    exit 1
    ;;
esac

# ---------- Verifikasi ----------
log "=== Verifikasi ==="
INTERNAL=$(ip -4 addr show 2>/dev/null | grep -E "wlan0|rmnet" | grep inet | awk '{print $2}')
log "  Internal IP: ${INTERNAL:-<none>}"
EXT_IP=$(curl -s --max-time 8 https://api.ipify.org 2>/dev/null)
log "  Public IP: ${EXT_IP:-<no-net>}"
log "=== Selesai ==="
