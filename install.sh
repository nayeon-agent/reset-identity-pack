#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  install.sh — Setup Full Reset Identity Stack di Termux
#  Usage: bash install.sh
# ============================================================

if [ "$(id -u)" != "0" ]; then
  echo "→ Butuh root untuk install, re-run via su..."
  exec su -c "/data/data/com.termux/files/usr/bin/bash $0"
fi

echo "=============================================="
echo "  INSTALL — Full Reset Identity (NO 3rd Party)"
echo "=============================================="

TERMUX_HOME="/data/data/com.termux/files/home"
DEST_DIR="$TERMUX_HOME/spoof"
mkdir -p "$DEST_DIR"

# Copy semua script
SCRIPT_SRC="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_SRC/reset_identity.sh"     "$DEST_DIR/" 2>/dev/null
cp "$SCRIPT_SRC/spoof_props.sh"        "$DEST_DIR/" 2>/dev/null
cp "$SCRIPT_SRC/imei_spoof.sh"         "$DEST_DIR/" 2>/dev/null
cp "$SCRIPT_SRC/ip_rotator.sh"         "$DEST_DIR/" 2>/dev/null
cp "$SCRIPT_SRC/auto_reset_loop.sh"    "$DEST_DIR/" 2>/dev/null
cp "$SCRIPT_SRC/farm_tiktok.sh"        "$DEST_DIR/" 2>/dev/null
cp "$SCRIPT_SRC/farm_state.sh"         "$DEST_DIR/" 2>/dev/null
cp "$SCRIPT_SRC/farm_preflight.sh"     "$DEST_DIR/" 2>/dev/null
cp "$SCRIPT_SRC/README_AUTO_RESET.md"  "$DEST_DIR/" 2>/dev/null

chmod +x "$DEST_DIR"/*.sh 2>/dev/null

echo "✓ Script di-copy ke: $DEST_DIR"
ls -la "$DEST_DIR/" | grep -v "^d"
echo ""

# Auto-start
echo "--- Auto-start saat boot? ---"
read -p "Tambahkan ke boot (y/n)? " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  mkdir -p /data/adb/service.d
  cat > /data/adb/service.d/auto_reset_identity.sh <<'EOF'
#!/system/bin/sh
# Auto-start reset identity daemon (tiap 10 menit)
nohup /data/data/com.termux/files/home/spoof/auto_reset_loop.sh 600 > /dev/null 2>&1 &
EOF
  chmod 755 /data/adb/service.d/auto_reset_identity.sh
  echo "✓ Auto-start: /data/adb/service.d/auto_reset_identity.sh"
fi

echo ""
echo "=============================================="
echo "  ✅ INSTALL SELESAI"
echo "=============================================="
echo ""
echo " Cara pakai:"
echo "  • Reset sekali (full):     bash ~/spoof/reset_identity.sh"
echo "  • Reset sekali (skip IP):  bash ~/spoof/reset_identity.sh skip"
echo "  • FARM mode TikTok:        bash ~/spoof/farm_tiktok.sh"
echo "  • Farm state/history:      bash ~/spoof/farm_state.sh"
echo "  • Farm preflight check:    bash ~/spoof/farm_preflight.sh"
echo "  • IP-only airplane:        bash ~/spoof/ip_rotator.sh airplane"
echo "  • Props-only spoof:        bash ~/spoof/spoof_props.sh"
echo "  • IMEI-only spoof:         bash ~/spoof/imei_spoof.sh"
echo "  • Daemon loop 10 min:      bash ~/spoof/auto_reset_loop.sh 600"
echo "  • Stop daemon:             killall auto_reset_loop.sh"
echo ""
echo " Module WAJIB terinstall di HP:"
echo "  • Magisk + Zygisk (untuk resetprop)"
echo "  • TrickyStore (boot state spoof)"
echo "  • Shamiko (root hide)"
echo ""
echo " Module OPTIONAL:"
echo "  • LSPosed (untuk IMEI full spoof via Android Faker)"
echo "  • DeviceSpoofLab-Magisk (alternative props spoof)"
echo "=============================================="
