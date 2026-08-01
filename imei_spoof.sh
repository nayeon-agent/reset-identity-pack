#!/system/bin/sh
# ============================================================
#  imei_spoof.sh — Spoof IMEI (partial, tanpa Xposed)
#  CARA KERJA:
#   • Props level: set ril.* props yg banyak app baca
#   • TelephonyManager binder: GAK BISA tanpa hook Xposed —
#     app yg pake getImei()/getDeviceId() tetap lihat IMEI asli
#   • Tapi buat app yg baca props / telephony props → kebaca palsu
#  JANGAN HARAP 100% — ini best-effort tanpa Xposed.
# ============================================================

LOG_FILE="/data/local/tmp/imei_spoof.log"
TS() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(TS)] $1" | tee -a "$LOG_FILE"; }

if [ "$(id -u)" != "0" ]; then
  echo "→ Butuh root, re-run via su..."
  exec su -c "sh $0"
fi

# ---------- Generate IMEI valid (Luhn check) ----------
gen_imei() {
  # TAC: pilih dari pool yg valid (samsung/emulator range)
  TAC="$1"
  if [ -z "$TAC" ]; then
    # Random TAC: 35 (Samsung) / 86 (China) / 01 (test)
    TAC="35$(printf '%04d' $((RANDOM % 10000)))"
  fi
  # SN: 6 digit random
  SN="$(printf '%06d' $((RANDOM % 1000000)))"
  # 14 digit base
  BASE="${TAC}${SN}"
  # Hitung Luhn check digit
  SUM=0
  ALT=0
  for (( i=13; i>=0; i-- )); do
    D="${BASE:$i:1}"
    if [ "$ALT" = "1" ]; then
      D2=$((D * 2))
      if [ "$D2" -gt 9 ]; then D2=$((D2 - 9)); fi
      SUM=$((SUM + D2))
      ALT=0
    else
      SUM=$((SUM + D))
      ALT=1
    fi
  done
  CHECK=$(( (10 - (SUM % 10)) % 10 ))
  echo "${BASE}${CHECK}"
}

# TAC: 35=GSMA registered (Samsung), 86=China, 01=test
IMEI1=$(gen_imei "35")
IMEI2=$(gen_imei "35")
log "=== IMEI spoof dimulai ==="
log "  IMEI1: $IMEI1"
log "  IMEI2: $IMEI2"

# ---------- Set props (best-effort) ----------
resetprop -n ril.imei "$IMEI1" 2>>"$LOG_FILE"
resetprop -n ril.imei2 "$IMEI2" 2>>"$LOG_FILE"
resetprop -n gsm.baseband.imei "$IMEI1" 2>>"$LOG_FILE"
resetprop -n ro.ril.oem.imei "$IMEI1" 2>>"$LOG_FILE"
resetprop -n ro.ril.oem.imei1 "$IMEI1" 2>>"$LOG_FILE"
resetprop -n ro.ril.oem.imei2 "$IMEI2" 2>>"$LOG_FILE"
resetprop -n persist.radio.imei "$IMEI1" 2>>"$LOG_FILE"
resetprop -n persist.radio.imei1 "$IMEI1" 2>>"$LOG_FILE"
resetprop -n persist.radio.imei2 "$IMEI2" 2>>"$LOG_FILE"
resetprop -n ro.telephony.default_network 9 2>>"$LOG_FILE"

# Restart telephony biar props ke-baca ulang (kadang perlu)
# cmd phone restart 2>>"$LOG_FILE"   # ga semua support

log "  ✓ Props IMEI di-set (best-effort)"
echo ""
echo "=============================================="
echo "  ⚠️  IMPORTANT — BATASAN SCRIPT INI"
echo "=============================================="
echo "  ❌ App yg pake TelephonyManager.getImei()"
echo "     → MASIH baca IMEI ASLI (binder, bukan props)"
echo "  ❌ *#06# di dialer → masih IMEI asli"
echo ""
echo "  ✅ App yg baca props / ril.* → kebaca palsu"
echo ""
echo "  BUAT 100% IMEI SPOOF, butuh salah satu:"
echo "   1. Android Faker (Xposed/LSPosed)"
echo "       github.com/Android1500/AndroidFaker"
echo "   2. IMEI Changer Xposed"
echo "       apkpure.com/imei-changer-xposed"
echo "   3. Module LSPosed lain yg hook TelephonyManager"
echo ""
echo "  Verifikasi:"
echo "    dumpsys iphonesubinfo | grep -i imei"
echo "=============================================="
