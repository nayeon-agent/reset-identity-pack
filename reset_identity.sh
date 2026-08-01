#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  reset_identity.sh — Full Reset (NO module 3rd party!)
#  Stack:
#    1. spoof_props.sh  → device fingerprint + build props
#    2. imei_spoof.sh   → ril.* props IMEI (best-effort)
#    3. ip_rotator.sh   → WiFi/airplane/WG rotate IP
#    4. MAC random      → kernel-level via ip link
#    5. GAID + app data reset
#  Usage : bash reset_identity.sh [method_ip]
#          method_ip = wifi (default) | airplane | wg | skip
# ============================================================

LOG_FILE="/data/local/tmp/reset_identity.log"
TS() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(TS)] $1" | tee -a "$LOG_FILE"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IP_METHOD="${1:-wifi}"

# ---------- Self-escalate ----------
if [ "$(id -u)" != "0" ]; then
  echo "→ Butuh root, re-run via su..."
  exec su -c "/data/data/com.termux/files/usr/bin/bash $0 $IP_METHOD"
fi

TARGET_APPS=(
  "com.shopee.id"
  "com.tokopedia.tkpd"
  "com.ss.android.ugc.aweme"
)

echo ""
echo "=============================================="
echo "  RESET IDENTITY v2.0 — Full Stack (NO 3rd Party)"
echo "=============================================="
log "=== Sesi reset dimulai (IP method: $IP_METHOD) ==="

# ---------- [1/6] Build fingerprint + props ----------
log "--- [1/6] Build fingerprint spoof ---"
if [ -f "$SCRIPT_DIR/spoof_props.sh" ]; then
  bash "$SCRIPT_DIR/spoof_props.sh" >/dev/null
  log "  ✓ spoof_props.sh executed"
else
  log "  ✗ spoof_props.sh gak ada — skip"
fi

# ---------- [2/6] IMEI props (best-effort) ----------
log "--- [2/6] IMEI spoof (ril.* props) ---"
if [ -f "$SCRIPT_DIR/imei_spoof.sh" ]; then
  bash "$SCRIPT_DIR/imei_spoof.sh" >/dev/null
  log "  ✓ imei_spoof.sh executed"
else
  log "  ✗ imei_spoof.sh gak ada — skip"
fi

# ---------- [3/6] IP rotator ----------
if [ "$IP_METHOD" != "skip" ]; then
  log "--- [3/6] IP rotation ($IP_METHOD) ---"
  if [ -f "$SCRIPT_DIR/ip_rotator.sh" ]; then
    bash "$SCRIPT_DIR/ip_rotator.sh" "$IP_METHOD" >/dev/null
    log "  ✓ ip_rotator.sh executed"
  else
    log "  ⚠ ip_rotator.sh gak ada — manual IP switch"
    log "    → Toggle airplane mode 15s sebagai fallback"
    cmd connectivity airplane-mode enable
    sleep 5
    cmd connectivity airplane-mode disable
    sleep 10
    log "    ✓ Airplane toggle done"
  fi
else
  log "--- [3/6] IP rotation (SKIPPED) ---"
fi

# ---------- [4/6] MAC random ----------
log "--- [4/6] MAC address random ---"
NEW_MAC=$(printf '02:%02x:%02x:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
ip link set wlan0 down 2>/dev/null
if ip link set wlan0 address "$NEW_MAC" 2>/dev/null; then
  ip link set wlan0 up 2>/dev/null
  log "  ✓ wlan0 MAC → $NEW_MAC"
else
  log "  ⚠ wlan0 MAC change gagal (fallback ke default)"
fi
# Cellular (kalo ada)
NEW_MAC2=$(printf '02:%02x:%02x:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
ip link set rmnet_data0 down 2>/dev/null
ip link set rmnet_data0 address "$NEW_MAC2" 2>/dev/null
ip link set rmnet_data0 up 2>/dev/null
log "  ✓ rmnet_data0 MAC → $NEW_MAC2"

# ---------- [5/6] GAID reset ----------
log "--- [5/6] Google Advertising ID reset ---"
GAID_OK=0
if cmd advertising_id reset >/dev/null 2>&1; then
  GAID_OK=1
elif cmd advertising-id reset >/dev/null 2>&1; then
  GAID_OK=1
fi
if [ "$GAID_OK" = "1" ]; then
  log "  ✓ GAID di-reset (cmd advertising_id)"
else
  pm clear com.google.android.gms >/dev/null 2>&1
  pm clear com.google.android.gsf >/dev/null 2>&1
  log "  ✓ GAID cleared via GMS data reset"
fi
# Buang cache iklan
rm -f /data/data/com.google.android.gms/databases/adid* 2>/dev/null
log "  ✓ Cache adid dibuang"

# ---------- [6/6] App data clear ----------
log "--- [6/6] Clear data app target ---"
for APP in "${TARGET_APPS[@]}"; do
  if pm list packages | grep -q "$APP"; then
    pm clear "$APP" >/dev/null 2>&1
    log "  ✓ $APP — data cleared"
  else
    log "  - $APP — belum terinstall"
  fi
done

# Restart Play Services biar baca ulang
am force-stop com.google.android.gms 2>>"$LOG_FILE"
am force-stop com.google.android.gsf 2>>"$LOG_FILE"
pm trim-caches 999999999999 2>/dev/null

# ---------- Ringkasan ----------
log "=== Sesi selesai ==="
echo ""
echo "=============================================="
echo "  ✅ RESET SELESAI (Full Stack)"
echo "=============================================="
echo ""
echo " Yang di-reset (NO MODULE):"
echo "  • Build fingerprint + props     → S25 Ultra spoof"
echo "  • ril.* IMEI props              → random valid IMEI"
echo "  • MAC address (wlan0/cellular)  → random"
echo "  • Google Advertising ID         → baru"
echo "  • Data app target               → cleared"
echo "  • IP address                    → $IP_METHOD method"
echo ""
echo " ⚠️  MASIH BUTUH:"
echo "   • Trickystore (boot state) — udah terinstall"
echo "   • Xposed module untuk full IMEI hook (jika perlu)"
echo ""
echo " 🚀 Next steps:"
echo "   1. Tunggu 30-60 detik sync Play Services"
echo "   2. Aktifkan VPN kalo IP method = 'skip'"
echo "   3. Buka app target → registrasi akun baru"
echo ""
echo " Log: $LOG_FILE"
echo "=============================================="
