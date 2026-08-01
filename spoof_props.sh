#!/system/bin/sh
# ============================================================
#  spoof_props.sh — Spoof Build Fingerprint + Device Props
#  GANTI DeviceSpoofLab / MagiskHide Props Config (100% sendiri)
#  Cara kerja: resetprop (built-in Magisk) override props
#  Jalan : sekali manual, atau taruh di /data/adb/service.d/
#          biar auto-jalan tiap boot
#  Usage : bash spoof_props.sh  (as root / via su)
# ============================================================

LOG_FILE="/data/local/tmp/spoof_props.log"
TS() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(TS)] $1" | tee -a "$LOG_FILE"; }

# ---------- Self-escalate ----------
if [ "$(id -u)" != "0" ]; then
  echo "→ Butuh root, re-run via su..."
  exec su -c "sh $0"
fi

# ============================================================
#  KONFIGURASI TARGET DEVICE — edit di sini
#  Default: Samsung Galaxy S25 Ultra (SM-S938B)
#  Mau device lain? Ganti semua value di bawah
# ============================================================
TGT_MANUFACTURER="samsung"
TGT_BRAND="samsung"
TGT_MODEL="SM-S938B"
TGT_DEVICE="pa3q"
TGT_PRODUCT="pa3qxxx"
TGT_HARDWARE="qcom"                       # S25 Ultra pake Snapdragon 8 Elite
TGT_FINGERPRINT="samsung/pa3qxxx/pa3q:16/BP2A.250605.031.A3/S938BXXU1BYC9:user/release-keys"
TGT_SECURITY_PATCH="2026-05-05"
TGT_SERIAL="R3CTW$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"

# ============================================================
#  EKSEKUSI
# ============================================================
log "=== Spoof props dimulai (target: $TGT_MODEL) ==="

# --- 1. Core identity ---
resetprop -n ro.product.manufacturer "$TGT_MANUFACTURER" 2>>"$LOG_FILE"
resetprop -n ro.product.brand "$TGT_BRAND" 2>>"$LOG_FILE"
resetprop -n ro.product.model "$TGT_MODEL" 2>>"$LOG_FILE"
resetprop -n ro.product.device "$TGT_DEVICE" 2>>"$LOG_FILE"
resetprop -n ro.product.name "$TGT_PRODUCT" 2>>"$LOG_FILE"
resetprop -n ro.product.board "$TGT_DEVICE" 2>>"$LOG_FILE"
resetprop -n ro.product.product "$TGT_PRODUCT" 2>>"$LOG_FILE"
resetprop -n ro.product.system.brand "$TGT_BRAND" 2>>"$LOG_FILE"
resetprop -n ro.product.system.model "$TGT_MODEL" 2>>"$LOG_FILE"
resetprop -n ro.product.vendor.brand "$TGT_BRAND" 2>>"$LOG_FILE"
resetprop -n ro.product.vendor.model "$TGT_MODEL" 2>>"$LOG_FILE"
resetprop -n ro.product.odm.brand "$TGT_BRAND" 2>>"$LOG_FILE"
resetprop -n ro.product.odm.model "$TGT_MODEL" 2>>"$LOG_FILE"
log "  ✓ product identity → $TGT_MODEL"

# --- 2. Fingerprint (semua partition) ---
resetprop -n ro.build.fingerprint "$TGT_FINGERPRINT" 2>>"$LOG_FILE"
resetprop -n ro.system.build.fingerprint "$TGT_FINGERPRINT" 2>>"$LOG_FILE"
resetprop -n ro.vendor.build.fingerprint "$TGT_FINGERPRINT" 2>>"$LOG_FILE"
resetprop -n ro.bootimage.build.fingerprint "$TGT_FINGERPRINT" 2>>"$LOG_FILE"
resetprop -n ro.odm.build.fingerprint "$TGT_FINGERPRINT" 2>>"$LOG_FILE"
resetprop -n ro.product.build.fingerprint "$TGT_FINGERPRINT" 2>>"$LOG_FILE"
# Props turunan biar konsisten
FP_ID="$(echo "$TGT_FINGERPRINT" | awk -F'/' '{print $2}' | awk -F'/' '{print $3}')"
resetprop -n ro.build.display.id "$FP_ID" 2>>"$LOG_FILE"
resetprop -n ro.build.id "$FP_ID" 2>>"$LOG_FILE"
resetprop -n ro.build.flavor "${TGT_PRODUCT}-user" 2>>"$LOG_FILE"
resetprop -n ro.build.description "${TGT_PRODUCT}-user $FP_ID user release-keys" 2>>"$LOG_FILE"
log "  ✓ fingerprint → $TGT_MODEL"

# --- 3. Boot state (konsisten dgn TrickyStore) ---
resetprop -n ro.boot.flash.locked 1 2>>"$LOG_FILE"
resetprop -n ro.boot.verifiedbootstate green 2>>"$LOG_FILE"
resetprop -n ro.boot.warranty_bit 0 2>>"$LOG_FILE"
resetprop -n ro.debuggable 0 2>>"$LOG_FILE"
resetprop -n ro.secure 1 2>>"$LOG_FILE"
resetprop -n ro.build.type user 2>>"$LOG_FILE"
resetprop -n ro.build.tags release-keys 2>>"$LOG_FILE"
log "  ✓ boot state: locked + green + user build"

# --- 4. Hardware (⚠️ opsional — bisa ganggu app system tertentu) ---
# Hati-hati: ro.hardware dipakai system buat load HAL.
# Setelah boot, aman untuk sebagian besar kasus. Kalau ada
# app crash / rendering error, comment baris ini.
# resetprop -n ro.hardware "$TGT_HARDWARE" 2>>"$LOG_FILE"
# resetprop -n ro.soc.model "SM8750" 2>>"$LOG_FILE"
# log "  ✓ hardware → $TGT_HARDWARE"

# --- 5. Serial & hostname ---
resetprop -n ro.serialno "$TGT_SERIAL" 2>>"$LOG_FILE"
resetprop -n ro.boot.serialno "$TGT_SERIAL" 2>>"$LOG_FILE"
resetprop -n net.hostname "android-$TGT_SERIAL" 2>>"$LOG_FILE"
log "  ✓ serial → $TGT_SERIAL"

# --- 6. Security patch ---
resetprop -n ro.build.version.security_patch "$TGT_SECURITY_PATCH" 2>>"$LOG_FILE"
resetprop -n ro.vendor.build.version.security_patch "$TGT_SECURITY_PATCH" 2>>"$LOG_FILE"
log "  ✓ security patch → $TGT_SECURITY_PATCH"

# --- 7. Clear Play Services cache biar baca ulang props ---
am force-stop com.google.android.gms 2>>"$LOG_FILE"
am force-stop com.google.android.gsf 2>>"$LOG_FILE"
log "=== Selesai. Restart app target biar baca props baru ==="
echo ""
echo "✅ Props spoofed → $TGT_MODEL"
echo "   Verifikasi: getprop ro.build.fingerprint"
echo "   Auto-boot  : cp spoof_props.sh /data/adb/service.d/ && chmod 755"
