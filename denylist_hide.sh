#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  denylist_hide.sh — KSU Denylist: umount root dari target apps
#  Tujuan: target apps (DuckDetector, TikTok, banking) gak bisa
#          liat root/module traces. Apps di denylist = di-unmount.
#
#  PENTING:
#  - JANGAN tambah com.termux ke denylist — Termux bakal kehilangan
#    akses su (KSU umount su binary dari app yang di-denylist).
#  - Ini HANYA umount root. Package detection (PackageManager)
#    tetap jalan — untuk hide package perlu HMA (UI config).
#
#  Usage: bash denylist_hide.sh
# ============================================================

if [ "$(id -u)" != "0" ]; then
  echo "→ Butuh root, re-run via su..."
  exec su -c "/data/data/com.termux/files/usr/bin/bash $0"
fi

echo "=============================================="
echo "  KSU DENYLIST — UNMOUNT ROOT FROM APPS"
echo "=============================================="

DENYLIST_FILE="/data/adb/ksu/denylist"
PACKAGES=(
  "com.eltavine.duckdetector"          # DuckDetector
  "com.ss.android.ugc.trill"           # TikTok (Global)
  "com.ss.android.ugc.aweme"           # TikTok (CN/Douyin)
  "com.zhiliaoapp.musically"           # TikTok (Lite)
  "com.google.android.gms"             # Play Integrity check path
  "com.android.vending"                # Play Store
)

# ---- Backup ----
if [ -f "$DENYLIST_FILE" ]; then
  BK="$DENYLIST_FILE.bak.$(date +%Y%m%d%H%M%S)"
  cp "$DENYLIST_FILE" "$BK"
  echo "✓ Backup: $BK"
else
  mkdir -p /data/adb/ksu
  touch "$DENYLIST_FILE"
  echo "! $DENYLIST_FILE belum ada, buat baru"
fi

echo ""
echo "--- Isi denylist sekarang ---"
cat "$DENYLIST_FILE" 2>/dev/null
echo ""

# ---- Prefer ksud CLI kalau ada ----
HAS_KSUD=0
if command -v ksud >/dev/null 2>&1; then
  HAS_KSUD=1
  echo "✓ ksud CLI ditemukan, pakai ksud"
elif [ -x /data/adb/ksud ]; then
  HAS_KSUD=1
  KSUD=/data/adb/ksud
  echo "✓ ksud ditemukan di /data/adb/ksud"
else
  echo "! ksud gak ditemukan, edit file langsung"
fi

echo ""
for pkg in "${PACKAGES[@]}"; do
  # Cek format `package` atau `package:uid`
  if grep -qE "^(.*:)?${pkg}(:.*)?$" "$DENYLIST_FILE" 2>/dev/null; then
    echo "= $pkg sudah ada, skip"
  else
    if [ "$HAS_KSUD" = "1" ]; then
      ${KSUD:-ksud} denylist add "$pkg" >/dev/null 2>&1
    else
      echo "$pkg" >> "$DENYLIST_FILE"
    fi
    echo "+ $pkg ditambahkan"
  fi
done

echo ""
echo "--- Isi denylist setelah ---"
cat "$DENYLIST_FILE" 2>/dev/null
echo ""

# ---- Verify ----
echo "--- Verify ksud (kalau ada) ---"
${KSUD:-ksud} denylist list 2>/dev/null || echo "(ksud list tidak tersedia)"
echo ""

# ---- Reboot ----
echo "Denylist selesai. Perlu reboot biar aktif."
read -p "Reboot sekarang? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Reboot..."
  sync
  reboot
else
  echo "Skip reboot. Denylist aktif setelah reboot manual."
fi
