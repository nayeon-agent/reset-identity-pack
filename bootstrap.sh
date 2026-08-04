#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  bootstrap.sh — One-liner installer Termux fresh
#  URL: https://raw.githubusercontent.com/nayeon-agent/reset-identity-pack/main/bootstrap.sh
#
#  Usage (di HP Termux):
#    curl -sL https://raw.githubusercontent.com/nayeon-agent/reset-identity-pack/main/bootstrap.sh | bash
#
#  Apa yang dilakukan:
#    1. Setup storage access (termux-setup-storage)
#    2. Install git + python (jika belum)
#    3. Clone repo ke ~/spoof
#    4. Run install.sh
#    5. Pre-flight check signal
# ============================================================

set -e

REPO_URL="https://github.com/nayeon-agent/reset-identity-pack.git"
DEST_DIR="$HOME/spoof"

echo "=============================================="
echo "  RESET IDENTITY PACK — Bootstrap Installer"
echo "  (untuk Termux fresh)"
echo "=============================================="

# ---------- Step 1: Storage access ----------
echo ""
echo "[1/6] Setup storage access..."
termux-setup-storage 2>&1 | head -1 || true

# ---------- Step 2: Update + install deps ----------
echo ""
echo "[2/6] Update + install deps (git, python, curl)..."
pkg update -y >/dev/null 2>&1
pkg install -y git python curl >/dev/null 2>&1
echo "  ✓ pkg ready"

# ---------- Step 3: Root check (informational) ----------
echo ""
echo "[3/6] Root detection..."
HAS_ROOT=0
if command -v su >/dev/null 2>&1; then
  if su -c id 2>/dev/null | grep -q "uid=0"; then
    HAS_ROOT=1
    ROOT_TYPE=$(su -c id 2>/dev/null | grep -oE 'magisk|ksu' | head -1)
    echo "  ✓ Root detected: $ROOT_TYPE"
  else
    echo "  ✗ su ada tapi gak ke-grant (cek Magisk/KSU prompt)"
  fi
else
  echo "  ✗ su command gak ada — install Magisk/KSU dulu"
fi

if [ "$HAS_ROOT" = "0" ]; then
  echo ""
  echo "  ⚠️  Script ini butuh root. Install Magisk dulu:"
  echo "     1. Patch boot.img via Magisk Manager"
  echo "     2. Flash via Odin/TWRP"
  echo "     3. Reboot → su -c id harus 'uid=0'"
  echo ""
  echo "  Tapi script bakal tetap di-clone + install (non-root commands OK)"
fi

# ---------- Step 4: Clone repo ----------
echo ""
echo "[4/6] Clone repo ke $DEST_DIR..."
if [ -d "$DEST_DIR" ]; then
  echo "  → Folder sudah ada, pull latest..."
  cd "$DEST_DIR" && git pull origin main 2>&1 | tail -3
else
  git clone "$REPO_URL" "$DEST_DIR" 2>&1 | tail -3
fi
cd "$DEST_DIR"
chmod +x *.sh 2>/dev/null
echo "  ✓ Repo ready"

# ---------- Step 5: Run install.sh ----------
echo ""
echo "[5/6] Run install.sh..."
if [ "$HAS_ROOT" = "1" ]; then
  bash install.sh
else
  echo "  ⚠️  Skip install.sh (butuh root)"
  echo "     Setelah root ready, jalanin manual:"
  echo "     bash $DEST_DIR/install.sh"
fi

# ---------- Step 6: Pre-flight check ----------
echo ""
echo "[6/6] Pre-flight check..."
if [ "$HAS_ROOT" = "1" ]; then
  bash farm_preflight.sh 2>&1 | tail -30
else
  echo "  (skip — butuh root)"
fi

echo ""
echo "=============================================="
echo "  ✅ BOOTSTRAP SELESAI"
echo "=============================================="
echo ""
echo "  Lokasi script: $DEST_DIR"
echo ""
echo "  Cara pakai:"
echo "    bash ~/spoof/reset_identity.sh          # reset sekali (WiFi IP)"
echo "    bash ~/spoof/farm_tiktok.sh             # FARM mode TikTok"
echo "    bash ~/spoof/farm_state.sh              # lihat state + history"
echo "    bash ~/spoof/farm_preflight.sh          # cek 7 signal"
echo ""
echo "  Module Magisk yang WAJIB ada di HP:"
echo "    • Magisk + Zygisk"
echo "    • TrickyStore (boot state spoof)"
echo "    • PlayIntegrityFork (fingerprint STRONG)"
echo "    • Shamiko (root hide)"
echo ""
echo "  Module OPTIONAL tapi recommended:"
echo "    • HMA — Hide My Applist"
echo "    • DeviceSpoofLab (props GUI)"
echo "    • auto-reset-google-advertising-id"
echo "    • LSPosed + Android Faker (IMEI full spoof)"
echo ""
echo "  Detail lengkap: cat ~/spoof/README_AUTO_RESET.md"
echo "=============================================="