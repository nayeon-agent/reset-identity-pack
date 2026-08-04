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
#
#  DEBUG: bash -x tiktok_farm_auto.sh 2>&1 | tail -80
# ============================================================

LOG_FILE="/data/local/tmp/tiktok_farm.log"
HIST_FILE="/data/local/tmp/farm_history.tsv"
TS() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(TS)] $1" | tee -a "$LOG_FILE"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IP_METHOD="${1:-airplane}"
COOLDOWN="${FARM_COOLDOWN:-900}"   # 15 menit default

# Smart APK detection: cek beberapa path umum
if [ -n "${TIKTOK_APK:-}" ]; then
  APK_PATH="$TIKTOK_APK"
elif [ -f "/sdcard/Download/tiktok.apk" ]; then
  APK_PATH="/sdcard/Download/tiktok.apk"
elif [ -f "/storage/emulated/0/Download/tiktok.apk" ]; then
  APK_PATH="/storage/emulated/0/Download/tiktok.apk"
elif [ -f "/storage/downloads/tiktok.apk" ]; then
  APK_PATH="/storage/downloads/tiktok.apk"
elif [ -f "$HOME/storage/downloads/tiktok.apk" ]; then
  APK_PATH="$HOME/storage/downloads/tiktok.apk"
else
  APK_PATH="/sdcard/Download/tiktok.apk"
fi

TIKTOK_PKGS=(
  "com.ss.android.ugc.aweme"
  "com.ss.android.ugc.trill"
)

# timeout wrapper — cegah hang pada command yang bisa block
T() { timeout 5 "$@" 2>/dev/null; }

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

# ---------- [0] Cooldown check (simpel, non-blocking) ----------
if [ -f "$HIST_FILE" ]; then
  LAST_LINE="$(tail -1 "$HIST_FILE" 2>/dev/null)"
  LAST_TS_STR="$(echo "$LAST_LINE" | cut -d'	' -f1,2)"
  if [ -n "$LAST_TS_STR" ]; then
    LAST_EPOCH="$(T date -d "$LAST_TS_STR" +%s)"
    NOW_EPOCH="$(date +%s)"
    if [ -n "$LAST_EPOCH" ] && [ $((NOW_EPOCH - LAST_EPOCH)) -lt "$COOLDOWN" ]; then
      WAIT=$((COOLDOWN - (NOW_EPOCH - LAST_EPOCH)))
      echo "⏳ Cooldown aktif — cycle terakhir ${WAIT}s lalu."
      echo "   Tunggu ${WAIT}s atau set FARM_COOLDOWN lebih kecil."
      log "  ⏳ Cooldown: cycle terakhir ${WAIT}s lalu — skip"
      exit 3
    fi
  fi
fi
echo "  ✓ Cooldown check passed"

# ---------- [1] Pre-state (dengan timeout, non-blocking) ----------
echo "  [1/6] Pre-state..."
PRE_MODEL="$(T getprop ro.product.model)"
PRE_GAID="$(T cmd advertising_id get | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)"
PRE_IP="$(T ip route get 1.1.1.1 | grep -oE 'src [0-9.]+' | awk '{print $2}')"
log "  pre: model=$PRE_MODEL gaid=${PRE_GAID:0:8} ip=$PRE_IP"
echo "  ✓ pre-state: model=$PRE_MODEL ip=$PRE_IP"

# ---------- [2] Uninstall total TikTok ----------
echo "  [2/6] Uninstall total TikTok..."
for PKG in "${TIKTOK_PKGS[@]}"; do
  if pm list packages 2>/dev/null | grep -q "$PKG"; then
    pm uninstall "$PKG" >/dev/null 2>&1 && log "  ✓ $PKG uninstalled" || log "  ✗ $PKG uninstall gagal"
  else
    log "  - $PKG belum terinstall"
  fi
done
rm -rf /data/data/com.ss.android.ugc.aweme /data/data/com.ss.android.ugc.trill 2>/dev/null
rm -rf /storage/emulated/0/Android/data/com.ss.android.ugc.aweme /storage/emulated/0/Android/data/com.ss.android.ugc.trill 2>/dev/null
rm -rf /storage/emulated/0/Android/obb/com.ss.android.ugc.aweme /storage/emulated/0/Android/obb/com.ss.android.ugc.trill 2>/dev/null
log "  ✓ sisa data dihapus"
echo "  ✓ uninstall done"

# ---------- [3] Reset identitas ----------
echo "  [3/6] Reset identitas..."
if [ -f "$SCRIPT_DIR/farm_tiktok.sh" ]; then
  bash "$SCRIPT_DIR/farm_tiktok.sh" "$IP_METHOD" >/dev/null 2>&1
  log "  ✓ farm_tiktok.sh executed"
elif [ -f "$SCRIPT_DIR/reset_identity.sh" ]; then
  bash "$SCRIPT_DIR/reset_identity.sh" "$IP_METHOD" >/dev/null 2>&1
  log "  ✓ reset_identity.sh executed"
else
  log "  ✗ farm/reset script gak ada — skip reset"
fi
echo "  ✓ reset done"

# ---------- [4] Install APK ----------
echo "  [4/6] Install APK TikTok..."
STAGE_APK="/data/local/tmp/tiktok_stage.apk"
STAGED=0
if [ -f "$APK_PATH" ]; then
  # Android 11+ storage namespace: pm (shell su) hanya bisa akses /data/local/tmp/
  # Stage APK ke /data/local/tmp/ biar pm install bisa baca file
  echo "  → staging APK ke $STAGE_APK..."
  if cp "$APK_PATH" "$STAGE_APK" 2>/dev/null; then
    STAGED=1
  else
    # Fallback: copy via root (kalau cp gagal karena permission)
    if su -c "cp '$APK_PATH' '$STAGE_APK' 2>/dev/null"; then
      su -c "chmod 644 '$STAGE_APK' 2>/dev/null"
      STAGED=1
    fi
  fi
  if [ "$STAGED" = "1" ]; then
    if pm install "$STAGE_APK" >/dev/null 2>&1; then
      log "  ✓ APK terinstall: $APK_PATH"
    elif pm install -r --user 0 "$STAGE_APK" >/dev/null 2>&1; then
      log "  ✓ APK terinstall (--user 0): $APK_PATH"
    else
      log "  ✗ Install gagal — periksa APK / signature"
      echo "  ❌ Install gagal. Coba manual: su -c 'pm install $STAGE_APK'"
    fi
    # Cleanup staged APK
    rm -f "$STAGE_APK" 2>/dev/null
  else
    log "  ✗ Gagal copy APK ke $STAGE_APK"
    echo "  ❌ Copy APK gagal. Coba manual:"
    echo "     su -c 'cp \"\$APK_PATH\" $STAGE_APK'"
    echo "     su -c 'pm install $STAGE_APK'"
  fi
else
  log "  ✗ APK gak ditemukan: $APK_PATH"
  echo "  ❌ APK gak ada. Taruh di salah satu:"
  echo "     /sdcard/Download/tiktok.apk"
  echo "     /storage/emulated/0/Download/tiktok.apk"
  echo "     /storage/downloads/tiktok.apk"
fi

# ---------- [5] Verify ----------
echo "  [5/6] Verify..."
POST_MODEL="$(T getprop ro.product.model)"
POST_GAID="$(T cmd advertising_id get | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)"
POST_IP="$(T ip route get 1.1.1.1 | grep -oE 'src [0-9.]+' | awk '{print $2}')"
TT_INSTALLED=0
for PKG in "${TIKTOK_PKGS[@]}"; do
  if pm list packages 2>/dev/null | grep -q "$PKG"; then TT_INSTALLED=1; fi
done
log "  post: model=$POST_MODEL gaid=${POST_GAID:0:8} ip=$POST_IP tiktok_installed=$TT_INSTALLED"

# ---------- [6] History + summary ----------
echo -e "$(date '+%Y-%m-%d %H:%M:%S')\t$IP_METHOD\t$PRE_MODEL\t$POST_MODEL\t${PRE_GAID:0:8}\t${POST_GAID:0:8}\t-\t-\t$PRE_IP\t$POST_IP" >> "$HIST_FILE" 2>/dev/null
tail -30 "$HIST_FILE" > "$HIST_FILE.tmp" 2>/dev/null && mv "$HIST_FILE.tmp" "$HIST_FILE" 2>/dev/null

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
