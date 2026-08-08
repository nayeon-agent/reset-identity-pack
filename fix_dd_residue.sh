#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  fix_dd_residue.sh — Hapus 3 prop leak yg DuckDetector tangkep
#  ============================================================
#  Issue (DuckDetector 2026-08-08 report):
#    1. ro.vendor.build.fingerprint  = samsung/greatltexx/...   (Note 8 Android 9)
#    2. ro.build.flavor              = greatltexx-user          (Note 8 codename)
#    3. ro.boot.bootloader           = N950FXXUGDVG5            (Note 8 bootloader)
#    + device_name di Settings Global yg leak "Vega's Note8"
#
#  Fix: set ke S22 (r0sxxx) biar konsisten dgn Build.FINGERPRINT.
#  Aman dipanggil kapan aja — gak butuh reboot, tapi REBOOT
#  lebih direkomendasikan biar semua process baca prop baru.
#
#  Usage:
#    bash fix_dd_residue.sh           # apply fix
#    bash fix_dd_residue.sh check     # cek doang, no fix
# ============================================================

if [ "$(id -u)" != "0" ]; then
  echo "→ Butuh root, re-run via su..."
  exec su -c "/data/data/com.termux/files/usr/bin/bash $0 $*"
fi

MODE="${1:-apply}"
LOG_FILE="/data/local/tmp/fix_dd_residue.log"
TS() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(TS)] $1" | tee -a "$LOG_FILE"; }

# ---------- Target (S22 SM-S901B — match build fingerprint lo) ----------
TGT_MODEL="SM-S901B"
TGT_PRODUCT="r0sxxx"
TGT_DEVICE="r0s"
TGT_BUILD_ID="BP2A.250605.031.A3"
TGT_FINGERPRINT="samsung/r0sxxx/r0s:16/BP2A.250605.031.A3/S901BXXSNGZD7:user/release-keys"
TGT_SECURITY_PATCH="2026-08-05"

log "=== fix_dd_residue.sh (mode=$MODE) ==="

# ---------- Apply ----------
if [ "$MODE" = "apply" ] || [ "$MODE" = "fix" ]; then
  log "--- Apply 3 leak fix ---"
  # 1. Vendor fingerprint (yg paling gede leak-nya: vendor Note 8 = Android 9, gak match A16)
  resetprop -n ro.vendor.build.fingerprint "$TGT_FINGERPRINT" && log "  ✓ ro.vendor.build.fingerprint → S22" || log "  ✗ vendor fp gagal"
  resetprop -n ro.odm.build.fingerprint "$TGT_FINGERPRINT" && log "  ✓ ro.odm.build.fingerprint → S22" || log "  ✗ odm fp gagal"
  resetprop -n ro.product.build.fingerprint "$TGT_FINGERPRINT" && log "  ✓ ro.product.build.fingerprint → S22" || log "  ✗ product fp gagal"
  # 2. Flavor (greatltexx = Note 8 codename → r0sxxx = S22)
  resetprop -n ro.build.flavor "${TGT_PRODUCT}-user" && log "  ✓ ro.build.flavor → r0sxxx-user" || log "  ✗ flavor gagal"
  # 3. Bootloader (N950FXXUGDVG5 → S901BXXSNGZD7)
  resetprop -n ro.boot.bootloader "$TGT_BUILD_ID" && log "  ✓ ro.boot.bootloader → S901BXXSNGZD7" || log "  ✗ bootloader gagal"
  # 4. Model (kalau masih N950F)
  if [ "$(getprop ro.product.model)" != "$TGT_MODEL" ]; then
    resetprop -n ro.product.model "$TGT_MODEL" && log "  ✓ ro.product.model → SM-S901B" || log "  ✗ model gagal"
    resetprop -n ro.product.vendor.model "$TGT_MODEL" && log "  ✓ ro.product.vendor.model → SM-S901B"
    resetprop -n ro.product.system.model "$TGT_MODEL" && log "  ✓ ro.product.system.model → SM-S901B"
  else
    log "  - model udah $TGT_MODEL (skip)"
  fi
  # 5. device_name di Settings (leak Note 8)
  settings put global device_name "$TGT_MODEL" && log "  ✓ settings global device_name → SM-S901B" || log "  ✗ device_name gagal"
  settings put system device_name "$TGT_MODEL" && log "  ✓ settings system device_name → SM-S901B"
  # 6. Bonus: ro.build.host + ro.build.user (cocokin sama S22 fingerprint)
  resetprop -n ro.build.host "21DN2919" && log "  ✓ ro.build.host → 21DN2919" || log "  ✗ build_host gagal"
  resetprop -n ro.build.user "dpi" && log "  ✓ ro.build.user → dpi"
  # 7. Security patch per-partition
  resetprop -n ro.system.build.version.security_patch "$TGT_SECURITY_PATCH" && log "  ✓ system secpatch"
  resetprop -n ro.vendor.build.version.security_patch "$TGT_SECURITY_PATCH" && log "  ✓ vendor secpatch"
  resetprop -n ro.product.build.version.security_patch "$TGT_SECURITY_PATCH" && log "  ✓ product secpatch"
  # Clear GMS cache biar re-read props
  am force-stop com.google.android.gms 2>/dev/null
  am force-stop com.google.android.gsf 2>/dev/null
  log "  ✓ GMS + GSF cache cleared"
fi

# ---------- Check (always) ----------
echo ""
echo "=== DD-RESIDUE CHECK ==="
FAIL=0

# 1. Vendor fingerprint
VFP="$(getprop ro.vendor.build.fingerprint)"
echo "  vendor fp  : $VFP"
if echo "$VFP" | grep -q "r0sxxx"; then
  echo "  ✅ vendor fp = S22 (no leak)"
else
  echo "  ❌ VENDOR LEAK: masih Note 8"
  FAIL=$((FAIL+1))
fi

# 2. Flavor
FLAV="$(getprop ro.build.flavor)"
echo "  flavor     : $FLAV"
if [ "$FLAV" = "${TGT_PRODUCT}-user" ]; then
  echo "  ✅ flavor konsisten (r0sxxx-user)"
else
  echo "  ❌ FLAVOR LEAK: $FLAV (expected r0sxxx-user)"
  FAIL=$((FAIL+1))
fi

# 3. Bootloader
BLDR="$(getprop ro.boot.bootloader)"
echo "  bootloader : $BLDR"
if [ "$BLDR" = "$TGT_BUILD_ID" ]; then
  echo "  ✅ bootloader = S901BXXSNGZD7"
else
  echo "  ❌ BOOTLOADER LEAK: $BLDR (expected S901BXXSNGZD7)"
  FAIL=$((FAIL+1))
fi

# 4. Model
MOD="$(getprop ro.product.model)"
echo "  model      : $MOD"
if [ "$MOD" = "$TGT_MODEL" ]; then
  echo "  ✅ model = $TGT_MODEL"
else
  echo "  ❌ MODEL MISMATCH: $MOD"
  FAIL=$((FAIL+1))
fi

# 5. device_name
DN="$(getprop persist.sys.device_name)"
DN2="$(settings get global device_name 2>/dev/null)"
echo "  device_name: persist=$DN  global=$DN2"
if echo "$DN $DN2" | grep -q "Note8\|N950"; then
  echo "  ❌ DEVICE_NAME LEAK: masih Note 8"
  FAIL=$((FAIL+1))
else
  echo "  ✅ device_name clean"
fi

# 6. vbmeta digest (DuckDetector pake buat TEE consistency)
VB="$(getprop ro.boot.vbmeta.digest)"
ATTEST="ba97b6511bf466cf29a7479dc57b864f2ff04aa4fcbafb83aff1e7c24ee7e394"
echo "  vbmeta     : ${VB:0:24}..."
if [ "$VB" = "$ATTEST" ]; then
  echo "  ✅ vbmeta digest = attested (TrickyStore OK)"
else
  echo "  ⚠️  vbmeta digest beda — TrickyStore keybox mungkin perlu refresh"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "✅ CLEAN — semua prop leak tertutup"
  echo "   Reboot direkomendasikan biar semua process baca prop baru."
else
  echo "❌ Ada $FAIL leak. Run dgn mode apply (atau ulang):"
  echo "   bash fix_dd_residue.sh apply"
fi
echo ""
echo "  Log: $LOG_FILE"
log "=== selesai (fail=$FAIL) ==="
exit $FAIL
