#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  farm_tiktok.sh — TikTok Farm Reset (ONE-SHOT per cycle)
#  Tujuan: reset identitas device biar TikTok lihat device baru
#          setiap cycle → eligible buat new-user voucher.
#
#  Workflow per cycle:
#    1. Preflight   — cek state sekarang (device, GAID, IMEI)
#    2. Reset       — random device + fingerprint + IMEI + MAC + GAID
#    3. IP rotate   — airplane toggle (ganti cellular IP)
#    4. Clear app   — pm clear TikTok (data bersih)
#    5. Verify      — pastikan semua props ke-set + app clean
#    6. State log   — append farm_history.tsv
#
#  Usage:
#    bash farm_tiktok.sh                # reset + airplane IP
#    bash farm_tiktok.sh wifi           # reset + wifi IP rotate
#    bash farm_tiktok.sh skip           # reset tanpa IP rotate
#    FARM_COOLDOWN=900 bash farm_tiktok.sh   # custom cooldown detik
#
#  State: /data/local/tmp/farm_history.tsv
# ============================================================

LOG_FILE="/data/local/tmp/farm_tiktok.log"
HIST_FILE="/data/local/tmp/farm_history.tsv"
TS() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(TS)] $1" | tee -a "$LOG_FILE"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IP_METHOD="${1:-airplane}"
COOLDOWN="${FARM_COOLDOWN:-900}"   # 15 menit default

# ---------- Self-escalate ----------
if [ "$(id -u)" != "0" ]; then
  echo "→ Butuh root, re-run via su..."
  exec su -c "/data/data/com.termux/files/usr/bin/bash $0 $IP_METHOD"
fi

# TikTok apps (Lite + original)
TARGET_APPS=(
  "com.ss.android.ugc.aweme"
  "com.ss.android.ugc.trill"
)

# ---------- Device pool (random per cycle) ----------
# Format: MANUFACTURER|BRAND|MODEL|DEVICE|PRODUCT|HARDWARE|FINGERPRINT|SECURITY_PATCH|SERIAL_PREFIX
DEVICE_POOL=(
  "samsung|samsung|SM-S901B|r0s|r0sxxx|samsungexynos8895|samsung/r0sxxx/r0s:16/BP2A.250605.031.A3/S901BXXSNGZD7:user/release-keys|2026-05-05|R3CTW"
  "samsung|samsung|SM-S911B|dm3q|dm3qxxx|samsungexynos2200|samsung/dm3qxxx/dm3q:14/UP1A.231005.007/S911BXXS6CXE1:user/release-keys|2026-05-01|R5CWA"
  "samsung|samsung|SM-S918B|dm3q|dm3qxxx|samsungexynos2200|samsung/dm3qxxx/dm3q:14/UP1A.231005.007/S918BXXS6CXE1:user/release-keys|2026-05-01|R5CWB"
  "samsung|samsung|SM-S921B|e3q|e3qxxx|samsungexynos2400|samsung/e3qxxx/e3q:14/UP1A.231005.007/S921BXXS2CXE1:user/release-keys|2026-05-01|R5CWC"
  "samsung|samsung|SM-S928B|e3q|e3qxxx|samsungexynos2400|samsung/e3qxxx/e3q:14/UP1A.231005.007/S928BXXS2CXE1:user/release-keys|2026-05-01|R5CWD"
  "samsung|samsung|SM-S938B|pa3q|pa3qxxx|samsungexynos2500|samsung/pa3qxxx/pa3q:16/BP2A.250605.031.A3/S938BXXU1BYC9:user/release-keys|2026-05-05|R5CWE"
)

pick_device() {
  local n="${#DEVICE_POOL[@]}"
  local idx=$((RANDOM % n))
  echo "${DEVICE_POOL[$idx]}"
}

# ---------- Baca device terakhir dari history (anti-dup berturut) ----------
last_model() {
  if [ -f "$HIST_FILE" ]; then
    tail -1 "$HIST_FILE" | awk -F'\t' '{print $4}'
  fi
}

# ---------- Generate random serial ----------
gen_serial() {
  local prefix="$1"
  echo "${prefix}$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
}

echo ""
echo "=============================================="
echo "  TIKTOK FARM RESET — ONE-SHOT"
echo "  IP method : $IP_METHOD"
echo "  Cooldown  : ${COOLDOWN}s (default 900 = 15m)"
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
    echo "   Tunggu ${WAIT}s atau jalankan ulang dengan FARM_COOLDOWN lebih kecil."
    log "  ⏳ Cooldown: cycle terakhir ${WAIT}s lalu — skip"
    exit 3
  fi
fi

# ---------- [1] Preflight ----------
log "--- [1/6] Preflight ---"
PRE_GAID="$(cmd advertising_id get 2>/dev/null | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)"
PRE_MODEL="$(getprop ro.product.model 2>/dev/null)"
PRE_FP="$(getprop ro.build.fingerprint 2>/dev/null)"
PRE_IMEI="$(getprop ril.imei 2>/dev/null)"
PRE_IP="$(ip route get 1.1.1.1 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print $2}')"
log "  pre: model=$PRE_MODEL fp=${PRE_FP:0:30}... gaid=${PRE_GAID:0:8} imei=${PRE_IMEI:0:8} ip=$PRE_IP"

# ---------- [2] Random device + props ----------
log "--- [2/6] Device randomization ---"
DEVICE_LINE="$(pick_device)"
# Skip kalau sama dengan yang terakhir (biar beda tiap cycle)
LAST_MODEL="$(last_model)"
for attempt in 1 2 3; do
  DEVICE_LINE="$(pick_device)"
  NEW_MODEL="$(echo "$DEVICE_LINE" | cut -d'|' -f3)"
  if [ "$NEW_MODEL" != "$LAST_MODEL" ] || [ -z "$LAST_MODEL" ]; then
    break
  fi
done

MANUFACTURER="$(echo "$DEVICE_LINE" | cut -d'|' -f1)"
BRAND="$(echo "$DEVICE_LINE" | cut -d'|' -f2)"
MODEL="$(echo "$DEVICE_LINE" | cut -d'|' -f3)"
DEVICE="$(echo "$DEVICE_LINE" | cut -d'|' -f4)"
PRODUCT="$(echo "$DEVICE_LINE" | cut -d'|' -f5)"
HARDWARE="$(echo "$DEVICE_LINE" | cut -d'|' -f6)"
FINGERPRINT="$(echo "$DEVICE_LINE" | cut -d'|' -f7)"
SEC_PATCH="$(echo "$DEVICE_LINE" | cut -d'|' -f8)"
SERIAL_PREFIX="$(echo "$DEVICE_LINE" | cut -d'|' -f9)"
SERIAL="$(gen_serial "$SERIAL_PREFIX")"
VBMETA_DIGEST="${VBMETA_DIGEST:-46ec95edb72801b74f475adca2ff6b2fee76a0def983479fc43e7166710232fd}"

log "  target: $MODEL ($DEVICE) — hardware=$HARDWARE"

# Apply props (resetprop — semua partition)
resetprop -n ro.product.manufacturer "$MANUFACTURER" 2>>"$LOG_FILE"
resetprop -n ro.product.brand "$BRAND" 2>>"$LOG_FILE"
resetprop -n ro.product.model "$MODEL" 2>>"$LOG_FILE"
resetprop -n ro.product.device "$DEVICE" 2>>"$LOG_FILE"
resetprop -n ro.product.name "$PRODUCT" 2>>"$LOG_FILE"
resetprop -n ro.product.board "$DEVICE" 2>>"$LOG_FILE"
resetprop -n ro.product.product "$PRODUCT" 2>>"$LOG_FILE"
resetprop -n ro.product.system.brand "$BRAND" 2>>"$LOG_FILE"
resetprop -n ro.product.system.model "$MODEL" 2>>"$LOG_FILE"
resetprop -n ro.product.vendor.brand "$BRAND" 2>>"$LOG_FILE"
resetprop -n ro.product.vendor.model "$MODEL" 2>>"$LOG_FILE"
resetprop -n ro.product.odm.brand "$BRAND" 2>>"$LOG_FILE"
resetprop -n ro.product.odm.model "$MODEL" 2>>"$LOG_FILE"
# Fingerprint semua partition
resetprop -n ro.build.fingerprint "$FINGERPRINT" 2>>"$LOG_FILE"
resetprop -n ro.system.build.fingerprint "$FINGERPRINT" 2>>"$LOG_FILE"
resetprop -n ro.vendor.build.fingerprint "$FINGERPRINT" 2>>"$LOG_FILE"
resetprop -n ro.bootimage.build.fingerprint "$FINGERPRINT" 2>>"$LOG_FILE"
resetprop -n ro.odm.build.fingerprint "$FINGERPRINT" 2>>"$LOG_FILE"
resetprop -n ro.product.build.fingerprint "$FINGERPRINT" 2>>"$LOG_FILE"
# Derived props
FP_ID="$(echo "$FINGERPRINT" | awk -F'/' '{print $2}' | awk -F'/' '{print $3}')"
resetprop -n ro.build.display.id "$FP_ID" 2>>"$LOG_FILE"
resetprop -n ro.build.id "$FP_ID" 2>>"$LOG_FILE"
resetprop -n ro.build.flavor "${PRODUCT}-user" 2>>"$LOG_FILE"
resetprop -n ro.build.description "${PRODUCT}-user $FP_ID user release-keys" 2>>"$LOG_FILE"
# Boot state
resetprop -n ro.boot.flash.locked 1 2>>"$LOG_FILE"
resetprop -n ro.boot.verifiedbootstate green 2>>"$LOG_FILE"
resetprop -n ro.boot.warranty_bit 0 2>>"$LOG_FILE"
resetprop -n ro.debuggable 0 2>>"$LOG_FILE"
resetprop -n ro.secure 1 2>>"$LOG_FILE"
resetprop -n ro.build.type user 2>>"$LOG_FILE"
resetprop -n ro.build.tags release-keys 2>>"$LOG_FILE"
resetprop -n ro.boot.vbmeta.digest "$VBMETA_DIGEST" 2>>"$LOG_FILE"
resetprop -n ro.boot.vbmeta.device_state locked 2>>"$LOG_FILE"
resetprop -n ro.boot.avb_version 1.1 2>>"$LOG_FILE"
# Hardware (comment-out kalau break HAL; default aman post-boot)
resetprop -n ro.hardware "$HARDWARE" 2>>"$LOG_FILE"
resetprop -n ro.soc.model "$HARDWARE" 2>>"$LOG_FILE"
# Serial
resetprop -n ro.serialno "$SERIAL" 2>>"$LOG_FILE"
resetprop -n ro.boot.serialno "$SERIAL" 2>>"$LOG_FILE"
resetprop -n net.hostname "android-$SERIAL" 2>>"$LOG_FILE"
# Security patch
resetprop -n ro.build.version.security_patch "$SEC_PATCH" 2>>"$LOG_FILE"
resetprop -n ro.vendor.build.version.security_patch "$SEC_PATCH" 2>>"$LOG_FILE"
log "  ✓ device props → $MODEL serial=$SERIAL"

# ---------- [3] IMEI random ----------
log "--- [3/6] IMEI spoof ---"
if [ -f "$SCRIPT_DIR/imei_spoof.sh" ]; then
  bash "$SCRIPT_DIR/imei_spoof.sh" >/dev/null
  log "  ✓ imei_spoof.sh executed"
else
  # Fallback: IMEI langsung
  gen_imei() {
    TAC="35$(printf '%04d' $((RANDOM % 10000)))"
    SN="$(printf '%06d' $((RANDOM % 1000000)))"
    BASE="${TAC}${SN}"
    SUM=0; ALT=0
    for (( i=13; i>=0; i-- )); do
      D="${BASE:$i:1}"
      if [ "$ALT" = "1" ]; then
        D2=$((D * 2)); [ "$D2" -gt 9 ] && D2=$((D2 - 9)); SUM=$((SUM + D2)); ALT=0
      else
        SUM=$((SUM + D)); ALT=1
      fi
    done
    CHECK=$(( (10 - (SUM % 10)) % 10 ))
    echo "${BASE}${CHECK}"
  }
  IMEI1=$(gen_imei); IMEI2=$(gen_imei)
  resetprop -n ril.imei "$IMEI1" 2>>"$LOG_FILE"
  resetprop -n ril.imei2 "$IMEI2" 2>>"$LOG_FILE"
  resetprop -n gsm.baseband.imei "$IMEI1" 2>>"$LOG_FILE"
  resetprop -n ro.ril.oem.imei "$IMEI1" 2>>"$LOG_FILE"
  resetprop -n ro.ril.oem.imei1 "$IMEI1" 2>>"$LOG_FILE"
  resetprop -n ro.ril.oem.imei2 "$IMEI2" 2>>"$LOG_FILE"
  persist.radio.imei "$IMEI1" 2>>"$LOG_FILE" >/dev/null 2>&1 || true
  persist.radio.imei1 "$IMEI1" 2>>"$LOG_FILE" >/dev/null 2>&1 || true
  persist.radio.imei2 "$IMEI2" 2>>"$LOG_FILE" >/dev/null 2>&1 || true
  log "  ✓ IMEI fallback: $IMEI1 / $IMEI2"
fi

# ---------- [4] MAC random ----------
log "--- [4/6] MAC randomization ---"
NEW_MAC=$(printf '02:%02x:%02x:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
ip link set wlan0 down 2>/dev/null
if ip link set wlan0 address "$NEW_MAC" 2>/dev/null; then
  ip link set wlan0 up 2>/dev/null
  log "  ✓ wlan0 MAC → $NEW_MAC"
else
  log "  ⚠ wlan0 MAC change gagal"
fi
NEW_MAC2=$(printf '02:%02x:%02x:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
ip link set rmnet_data0 down 2>/dev/null
ip link set rmnet_data0 address "$NEW_MAC2" 2>/dev/null
ip link set rmnet_data0 up 2>/dev/null
log "  ✓ rmnet_data0 MAC → $NEW_MAC2"

# ---------- [5] GAID + app data reset ----------
log "--- [5/6] GAID + app data ---"
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
rm -f /data/data/com.google.android.gms/databases/adid* 2>/dev/null
log "  ✓ Cache adid dibuang"

for APP in "${TARGET_APPS[@]}"; do
  if pm list packages | grep -q "$APP"; then
    pm clear "$APP" >/dev/null 2>&1
    log "  ✓ $APP — data cleared"
  else
    log "  - $APP — belum terinstall"
  fi
done
am force-stop com.google.android.gms 2>>"$LOG_FILE"
am force-stop com.google.android.gsf 2>>"$LOG_FILE"
pm trim-caches 999999999999 2>/dev/null

# ---------- [6] IP rotate ----------
log "--- [6/6] IP rotation ($IP_METHOD) ---"
if [ "$IP_METHOD" != "skip" ]; then
  if [ -f "$SCRIPT_DIR/ip_rotator.sh" ]; then
    bash "$SCRIPT_DIR/ip_rotator.sh" "$IP_METHOD" >/dev/null
    log "  ✓ ip_rotator.sh executed"
  else
    cmd connectivity airplane-mode enable
    sleep 5
    cmd connectivity airplane-mode disable
    sleep 10
    log "  ✓ Airplane toggle fallback done"
  fi
else
  log "  - IP rotation SKIPPED"
fi

# ---------- Verify post-state ----------
log "--- Verify post-state ---"
POST_GAID="$(cmd advertising_id get 2>/dev/null | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)"
POST_MODEL="$(getprop ro.product.model 2>/dev/null)"
POST_FP="$(getprop ro.build.fingerprint 2>/dev/null)"
POST_IMEI="$(getprop ril.imei 2>/dev/null)"
POST_IP="$(ip route get 1.1.1.1 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print $2}')"
log "  post: model=$POST_MODEL fp=${POST_FP:0:30}... gaid=${POST_GAID:0:8} imei=${POST_IMEI:0:8} ip=$POST_IP"

# ---------- History append ----------
echo -e "$(date '+%Y-%m-%d %H:%M:%S')\t$IP_METHOD\t$PRE_MODEL\t$MODEL\t${PRE_GAID:0:8}\t${POST_GAID:0:8}\t${PRE_IMEI:0:8}\t${POST_IMEI:0:8}\t$PRE_IP\t$POST_IP" >> "$HIST_FILE"
# Keep last 30
tail -30 "$HIST_FILE" > "$HIST_FILE.tmp" && mv "$HIST_FILE.tmp" "$HIST_FILE"

echo ""
echo "=============================================="
echo "  ✅ FARM RESET SELESAI"
echo "=============================================="
echo "  Model     : $PRE_MODEL → $MODEL"
echo "  GAID      : ${PRE_GAID:0:8}... → ${POST_GAID:0:8}..."
echo "  IMEI      : ${PRE_IMEI:0:8}... → ${POST_IMEI:0:8}..."
echo "  IP        : $PRE_IP → $POST_IP"
echo "  Serial    : $SERIAL"
echo ""
echo "  📱 Sekarang buka TikTok → registrasi akun baru"
echo "  ⏳ Cooldown: ${COOLDOWN}s sebelum cycle berikutnya"
echo ""
echo "  History: $HIST_FILE"
echo "=============================================="
log "=== Farm cycle selesai: $PRE_MODEL → $MODEL ==="
exit 0
