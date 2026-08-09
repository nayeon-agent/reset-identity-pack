#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  fix_full_build_leak.sh — Hapus SEMUA leak build.prop
#  ============================================================
#  Issue hp Oppa (probe 2026-08-09 live):
#    [UN1CA ROM markers]
#      ro.unica.codename=Poseidon, ro.unica.version=1.0.1-fa49be90
#      persist.sys.unica.bootsound=true, keybox=true, pif=true, vulkan=false
#    [Note 8 codename leaks]
#      ro.build.flavor=greatltexx-user
#      ro.vendor/odm/vendor_dlkm.build.fingerprint = samsung/greatltexx/...:9/...
#      ro.product.vendor.model=SM-N950F, ro.product.odm.model=SM-N950F
#      ro.product.vendor.name=greatltexx, ro.product.odm.name=greatltexx
#      ro.product.vendor_dlkm.model=SM-N950F, ro.product.vendor_dlkm.name=greatltexx
#      ro.build.product=essi (S22 = r0s, essi = wrong codename)
#      ro.boot.bootloader=N950FXXUGDVG5, ro.boot.em.model=SM-N950F
#      gsm.version.baseband=N950FXXSGDUG6, ril.product_code=SM-N950FZKDXSP
#      selinux.policy_version=SEPF_SM-N950F_13_0001
#      ro.quick_start.device_id=SM-N950
#    [essi mismatch]
#      ro.system/system_ext/product.build.fingerprint = .../essi:16/...
#      ro.product.system.device=essi, ro.product.system_ext.device=essi
#      ro.product.product.device=essi
#
#  Fix: samain ke S22 (r0sxxx) + hapus semua unica marker.
#  Catatan:
#    - resetprop -d (delete) hanya bisa untuk ro.* (read-only props).
#      persist.* dipakai oleh system services; set ke "" (empty)
#      adalah best-effort yang aman — gak nge-break boot.
#    - gsm/ril baseband props DIBIARKAN — baseband adalah hardware
#      fingerprint asli modem; mengubahnya bisa nge-break telepon.
#      Detector (DuckDetector) umumnya gak nge-flag baseband karena
#      gak bisa diubah normal.
#    - selinux.policy_version juga DIBIARKAN (kernel-level, gak bisa).
#
#  Usage:
#    bash fix_full_build_leak.sh           # apply fix
#    bash fix_full_build_leak.sh check     # cek doang, no fix
#    bash fix_full_build_leak.sh install   # taruh di /data/adb/service.d/ auto-boot
#    bash fix_full_build_leak.sh remove    # hapus dari service.d
# ============================================================

# ---------- Self-escalate ----------
if [ "$(id -u)" != "0" ]; then
  echo "→ Butuh root, re-run via su..."
  exec su -c "/data/data/com.termux/files/usr/bin/bash $0 $*"
fi

MODE="${1:-apply}"
LOG_FILE="/data/local/tmp/fix_full_build_leak.log"
TS() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(TS)] $1" | tee -a "$LOG_FILE"; }

# ---------- Target (S22 SM-S901B — samain dgn fix_dd_residue.sh) ----------
TGT_MODEL="SM-S901B"
TGT_PRODUCT="r0sxxx"
TGT_DEVICE="r0s"
TGT_BUILD_ID="BP2A.250605.031.A3"
TGT_FINGERPRINT="samsung/r0sxxx/r0s:16/BP2A.250605.031.A3/S901BXXSNGZD7:user/release-keys"
TGT_BUILD_HOST="21DN2919"
TGT_BUILD_USER="dpi"
TGT_SECURITY_PATCH="2026-05-05"

# Marker yang harus HILANG (UN1CA + Note 8 codename)
LEAK_PROPS=(
  "ro.unica.codename"
  "ro.unica.version"
  "persist.sys.unica.bootsound"
  "persist.sys.unica.keybox"
  "persist.sys.unica.pif"
  "persist.sys.unica.vulkan"
)

# Props yang harus di-SET ke nilai S22 (bukan dihapus)
FIX_PROPS_MODEL=(
  "ro.product.vendor.model"
  "ro.product.odm.model"
  "ro.product.vendor_dlkm.model"
  "ro.product.system_ext.model"
)
FIX_PROPS_NAME=(
  "ro.product.vendor.name"
  "ro.product.odm.name"
  "ro.product.vendor_dlkm.name"
  "ro.product.system_ext.name"
)
FIX_PROPS_DEVICE=(
  "ro.product.system.device"
  "ro.product.system_ext.device"
  "ro.product.product.device"
  "ro.build.product"
)
FIX_PROPS_BRAND=(
  "ro.product.vendor.brand"
  "ro.product.odm.brand"
  "ro.product.vendor_dlkm.brand"
  "ro.product.system_ext.brand"
)
FIX_PROPS_MANUFACTURER=(
  "ro.product.vendor.manufacturer"
  "ro.product.odm.manufacturer"
  "ro.product.vendor_dlkm.manufacturer"
  "ro.product.system_ext.manufacturer"
)

log "=== fix_full_build_leak.sh (mode=$MODE) ==="

# ============================================================
#  APPLY
# ============================================================
if [ "$MODE" = "apply" ] || [ "$MODE" = "fix" ]; then
  log "--- [1/6] Hapus UN1CA / Note 8 leak markers ---"
  for prop in "${LEAK_PROPS[@]}"; do
    CURRENT="$(getprop "$prop" 2>/dev/null)"
    if [ -n "$CURRENT" ]; then
      if [[ "$prop" == persist.* ]]; then
        setprop "$prop" "" 2>/dev/null && \
          log "  ✓ $prop cleared (was: $CURRENT)" || \
          log "  ✗ $prop gagal clear"
      else
        resetprop -d "$prop" 2>/dev/null && \
          log "  ✓ $prop deleted (was: $CURRENT)" || \
          resetprop -n "$prop" "" 2>/dev/null && log "  ✓ $prop = empty (fallback)" || \
          log "  ✗ $prop gagal"
      fi
    else
      log "  - $prop udah kosong (skip)"
    fi
  done

  log "--- [2/6] Set fingerprint ALL partitions ke S22 ---"
  for prop in \
    ro.build.fingerprint \
    ro.system.build.fingerprint \
    ro.system_ext.build.fingerprint \
    ro.vendor.build.fingerprint \
    ro.odm.build.fingerprint \
    ro.product.build.fingerprint \
    ro.vendor_dlkm.build.fingerprint; do
    resetprop -n "$prop" "$TGT_FINGERPRINT" 2>>"$LOG_FILE" && \
      log "  ✓ $prop" || \
      log "  ✗ $prop gagal"
  done

  log "--- [3/6] Fix device/model/name/brand/manufacturer (vendor/odm/dlkm) ---"
  for prop in "${FIX_PROPS_MODEL[@]}"; do
    resetprop -n "$prop" "$TGT_MODEL" 2>>"$LOG_FILE" && log "  ✓ $prop=$TGT_MODEL" || log "  ✗ $prop"
  done
  for prop in "${FIX_PROPS_NAME[@]}"; do
    resetprop -n "$prop" "$TGT_PRODUCT" 2>>"$LOG_FILE" && log "  ✓ $prop=$TGT_PRODUCT" || log "  ✗ $prop"
  done
  for prop in "${FIX_PROPS_DEVICE[@]}"; do
    resetprop -n "$prop" "$TGT_DEVICE" 2>>"$LOG_FILE" && log "  ✓ $prop=$TGT_DEVICE" || log "  ✗ $prop"
  done
  for prop in "${FIX_PROPS_BRAND[@]}"; do
    resetprop -n "$prop" "samsung" 2>>"$LOG_FILE" && log "  ✓ $prop=samsung" || log "  ✗ $prop"
  done
  for prop in "${FIX_PROPS_MANUFACTURER[@]}"; do
    resetprop -n "$prop" "samsung" 2>>"$LOG_FILE" && log "  ✓ $prop=samsung" || log "  ✗ $prop"
  done

  log "--- [4/6] Fix flavor + description + display + build.id ---"
  resetprop -n ro.build.flavor "${TGT_PRODUCT}-user" 2>>"$LOG_FILE" && \
    log "  ✓ ro.build.flavor → r0sxxx-user" || log "  ✗ flavor"
  resetprop -n ro.build.description "${TGT_PRODUCT}-user 16 ${TGT_BUILD_ID} S901BXXSNGZD7 release-keys" 2>>"$LOG_FILE" && \
    log "  ✓ ro.build.description" || log "  ✗ description"
  resetprop -n ro.build.display.id "${TGT_BUILD_ID}.S901BXXSNGZD7" 2>>"$LOG_FILE" && \
    log "  ✓ ro.build.display.id" || log "  ✗ display.id"
  resetprop -n ro.build.id "$TGT_BUILD_ID" 2>>"$LOG_FILE" && \
    log "  ✓ ro.build.id" || log "  ✗ build.id"

  log "--- [5/6] Fix bootloader + host/user + secpatch + device_name ---"
  resetprop -n ro.boot.bootloader "$TGT_BUILD_ID" 2>>"$LOG_FILE" && \
    log "  ✓ ro.boot.bootloader" || log "  ✗ bootloader"
  resetprop -n ro.boot.em.model "$TGT_MODEL" 2>>"$LOG_FILE" && \
    log "  ✓ ro.boot.em.model" || log "  ✗ em.model"
  resetprop -n ro.build.host "$TGT_BUILD_HOST" 2>>"$LOG_FILE" && \
    log "  ✓ ro.build.host" || log "  ✗ host"
  resetprop -n ro.build.user "$TGT_BUILD_USER" 2>>"$LOG_FILE" && \
    log "  ✓ ro.build.user" || log "  ✗ user"
  resetprop -n ro.build.version.security_patch "$TGT_SECURITY_PATCH" 2>>"$LOG_FILE" && \
    log "  ✓ ro.build.version.security_patch" || log "  ✗ secpatch"
  # device_name udah SM-S901B (probe), cek ulang biar aman
  DN="$(settings get global device_name 2>/dev/null)"
  if echo "$DN" | grep -qE "Note8|N950|Note 8"; then
    settings put global device_name "$TGT_MODEL" 2>/dev/null && \
      log "  ✓ global device_name → $TGT_MODEL (was: $DN)" || log "  ✗ device_name"
  else
    log "  - global device_name udah clean (skip)"
  fi

  log "--- [6/6] Clear GMS cache + selesai ---"
  am force-stop com.google.android.gms 2>/dev/null
  am force-stop com.google.android.gsf 2>/dev/null
  log "  ✓ GMS + GSF force-stop"
fi

# ============================================================
#  INSTALL / REMOVE (auto-boot)
# ============================================================
if [ "$MODE" = "install" ]; then
  log "--- Install ke /data/adb/service.d/ ---"
  SRC="$(cd "$(dirname "$0")" && pwd)/fix_full_build_leak.sh"
  DST="/data/adb/service.d/fix_full_build_leak.sh"
  cp "$SRC" "$DST" 2>/dev/null && chmod 755 "$DST" 2>/dev/null && \
    log "  ✓ Installed: $DST (auto-run tiap boot)" || \
    log "  ✗ Install gagal"
  echo ""
  echo "✅ Auto-boot aktif. Script jalan tiap boot late_start."
  echo "   Uninstall: bash $0 remove"
  exit 0
fi

if [ "$MODE" = "remove" ]; then
  log "--- Hapus dari /data/adb/service.d/ ---"
  rm -f /data/adb/service.d/fix_full_build_leak.sh 2>/dev/null && \
    log "  ✓ Removed" || \
    log "  ✗ Remove gagal (file belum ada?)"
  exit 0
fi

# ============================================================
#  VERIFY (always)
# ============================================================
echo ""
echo "=== FULL BUILD-LEAK VERIFY ==="
FAIL=0

# 1. UN1CA markers
echo "--- UN1CA markers (harus KOSONG) ---"
for prop in "${LEAK_PROPS[@]}"; do
  V="$(getprop "$prop" 2>/dev/null)"
  if [ -z "$V" ]; then
    echo "  ✅ $prop (kosong)"
  else
    echo "  ❌ $prop = $V (LEAK!)"
    FAIL=$((FAIL+1))
  fi
done

# 2. Fingerprint partitions
echo "--- Fingerprint (semua partition harus S22 r0sxxx/r0s) ---"
for prop in \
  ro.build.fingerprint \
  ro.system.build.fingerprint \
  ro.system_ext.build.fingerprint \
  ro.vendor.build.fingerprint \
  ro.odm.build.fingerprint \
  ro.product.build.fingerprint \
  ro.vendor_dlkm.build.fingerprint; do
  V="$(getprop "$prop" 2>/dev/null)"
  if [ "$V" = "$TGT_FINGERPRINT" ]; then
    echo "  ✅ $prop = S22"
  elif [ -z "$V" ]; then
    echo "  ⚠️  $prop kosong (perlu reboot)"
  elif echo "$V" | grep -qE "greatltexx|N950F"; then
    echo "  ❌ $prop LEAK Note 8: $V"
    FAIL=$((FAIL+1))
  elif echo "$V" | grep -q "/essi:"; then
    echo "  ❌ $prop masih /essi/ (harus /r0s/): $V"
    FAIL=$((FAIL+1))
  else
    echo "  ⚠️  $prop beda: $V"
  fi
done

# 3. Device name mismatch
echo "--- Device name (essi → r0s) ---"
for prop in ro.product.system.device ro.product.system_ext.device ro.product.product.device ro.build.product ro.product.device; do
  V="$(getprop "$prop" 2>/dev/null)"
  if [ "$V" = "$TGT_DEVICE" ]; then
    echo "  ✅ $prop = r0s"
  elif [ "$V" = "essi" ]; then
    echo "  ❌ $prop = essi (LEAK, harus r0s)"
    FAIL=$((FAIL+1))
  elif [ -z "$V" ]; then
    echo "  ⚠️  $prop kosong"
  else
    echo "  ❌ $prop = $V (bukan r0s)"
    FAIL=$((FAIL+1))
  fi
done

# 4. Flavor
echo "--- Flavor ---"
FLAV="$(getprop ro.build.flavor)"
echo "  flavor: $FLAV"
if [ "$FLAV" = "${TGT_PRODUCT}-user" ]; then
  echo "  ✅ flavor = r0sxxx-user"
else
  echo "  ❌ flavor LEAK: $FLAV"
  FAIL=$((FAIL+1))
fi

# 5. Model (vendor/odm/dlkm)
echo "--- Model per-partition (harus SM-S901B) ---"
for prop in ro.product.model ro.product.vendor.model ro.product.odm.model ro.product.vendor_dlkm.model ro.product.system_ext.model; do
  V="$(getprop "$prop" 2>/dev/null)"
  if [ "$V" = "$TGT_MODEL" ]; then
    echo "  ✅ $prop = SM-S901B"
  elif [ -z "$V" ]; then
    echo "  ⚠️  $prop kosong"
  elif echo "$V" | grep -qE "N950F|Note"; then
    echo "  ❌ $prop LEAK Note 8: $V"
    FAIL=$((FAIL+1))
  else
    echo "  ⚠️  $prop beda: $V"
  fi
done

# 6. Bootloader
echo "--- Bootloader ---"
BLDR="$(getprop ro.boot.bootloader)"
echo "  bootloader: $BLDR"
if [ "$BLDR" = "$TGT_BUILD_ID" ]; then
  echo "  ✅ bootloader = S22"
else
  echo "  ❌ bootloader LEAK: $BLDR"
  FAIL=$((FAIL+1))
fi

# 7. ro.boot.em.model
echo "--- ro.boot.em.model ---"
EM="$(getprop ro.boot.em.model)"
echo "  em.model: $EM"
if [ "$EM" = "$TGT_MODEL" ]; then
  echo "  ✅ em.model = SM-S901B"
elif [ -z "$EM" ]; then
  echo "  ⚠️  em.model kosong"
else
  echo "  ❌ em.model LEAK: $EM"
  FAIL=$((FAIL+1))
fi

# 8. Description + display.id
echo "--- Description + display.id ---"
DESC="$(getprop ro.build.description)"
DSP="$(getprop ro.build.display.id)"
echo "  description : $DESC"
echo "  display.id  : $DSP"
if echo "$DESC $DSP" | grep -qE "greatltexx|essi"; then
  echo "  ❌ description/display leak"
  FAIL=$((FAIL+1))
else
  echo "  ✅ description/display clean"
fi

# 9. device_name (Settings)
echo "--- Settings device_name ---"
DN="$(settings get global device_name 2>/dev/null)"
echo "  device_name: $DN"
if echo "$DN" | grep -qE "Note8|N950|Note 8"; then
  echo "  ❌ DEVICE_NAME LEAK (Note 8)"
  FAIL=$((FAIL+1))
else
  echo "  ✅ device_name clean"
fi

echo ""
echo "=============================================="
if [ "$FAIL" -eq 0 ]; then
  echo "✅ CLEAN — semua build.prop leak tertutup"
  echo "   Reboot direkomendasikan biar semua process baca prop baru."
  echo "   Atau auto-boot: bash $0 install"
else
  echo "❌ Ada $FAIL leak. Run ulang: bash $0 apply"
  echo "   Reboot dulu, terus ulang. Beberapa prop butuh fresh boot."
fi
echo "=============================================="
echo ""
echo "  Log: $LOG_FILE"
log "=== selesai (fail=$FAIL, mode=$MODE) ==="
exit $FAIL
