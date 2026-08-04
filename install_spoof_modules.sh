#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  install_spoof_modules.sh — Auto-install + setup TikTok spoofing modules
#  ============================================================
#  Modul yang di-install:
#    1. LSPosed-CLI-Manager (CLI manager buat auto-config module)
#    2. Android Faker APK (Xposed module — spoof 12 ID per-app)
#    3. Optional: COPG setup TikTok per-app (jika COPG udah terinstall)
#
#  Prasyarat:
#    • LSPosed module sudah terinstall di HP
#    • Root via Magisk/KSU (su -c id = uid=0)
#    • Internet aktif
#
#  Usage:
#    bash install_spoof_modules.sh
# ============================================================

set -e

LOG_FILE="/data/local/tmp/install_spoof_modules.log"
TS() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(TS)] $1" | tee -a "$LOG_FILE"; }

INSTALL_DIR="/data/local/tmp/lsposed-cli"
LSPOSED_CLI_REPO="https://github.com/rogy153/LSPosed-CLI-Manager"
STAGE_DIR="/data/local/tmp/spoof_stage"
ANDROID_FAKER_REPO="https://github.com/Android1500/AndroidFaker/releases"
ANDROID_FAKER_FALLBACK="https://github.com/Android1500/AndroidFaker/releases/latest/download/app-release.apk"

# TikTok target apps (FQDN)
TIKTOK_PKGS=(
  "com.ss.android.ugc.aweme"     # TikTok main
  "com.ss.android.ugc.trill"     # TikTok Lite
)

# ---------- Self-escalate ----------
if [ "$(id -u)" != "0" ]; then
  echo "→ Butuh root, re-run via su..."
  exec su -c "/data/data/com.termux/files/usr/bin/bash $0"
fi

echo ""
echo "=============================================="
echo "  SPOOF MODULES INSTALLER"
echo "  Untuk TikTok Shop voucher farming"
echo "=============================================="
log "=== Install dimulai ==="

# ---------- [0] Pre-flight ----------
echo "  [0/6] Pre-flight check..."

# LSPosed module check
LSPOSED_OK=0
if [ -d "/data/adb/lspd" ] || [ -d "/data/adb/modules/zygisk_lsposed" ]; then
  LSPOSED_OK=1
  log "  ✓ LSPosed module terinstall"
else
  log "  ✗ LSPosed module GAK ada — install dulu LSPosed-v2.1.1 dari /storage/downloads/"
fi

# sqlite3 check
if command -v sqlite3 >/dev/null 2>&1; then
  log "  ✓ sqlite3 available"
else
  log "  ⚠️  sqlite3 tidak ada — coba pakai busybox"
  if busybox --list 2>/dev/null | grep -q "^sqlite3$"; then
    alias sqlite3='busybox sqlite3'
    log "  ✓ busybox sqlite3 fallback"
  else
    log "  ✗ sqlite3 GAK ada — install dulu (apt-get di Debian / Termux pkg install sqlite)"
  fi
fi

# ---------- [1] Setup directories ----------
echo "  [1/6] Setup directories..."
mkdir -p "$INSTALL_DIR" "$STAGE_DIR"
chmod 755 "$INSTALL_DIR" "$STAGE_DIR"
log "  ✓ dirs: $INSTALL_DIR + $STAGE_DIR"

# ---------- [2] Install LSPosed-CLI-Manager ----------
echo "  [2/6] Install LSPosed-CLI-Manager..."
if [ -f "$INSTALL_DIR/list_modules.sh" ]; then
  log "  ✓ LSPosed CLI udah terinstall — skip"
else
  log "  → Clone LSPosed-CLI-Manager..."
  if cd "$INSTALL_DIR" && curl -fsSL "$LSPOSED_CLI_REPO/archive/main.tar.gz" 2>/dev/null | tar -xz 2>/dev/null; then
    # Extract scripts
    if [ -d "$INSTALL_DIR/LSPosed-CLI-Manager-main" ]; then
      cp -r "$INSTALL_DIR/LSPosed-CLI-Manager-main/scripts/"* "$INSTALL_DIR/" 2>/dev/null
      rm -rf "$INSTALL_DIR/LSPosed-CLI-Manager-main"
    fi
    chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null
    log "  ✓ LSPosed-CLI-Manager installed"
  else
    log "  ✗ Clone gagal — coba manual: lihat https://github.com/rogy153/LSPosed-CLI-Manager"
  fi
fi

# ---------- [3] Download Android Faker APK ----------
echo "  [3/6] Download Android Faker APK..."
ANDROID_FAKER_APK="$STAGE_DIR/android_faker.apk"
if [ -f "$ANDROID_FAKER_APK" ] && [ "$(stat -c%s "$ANDROID_FAKER_APK" 2>/dev/null)" -gt 1000000 ]; then
  log "  ✓ APK udah ada di stage ($(du -h "$ANDROID_FAKER_APK" | cut -f1))"
else
  log "  → Fetching Android Faker release info..."
  # Coba ambil latest APK URL dari GitHub API
  LATEST_URL=""
  if command -v curl >/dev/null 2>&1; then
    RELEASE_JSON="$(curl -fsSL "https://api.github.com/repos/Android1500/AndroidFaker/releases/latest" 2>/dev/null)"
    if [ -n "$RELEASE_JSON" ]; then
      LATEST_URL="$(echo "$RELEASE_JSON" | grep -oE 'https://[^"]+\.apk' | head -1)"
    fi
  fi
  if [ -z "$LATEST_URL" ]; then
    LATEST_URL="$ANDROID_FAKER_FALLBACK"
  fi
  log "  → Download: $LATEST_URL"
  if curl -fsL -o "$ANDROID_FAKER_APK" "$LATEST_URL" 2>/dev/null && [ "$(stat -c%s "$ANDROID_FAKER_APK" 2>/dev/null)" -gt 1000000 ]; then
    log "  ✓ APK downloaded ($(du -h "$ANDROID_FAKER_APK" | cut -f1))"
  else
    log "  ⚠️  Download gagal — pakai manual path"
    log "     Taruh APK di: $ANDROID_FAKER_APK"
    log "     atau download manual dari: $ANDROID_FAKER_REPO"
    # Cari APK lokal
    LOCAL_APK=$(find /storage /sdcard -name "*AndroidFaker*.apk" -o -name "*android_faker*.apk" 2>/dev/null | head -1)
    if [ -n "$LOCAL_APK" ] && [ -f "$LOCAL_APK" ]; then
      cp "$LOCAL_APK" "$ANDROID_FAKER_APK"
      log "  ✓ Pakai APK lokal: $LOCAL_APK"
    fi
  fi
fi

# ---------- [4] Install Android Faker ----------
echo "  [4/6] Install Android Faker APK..."
if [ -f "$ANDROID_FAKER_APK" ] && [ "$(stat -c%s "$ANDROID_FAKER_APK" 2>/dev/null)" -gt 1000000 ]; then
  if pm install "$ANDROID_FAKER_APK" >/dev/null 2>&1; then
    log "  ✓ Android Faker APK terinstall"
  elif pm install -r "$ANDROID_FAKER_APK" >/dev/null 2>&1; then
    log "  ✓ Android Faker APK terinstall (replace)"
  else
    log "  ✗ Install gagal"
    exit 1
  fi
else
  log "  ✗ APK gak ada — skip install"
  exit 1
fi

# ---------- [5] Enable Android Faker + scope ke TikTok ----------
echo "  [5/6] Enable Android Faker + scope TikTok..."
if [ -f "$INSTALL_DIR/list_modules.sh" ] && [ "$LSPOSED_OK" = "1" ]; then
  log "  → List modules..."
  bash "$INSTALL_DIR/list_modules.sh" 2>&1 | grep -i android_faker && MOD_PKG="com.android1500.androidfaker" || MOD_PKG="com.android1500.androidfaker"

  log "  → Enable module + add scope..."
  if [ -x "$INSTALL_DIR/enable_module.sh" ]; then
    bash "$INSTALL_DIR/enable_module.sh" "$MOD_PKG" 2>&1 | tail -10 | while read -r line; do log "    $line"; done

    # Add TikTok scopes
    if [ -x "$INSTALL_DIR/discover_scopes.sh" ]; then
      for PKG in "${TIKTOK_PKGS[@]}"; do
        log "  → Add scope: $PKG"
        bash "$INSTALL_DIR/enable_module.sh" "$MOD_PKG" --scope "$PKG" 2>&1 | tail -3 | while read -r line; do log "    $line"; done
      done
    fi
  else
    log "  ⚠️  enable_module.sh gak ada — fallback: manual via LSPosed Manager"
    log "     Buka LSPosed Manager > Modules > Android Faker > enable"
    log "     Scope: com.ss.android.ugc.aweme, com.ss.android.ugc.trill"
  fi
else
  log "  ⚠️  LSPosed CLI gak ada — enable manual via LSPosed Manager"
fi

# ---------- [6] Verify + summary ----------
echo "  [6/6] Verify..."
ANDROID_FAKER_INSTALLED=0
if pm list packages 2>/dev/null | grep -q "com.android1500.androidfaker"; then
  ANDROID_FAKER_INSTALLED=1
  log "  ✓ com.android1500.androidfaker terinstall"
else
  log "  ✗ com.android1500.androidfaker GAK ada"
fi

LSP_CLI_OK=0
if [ -x "$INSTALL_DIR/list_modules.sh" ]; then
  LSP_CLI_OK=1
fi

echo ""
echo "=============================================="
echo "  ✅ INSTALL COMPLETE"
echo "=============================================="
echo ""
echo "  Status:"
echo "    Android Faker APK     : $([ "$ANDROID_FAKER_INSTALLED" = "1" ] && echo "✅ installed" || echo "❌ not installed")"
echo "    LSPosed CLI Manager   : $([ "$LSP_CLI_OK" = "1" ] && echo "✅ installed" || echo "❌ not installed")"
echo "    TikTok scopes added   : $([ "$LSP_CLI_OK" = "1" ] && echo "attempted" || echo "manual")"
echo ""
echo "  NEXT STEPS:"
echo "  1. Buka Android Faker app → set 12 ID random (atau auto-generate)"
echo "  2. Reboot"
echo "  3. Run farm cycle:"
echo "     bash ~/spoof/tiktok_farm_auto.sh"
echo ""
echo "  Helper commands:"
echo "    ls -la $INSTALL_DIR/             # LSPosed CLI scripts"
echo "    cat $LOG_FILE                   # install log"
echo "    pm list packages | grep android1500  # verify install"
echo ""
echo "  Detail modul apa yang di-spoof (12 ID):"
echo "    IMEI, Hardware ID, MAC, BSSID, SSID, Bluetooth MAC,"
echo "    Android ID, SIM Serial, SIM Sub ID, Mobile No,"
echo "    GSF ID, MediaDrm ID, Advertisement ID (GAID)"
echo "=============================================="
log "=== Install selesai ==="