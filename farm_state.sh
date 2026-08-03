#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  farm_state.sh — TikTok Farm History Viewer
#  Lihat history cycle + current state device.
#
#  Usage:
#    bash farm_state.sh           # 10 terakhir
#    bash farm_state.sh 20        # 20 terakhir
#    bash farm_state.sh all       # semua
#    bash farm_state.sh current   # current state aja (no history)
# ============================================================

HIST_FILE="/data/local/tmp/farm_history.tsv"
LOG_FILE="/data/local/tmp/farm_tiktok.log"
TS() { date '+%Y-%m-%d %H:%M:%S'; }

if [ "$(id -u)" != "0" ]; then
  echo "→ Butuh root untuk baca device state, re-run via su..."
  exec su -c "/data/data/com.termux/files/usr/bin/bash $0 $1"
fi

# ---------- Current state ----------
show_current() {
  echo "=============================================="
  echo "  📱 CURRENT DEVICE STATE"
  echo "  (snapshot: $(TS))"
  echo "=============================================="
  MODEL=$(getprop ro.product.model 2>/dev/null)
  BRAND=$(getprop ro.product.brand 2>/dev/null)
  HARDWARE=$(getprop ro.hardware 2>/dev/null)
  FP=$(getprop ro.build.fingerprint 2>/dev/null)
  IMEI=$(getprop ril.imei 2>/dev/null)
  SERIAL=$(getprop ro.serialno 2>/dev/null)
  GAID=$(cmd advertising_id get 2>/dev/null | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)
  MAC=$(ip link show wlan0 2>/dev/null | grep -oE 'link/ether [0-9a-f:]+' | awk '{print $2}')
  IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print $2}')
  VBSTATE=$(getprop ro.boot.verifiedbootstate 2>/dev/null)
  SEC_PATCH=$(getprop ro.build.version.security_patch 2>/dev/null)

  echo ""
  echo "  Model         : $MODEL ($BRAND)"
  echo "  Hardware      : $HARDWARE"
  echo "  Fingerprint   : $FP"
  echo "  Serial        : $SERIAL"
  echo "  IMEI (props)  : ${IMEI:0:8}... (Luhn-valid 15-digit)"
  echo "  GAID          : $GAID"
  echo "  MAC wlan0     : $MAC"
  echo "  IP            : $IP"
  echo "  Boot state    : $VBSTATE"
  echo "  Security patch: $SEC_PATCH"
  echo ""
  echo "  ⚠️  IMEI via TelephonyManager.getImei() masih ASLI"
  echo "     (butuh LSPosed + Android Faker untuk 100% spoof)"
  echo ""
  echo "=============================================="
}

# ---------- History viewer ----------
show_history() {
  local n="${1:-10}"
  if [ "$n" = "all" ]; then n=9999; fi

  if [ ! -f "$HIST_FILE" ]; then
    echo ""
    echo "  (Belum ada history — jalankan farm_tiktok.sh dulu)"
    echo ""
    return
  fi

  echo ""
  echo "=============================================="
  echo "  📜 FARM HISTORY (last $n cycles)"
  echo "=============================================="
  printf '%-20s %-10s %-15s → %-15s %-10s → %-10s\n' "Timestamp" "IP" "Model lama" "Model baru" "GAID" "IMEI"
  echo "----------------------------------------------------------------------------------------------------"

  tail -n "$n" "$HIST_FILE" 2>/dev/null | while IFS=$'\t' read -r ts ip pm nm pg ng pi ni _ _; do
    printf '%-20s %-10s %-15s → %-15s %-10s → %-10s\n' \
      "$ts" "$ip" "$pm" "$nm" "${pg}..." "${pi}..."
  done

  echo ""
  echo "  Full history: $HIST_FILE"
  echo ""
}

# ---------- Latest log ----------
show_log_tail() {
  if [ -f "$LOG_FILE" ]; then
    echo "=============================================="
    echo "  📋 LAST LOG (farm_tiktok.log)"
    echo "=============================================="
    tail -15 "$LOG_FILE"
    echo ""
  fi
}

# ---------- Main ----------
case "${1:-}" in
  current|c)
    show_current
    ;;
  all|a)
    show_current
    show_history "all"
    show_log_tail
    ;;
  "")
    show_current
    show_history "10"
    show_log_tail
    ;;
  *)
    show_current
    show_history "$1"
    ;;
esac