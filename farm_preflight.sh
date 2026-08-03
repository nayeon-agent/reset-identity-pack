#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  farm_preflight.sh — Pre-Register Health Check
#  Cek semua signal yang dibaca TikTok sebelum registrasi:
#    • Fingerprint konsisten semua partition
#    • GAID fresh (bukan yang kemarin)
#    • IMEI props ada
#    • IP beda dari cycle sebelumnya
#    • App TikTok data bersih (belum pernah login)
#    • Boot state aman (locked/green)
#    • Play Integrity (via PlayIntegrityFork props)
#
#  Usage: bash farm_preflight.sh [--strict]
#    --strict → exit 1 kalau ada yang FAIL (untuk automasi)
# ============================================================

HIST_FILE="/data/local/tmp/farm_history.tsv"
TS() { date '+%Y-%m-%d %H:%M:%S'; }
MODE="${1:-normal}"

if [ "$(id -u)" != "0" ]; then
  echo "→ Butuh root, re-run via su..."
  exec su -c "/data/data/com.termux/files/usr/bin/bash $0 $1"
fi

PASS=0
FAIL=0
WARN=0

check() {
  local label="$1" status="$2" msg="$3"
  case "$status" in
    PASS) PASS=$((PASS+1)); echo "  ✅ $label: $msg" ;;
    FAIL) FAIL=$((FAIL+1)); echo "  ❌ $label: $msg" ;;
    WARN) WARN=$((WARN+1)); echo "  ⚠️  $label: $msg" ;;
  esac
}

echo ""
echo "=============================================="
echo "  🩺 PRE-FLIGHT CHECK — $(TS)"
echo "  Mode: $MODE"
echo "=============================================="
echo ""

# ---------- 1. Fingerprint konsisten ----------
echo "  [1/7] Fingerprint consistency"
FP_MAIN="$(getprop ro.build.fingerprint 2>/dev/null)"
FP_SYS="$(getprop ro.system.build.fingerprint 2>/dev/null)"
FP_VEN="$(getprop ro.vendor.build.fingerprint 2>/dev/null)"
FP_BOOT="$(getprop ro.bootimage.build.fingerprint 2>/dev/null)"
FP_ODM="$(getprop ro.odm.build.fingerprint 2>/dev/null)"
FP_PROD="$(getprop ro.product.build.fingerprint 2>/dev/null)"

if [ -z "$FP_MAIN" ]; then
  check "Fingerprint" FAIL "kosong — spoof belum jalan"
else
  check "Fingerprint main" PASS "$(echo "$FP_MAIN" | cut -d'/' -f1-3)"
  for part in "system:$FP_SYS" "vendor:$FP_VEN" "bootimage:$FP_BOOT" "odm:$FP_ODM" "product:$FP_PROD"; do
    name="${part%%:*}"
    val="${part#*:}"
    if [ "$val" = "$FP_MAIN" ]; then
      check "  partition $name" PASS "match"
    elif [ -z "$val" ]; then
      check "  partition $name" WARN "kosong"
    else
      check "  partition $name" FAIL "BEDA: $val"
    fi
  done
fi

# ---------- 2. Boot state ----------
echo ""
echo "  [2/7] Boot state"
VB="$(getprop ro.boot.verifiedbootstate 2>/dev/null)"
FLASH="$(getprop ro.boot.flash.locked 2>/dev/null)"
VBMETA="$(getprop ro.boot.vbmeta.digest 2>/dev/null)"
[ "$VB" = "green" ] && check "Boot state" PASS "green" || check "Boot state" FAIL "=$VB"
[ "$FLASH" = "1" ] && check "Flash locked" PASS "locked" || check "Flash locked" FAIL "=$FLASH"
[ -n "$VBMETA" ] && check "vbmeta digest" PASS "ter-set (${VBMETA:0:8}...)" || check "vbmeta digest" FAIL "kosong"

# ---------- 3. GAID fresh ----------
echo ""
echo "  [3/7] GAID freshness"
GAID="$(cmd advertising_id get 2>/dev/null | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)"
if [ -z "$GAID" ]; then
  check "GAID" FAIL "gak bisa dibaca — service advertising_id mati"
elif [ -f "$HIST_FILE" ]; then
  LAST_GAID="$(tail -1 "$HIST_FILE" | awk -F'\t' '{print $6}')"
  if [ "${GAID:0:8}" = "$LAST_GAID" ]; then
    check "GAID" FAIL "sama dengan cycle terakhir (${GAID:0:8}...) — reset lagi"
  else
    check "GAID" PASS "${GAID:0:8}... (beda dari cycle terakhir)"
  fi
else
  check "GAID" PASS "${GAID:0:8}... (fresh, no history)"
fi

# ---------- 4. IMEI props ----------
echo ""
echo "  [4/7] IMEI props"
IMEI="$(getprop ril.imei 2>/dev/null)"
if [ -n "$IMEI" ] && [ ${#IMEI} -eq 15 ]; then
  check "IMEI (ril.imei)" PASS "${IMEI:0:8}... (15 digit)"
else
  check "IMEI (ril.imei)" FAIL "kosong/format salah"
fi

# ---------- 5. IP beda ----------
echo ""
echo "  [5/7] IP rotation"
IP="$(ip route get 1.1.1.1 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print $2}')"
if [ -f "$HIST_FILE" ]; then
  LAST_IP="$(tail -1 "$HIST_FILE" | awk -F'\t' '{print $10}')"
  if [ "$IP" = "$LAST_IP" ]; then
    check "IP" WARN "sama dengan cycle terakhir ($IP) — kemungkinan IP gak rotate"
  else
    check "IP" PASS "$IP (beda dari $LAST_IP)"
  fi
else
  check "IP" PASS "$IP (no history)"
fi

# ---------- 6. TikTok app clean ----------
echo ""
echo "  [6/7] TikTok app state"
TT_APP=""
for APP in com.ss.android.ugc.aweme com.ss.android.ugc.trill; do
  if pm list packages | grep -q "$APP"; then
    TT_APP="$APP"
    break
  fi
done
if [ -z "$TT_APP" ]; then
  check "TikTok app" FAIL "belum terinstall — install dulu biar data fresh"
else
  # Cek data dir ada session (login state) — cara kasar: cek files di data dir
  DATA_DIR="/data/data/$TT_APP"
  if [ -d "$DATA_DIR" ]; then
    LOGIN_MARKER="$(find "$DATA_DIR" -maxdepth 2 -name "*session*" -o -maxdepth 2 -name "*login*" 2>/dev/null | head -1)"
    if [ -n "$LOGIN_MARKER" ]; then
      check "TikTok ($TT_APP)" WARN "data dir ada ($(basename "$LOGIN_MARKER")) — kemungkinan pernah login"
    else
      check "TikTok ($TT_APP)" PASS "data dir fresh"
    fi
  else
    check "TikTok ($TT_APP)" PASS "belum pernah jalan (no data dir)"
  fi
fi

# ---------- 7. Play Integrity props ----------
echo ""
echo "  [7/7] Play Integrity support"
PIF="$(getprop ro.build.fingerprint 2>/dev/null | grep -cE 'google|samsung')"
TS_STATE="$(ls /data/adb/tricky_store 2>/dev/null | wc -l)"
if [ -d /data/adb/tricky_store ]; then
  check "TrickyStore" PASS "terinstall ($TS_STATE files)"
else
  check "TrickyStore" WARN "tidak ditemukan — boot state bisa ke-flag"
fi
if [ -f /data/adb/modules/playintegrityfork/pif.json ] || [ -f /data/adb/modules/playintegrityfork/custom.pif.prop ]; then
  check "PIF config" PASS "ada"
else
  check "PIF config" WARN "tidak ditemukan"
fi

echo ""
echo "=============================================="
echo "  RESULT: $PASS pass, $WARN warning, $FAIL fail"
echo "=============================================="

if [ "$MODE" = "--strict" ] && [ "$FAIL" -gt 0 ]; then
  echo "  ❌ STRICT MODE: ada $FAIL FAIL — jangan registrasi"
  exit 1
elif [ "$FAIL" -gt 0 ]; then
  echo "  ⚠️  Ada $FAIL FAIL — fix dulu sebelum registrasi biar aman"
  exit 2
else
  echo "  ✅ AMAN — siap registrasi akun baru"
  exit 0
fi