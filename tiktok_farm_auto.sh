#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  tiktok_farm_auto.sh — FULL AUTO TikTok Farm Cycle
#  ============================================================
#  Satu command buat cycle lengkap:
#    1. Uninstall total TikTok (data + obb + user data)
#    2. Reset identitas device (random model, IMEI, GAID, AID, MAC, IP)
#    3. Install APK TikTok (dari /sdcard — bukan Play Store)
#    4. Log state + instruksi klaim voucher
#
#  PRASYARAT:
#    • COPG module terinstall + patched Pro (udah punya)
#    • APK TikTok di /sdcard/Download/tiktok.apk
#    • Termux root (su -c id = uid=0)
#
#  Usage:
#    bash tiktok_farm_auto.sh
#    bash tiktok_farm_auto.sh wifi        # IP method: wifi|airplane|skip
#    FARM_COOLDOWN=300 bash tiktok_farm_auto.sh   # custom cooldown detik
# ============================================================

set -e

LOG_FILE="/data/local/tmp/tiktok_farm.log"
HIST_FILE="/data/local/tmp/farm_history.tsv"
TS() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(TS)] $1" | tee -a "$LOG_FILE"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IP_METHOD="${1:-airplane}"
COOLDOWN="${FARM_COOLDOWN:-900}"   # 15 menit default
APK_PATH="${TIKTOK_APK:-/sdcard/Download/tiktok.apk}"

TIKTOK_PKGS=(
  "com.ss.android.ugc.aweme"
  "com.ss.android.ugc.trill"
)

# ---------- Self-escalate ----------
if [ "$(id -u)" != "0" ]; then
  echo "→ Butuh root, re-run via su..."
  exec su -c "/data/data/com.termux/files/usr/bin/bash $0 $IP_METHOD"
fi

echo ""
echo "=============================================="
echo "  TIKTOK FARM — FULL AUTO"
echo "  IP method : $IP_METHOD"
echo "  Cooldown  : ${COOLDOWN}s"
echo "  APK       : $APK_PATH"
echo "=============================================="
log "=== Farm cycle dimulai (IP: $IP_METHOD, cooldown: ${COOLDOWN}s) ==="

# ---------- [0] Cooldown check ----------
LAST_TS=""
if [ -f "$HIST_FILE" ]; then
  LAST_TS="$(tail -1 "$HIST_FILE" | awk -F'\t' '{print $1" "$2}')"
fi
if [ -n "$LAST_TS" ]; then
  LAST_EPOCH="$(date -d "$LAST_TS" +%s 2>/dev/null)"
  NOW_EPOCH="$(date +%s)"
  if [ -n "$LAST_EPOCH" ] && [ $((NOW_EPOCH - LAST_EPOCH)) -lt "$COOLDOWN" ]; then
    WAIT=$((COOLDOWN - (NOW_EPOCH - LAST_EPOCH)))
    echo "⏳ Cooldown aktif — cycle terakhir ${WAIT}s lalu."
    echo "   Tunggu ${WAIT}s atau set FARM_COOLDOWN lebih kecil."
    log "  ⏳ Cooldown: cycle terakhir ${WAIT}s lalu — skip"
    exit 3
  fi
fi

# ---------- [1] Pre-state ----------
log "--- [1/6] Pre-state ---"
PRE_MODEL="$(getprop ro.product.model 2>/dev/null)"
PRE_GAID="$(cmd advertising_id get 2>/dev/null | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)"
PRE_IP="$(ip route get 1.1.1.1 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print $2}')"
log "  pre: model=$PRE_MODEL gaid=${PRE_GAID:0:8} ip=$PRE_IP"

# ---------- [2] Uninstall total TikTok ----------
log "--- [2/6] Uninstall total TikTok ---"
for PKG in "${TIKTOK_PKGS[@]}"; do
  if pm list packages | grep -q "$PKG"; then
    pm uninstall "$PKG" >/dev/null 2>&1 && log "  ✓ $PKG uninstalled" || log "  ✗ $PKG uninstall gagal"
  else
    log "  - $PKG belum terinstall"
  fi
done
# Bersihkan sisa data manual (kalau pm uninstall gak hapus sempurna)
rm -rf /data/data/com.ss.android.ugc.aweme 2>/dev/null
rm -rf /data/data/com.ss.android.ugc.trill 2>/dev/null
rm -rf /storage/emulated/0/Android/data/com.ss.android.ugc.aweme 2>/dev/null
rm -rf /storage/emulated/0/Android/data/com.ss.android.ugc.trill 2>/dev/null
rm -rf /storage/emulated/0/Android/obb/com.ss.android.ugc.aweme 2>/dev/null
rm -rf /storage/emulated/0/Android/obb/com.ss.android.ugc.trill 2>/dev/null
log "  ✓ sisa data dihapus"

# ---------- [3] Reset identitas ----------
log "--- [3/6] Reset identitas ---"
if [ -f "$SCRIPT_DIR/farm_tiktok.sh" ]; then
  bash "$SCRIPT_DIR/farm_tiktok.sh" "$IP_METHOD" 2>&1 | tail -8 | while read -r line; do log "  farm: $line"; done
elif [ -f "$SCRIPT_DIR/reset_identity.sh" ]; then
  bash "$SCRIPT_DIR/reset_identity.sh" "$IP_METHOD" >/dev/null 2>&1
  log "  ✓ reset_identity.sh executed"
else
  log "  ✗ farm_tiktok.sh / reset_identity.sh gak ada — skip reset"
fi

# ---------- [4] Install APK ----------
log "--- [4/6] Install APK TikTok ---"
if [ -f "$APK_PATH" ]; then
  if pm install "$APK_PATH" >/dev/null 2>&1; then
    log "  ✓ APK terinstall: $APK_PATH"
  else
    log "  ✗ Install gagal — coba dengan --user 0:"
    if pm install -r --user 0 "$APK_PATH" >/dev/null 2>&1; then
      log "  ✓ APK terinstall (--user 0): $APK_PATH"
    else
      log "  ✗ Install tetap gagal — periksa APK / storage permission"
      echo "  ❌ Install APK gagal. Cek: su -c 'pm install /sdcard/Download/tiktok.apk'"
    fi
  fi
else
  log "  ✗ APK gak ditemukan: $APK_PATH"
  echo "  ❌ APK gak ada di $APK_PATH"
  echo "     Taruh APK TikTok di /sdcard/Download/tiktok.apk dulu"
  echo "     (download dari tiktok.com/download atau apkpure)"
fi

# ---------- [5] Verify ----------
log "--- [5/6] Verify ---"
POST_MODEL="$(getprop ro.product.model 2>/dev/null)"
POST_GAID="$(cmd advertising_id get 2>/dev/null | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)"
POST_IP="$(ip route get 1.1.1.1 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print $2}')"
TT_INSTALLED=0
for PKG in "${TIKTOK_PKGS[@]}"; do
  if pm list packages | grep -q "$PKG"; then TT_INSTALLED=1; fi
done
log "  post: model=$POST_MODEL gaid=${POST_GAID:0:8} ip=$POST_IP tiktok_installed=$TT_INSTALLED"

# ---------- [6] History + summary ----------
echo -e "$(date '+%Y-%m-%d %H:%M:%S')\t$IP_METHOD\t$PRE_MODEL\t$POST_MODEL\t${PRE_GAID:0:8}\t${POST_GAID:0:8}\t-\t-\t$PRE_IP\t$POST_IP" >> "$HIST_FILE"
tail -30 "$HIST_FILE" > "$HIST_FILE.tmp" && mv "$HIST_FILE.tmp" "$HIST_FILE"

echo ""
echo "=============================================="
echo "  ✅ FARM CYCLE SELESAI"
echo "=============================================="
echo "  Model   : $PRE_MODEL → $POST_MODEL"
echo "  GAID    : ${PRE_GAID:0:8}... → ${POST_GAID:0:8}..."
echo "  IP      : $PRE_IP → $POST_IP"
echo "  TikTok  : $([ "$TT_INSTALLED" = "1" ] && echo "terinstall ✅" || echo "BELUM ❌")"
echo ""
echo "  📱 NEXT STEPS (manual):"
echo "  1. Buka TikTok → registrasi akun BARU"
echo "  2. Verifikasi nomor (OTP SMS)"
echo "  3. Scroll feed 1-2 menit → buka TikTok Shop"
echo "  4. Cek banner 'New User' → tap Claim voucher"
echo "  5. Voucher muncul di Shop > Wallet > Voucher"
echo ""
echo "  ⏳ Cooldown: ${COOLDOWN}s sebelum cycle berikutnya"
echo "  Log: $LOG_FILE | History: $HIST_FILE"
echo "=============================================="
log "=== Farm cycle selesai ==="
exit 0
