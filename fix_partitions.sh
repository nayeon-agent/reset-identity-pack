#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  fix_partitions.sh — Set ALL fingerprint partitions (fix 4 FAIL)
#  Kenapa perlu: ROM UniGaga A16 port dari S22 — system partition
#  udah S22 (r0sxxx/essi) tapi vendor/odm masih Note 8 (greatlte).
#  Resetprop via su (bukan shell biasa) biar konsisten.
#
#  Usage: bash fix_partitions.sh
# ============================================================

if [ "$(id -u)" != "0" ]; then
  echo "→ Butuh root, re-run via su..."
  exec su -c "/data/data/com.termux/files/usr/bin/bash $0"
fi

LOG_FILE="/data/local/tmp/fix_partitions.log"
TS() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(TS)] $1" | tee -a "$LOG_FILE"; }

# ---------- Target (S22 SM-S901B — sama dengan spoof_props.sh) ----------
MANUFACTURER="samsung"
BRAND="samsung"
MODEL="SM-S901B"
DEVICE="r0s"
PRODUCT="r0sxxx"
HARDWARE="samsungexynos8895"
FINGERPRINT="samsung/r0sxxx/r0s:16/BP2A.250605.031.A3/S901BXXSNGZD7:user/release-keys"
FP_ID="BP2A.250605.031.A3"

log "=== Fix partitions dimulai (target: $MODEL) ==="

# ---------- Resetprop — SEMUA partition fingerprint ----------
log "--- Set fingerprint all partitions ---"
for prop in \
  ro.build.fingerprint \
  ro.system.build.fingerprint \
  ro.vendor.build.fingerprint \
  ro.bootimage.build.fingerprint \
  ro.odm.build.fingerprint \
  ro.product.build.fingerprint; do
  resetprop -n "$prop" "$FINGERPRINT" 2>>"$LOG_FILE" && log "  ✓ $prop" || log "  ✗ $prop (gagal)"
done

# ---------- Product identity ----------
log "--- Set product identity ---"
for prop in \
  ro.product.manufacturer ro.product.brand ro.product.model \
  ro.product.device ro.product.name ro.product.board ro.product.product \
  ro.product.system.brand ro.product.system.model \
  ro.product.vendor.brand ro.product.vendor.model \
  ro.product.odm.brand ro.product.odm.model; do
  case "$prop" in
    *manufacturer) VAL="$MANUFACTURER" ;;
    *brand)        VAL="$BRAND" ;;
    *model)        VAL="$MODEL" ;;
    *device|*board) VAL="$DEVICE" ;;
    *name|*product) VAL="$PRODUCT" ;;
  esac
  resetprop -n "$prop" "$VAL" 2>>"$LOG_FILE" && log "  ✓ $prop=$VAL" || log "  ✗ $prop (gagal)"
done

# ---------- Derived props ----------
log "--- Set derived props ---"
resetprop -n ro.build.display.id "$FP_ID" 2>>"$LOG_FILE"
resetprop -n ro.build.id "$FP_ID" 2>>"$LOG_FILE"
resetprop -n ro.build.flavor "${PRODUCT}-user" 2>>"$LOG_FILE"
resetprop -n ro.build.description "${PRODUCT}-user $FP_ID user release-keys" 2>>"$LOG_FILE"
resetprop -n ro.hardware "$HARDWARE" 2>>"$LOG_FILE"
# Bootloader leak (DuckDetector 2026-08-08): N950FXXUGDVG5 -> S901BXXSNGZD7
resetprop -n ro.boot.bootloader "$FP_ID" 2>>"$LOG_FILE"
# Build host/user — pin ke build S22 asli (bukan Note 8)
resetprop -n ro.build.host "21DN2919" 2>>"$LOG_FILE"
resetprop -n ro.build.user "dpi" 2>>"$LOG_FILE"
# Security patch per-partition biar konsisten
resetprop -n ro.system.build.version.security_patch "2026-08-05" 2>>"$LOG_FILE"
resetprop -n ro.vendor.build.version.security_patch "2026-08-05" 2>>"$LOG_FILE"
resetprop -n ro.product.build.version.security_patch "2026-08-05" 2>>"$LOG_FILE"
log "  ✓ derived props set"

# ---------- Verify ----------
echo ""
echo "=== VERIFY — semua partition ==="
echo "  main    : $(getprop ro.build.fingerprint)"
echo "  system  : $(getprop ro.system.build.fingerprint)"
echo "  vendor  : $(getprop ro.vendor.build.fingerprint)"
echo "  bootimg : $(getprop ro.bootimage.build.fingerprint)"
echo "  odm     : $(getprop ro.odm.build.fingerprint)"
echo "  product : $(getprop ro.product.build.fingerprint)"
echo "  model   : $(getprop ro.product.model)"
echo ""

# Check match
FP_MAIN="$(getprop ro.build.fingerprint)"
FAIL=0
for part in ro.system.build.fingerprint ro.vendor.build.fingerprint ro.bootimage.build.fingerprint ro.odm.build.fingerprint ro.product.build.fingerprint; do
  VAL="$(getprop $part)"
  if [ "$VAL" = "$FP_MAIN" ]; then
    echo "  ✅ $part match"
  elif [ -z "$VAL" ]; then
    echo "  ⚠️  $part kosong (perlu reboot)"
  else
    echo "  ❌ $part BEDA: $VAL"
    FAIL=$((FAIL+1))
  fi
done

# --- DuckDetector 2026-08-08 leak check ---
echo ""
echo "=== DD-RESIDUE CHECK (3 leak sebelumnya) ==="
echo "  vendor fp      : $(getprop ro.vendor.build.fingerprint)"
echo "  flavor         : $(getprop ro.build.flavor)"
echo "  bootloader     : $(getprop ro.boot.bootloader)"
echo "  model          : $(getprop ro.product.model)"
echo "  device_name    : $(getprop persist.sys.device_name)"
VFP="$(getprop ro.vendor.build.fingerprint)"
if echo "$VFP" | grep -q "r0sxxx"; then
  echo "  ✅ vendor fingerprint = S22 (no leak)"
else
  echo "  ❌ vendor fingerprint masih leak: $VFP"
  FAIL=$((FAIL+1))
fi
FLAV="$(getprop ro.build.flavor)"
if [ "$FLAV" = "${PRODUCT}-user" ]; then
  echo "  ✅ flavor konsisten ($FLAV)"
else
  echo "  ❌ flavor leak: $FLAV"
  FAIL=$((FAIL+1))
fi
BLDR="$(getprop ro.boot.bootloader)"
if [ "$BLDR" = "$FP_ID" ]; then
  echo "  ✅ bootloader = S22 ($BLDR)"
else
  echo "  ❌ bootloader masih leak: $BLDR"
  FAIL=$((FAIL+1))
fi

if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "  ✅ SEMUA partition match + DD-residue bersih — siap lanjut"
else
  echo ""
  echo "  ⚠️  Ada $FAIL issue — reboot dulu, jalanin ulang fix_partitions.sh"
fi
echo ""
echo "  Log: $LOG_FILE"
log "=== Selesai (fail=$FAIL) ==="
