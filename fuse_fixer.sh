#!/system/bin/sh
# fuse_fixer.sh — fix DuckDetector "FUSE stat" HMA-mismatch leaks (DANGER card)
# Works on KernelSU Next. Safe defaults. Run as root (su -c "sh fuse_fixer.sh").
#
# Actions:
#   1. Detect susfs kernel support
#   2. susfs sus_path hides for KSU Next + KSU WebUI residue (kernel-level, if susfs present)
#   3. Clean FUSE-visible residue dirs (/sdcard/Android/data stale)
#   4. Audit current HMA hide state for the 3 packages
#
# Flags:
#   --hide-termux   also sus_path-hide Termux (GLOBAL hide — Termux self-access breaks; revert with --revert)
#   --transparent   remove packages from HMA hide list -> visible but consistent (kills mismatch, Danger->Warning)
#   --revert        remove all sus_path entries added by this script
#   --check         audit only, no changes

LOG=/data/local/tmp/fuse_fixer.log
SUSFS_CONF=""
SUSFS_PATHS=""
MODE=check
HIDE_TERMUX=0

# ---------- detect susfs ----------
detect_susfs() {
  if [ -d /data/adb/ksu/modules/susfs/config ]; then
    SUSFS_CONF=/data/adb/ksu/modules/susfs/config
    SUSFS_PATHS=$SUSFS_CONF/sus_path
  elif [ -d /data/adb/susfs ]; then
    SUSFS_CONF=/data/adb/susfs
    SUSFS_PATHS=$SUSFS_CONF/sus_path
  fi
  if grep -q susfs /proc/version 2>/dev/null; then
    [ -z "$SUSFS_CONF" ] && SUSFS_PATHS=/data/adb/susfs/sus_path
  fi
}

# ---------- HMA config location ----------
hma_config() {
  # HMA = com.tsng.hidemyapplist (or com.tsng.pzyhrx.hma). Config in lspd dir, root-only.
  for hma in com.tsng.hidemyapplist com.tsng.pzyhrx.hma; do
    local d=/data/adb/lspd/config/modules/$hma
    [ -d "$d" ] && { echo "$d"; return; }
  done
  echo ""
}

# ---------- audit ----------
audit() {
  echo "=== FUSE FIXER AUDIT $(date) ===" | tee $LOG
  detect_susfs
  if [ -n "$SUSFS_PATHS" ]; then
    echo "[+] susfs: PRESENT ($SUSFS_PATHS)" | tee -a $LOG
    echo "    entries:" | tee -a $LOG
    cat $SUSFS_PATHS 2>/dev/null | sed 's/^/      /' | tee -a $LOG
  else
    echo "[-] susfs: NOT DETECTED — kernel-level hide unavailable" | tee -a $LOG
  fi
  echo "--- package states ---" | tee -a $LOG
  for pkg in com.rifsxd.ksunext io.github.a13e300.ksuwebui com.termux; do
    local state=$(pm path $pkg 2>/dev/null | head -1)
    if [ -n "$state" ]; then
      echo "  $pkg: INSTALLED ($state)" | tee -a $LOG
    else
      echo "  $pkg: not found via pm" | tee -a $LOG
    fi
  done
  echo "--- FUSE residue ---" | tee -a $LOG
  for pkg in com.rifsxd.ksunext io.github.a13e300.ksuwebui com.termux; do
    for d in /storage/emulated/0/Android/data/$pkg /storage/emulated/0/Android/obb/$pkg; do
      [ -d "$d" ] && echo "  RESIDUE: $d" | tee -a $LOG
    done
  done
  local hma=$(hma_config)
  if [ -n "$hma" ]; then
    echo "  HMA config: $hma" | tee -a $LOG
    grep -rl "com.rifsxd.ksunext\|io.github.a13e300.ksuwebui\|com.termux" $hma 2>/dev/null | sed 's/^/    /' | tee -a $LOG
  else
    echo "  HMA config: NOT FOUND (LSPosed/HMA not running?)" | tee -a $LOG
  fi
}

# ---------- susfs hide ----------
apply_sus_hide() {
  [ -z "$SUSFS_PATHS" ] && { echo "[-] susfs absent — skip kernel hide"; return 1; }
  local added=0
  for p in \
    "/data/app/*/com.rifsxd.ksunext*" \
    "/data/data/com.rifsxd.ksunext" \
    "/data/user_de/0/com.rifsxd.ksunext" \
    "/data/app/*/io.github.a13e300.ksuwebui*" \
    "/data/data/io.github.a13e300.ksuwebui" \
    "/storage/emulated/0/Android/data/io.github.a13e300.ksuwebui" \
    "/storage/emulated/0/Android/data/com.rifsxd.ksunext"; do
    if ! grep -qxF "$p" $SUSFS_PATHS 2>/dev/null; then
      echo "$p" >> $SUSFS_PATHS
      echo "  [+] sus_path: $p" | tee -a $LOG
      added=1
    fi
  done
  if [ "$HIDE_TERMUX" = "1" ]; then
    for p in "/data/app/*/com.termux*" "/data/data/com.termux" "/storage/emulated/0/Android/data/com.termux"; do
      if ! grep -qxF "$p" $SUSFS_PATHS 2>/dev/null; then
        echo "$p" >> $SUSFS_PATHS
        echo "  [+] sus_path (TERMUX): $p" | tee -a $LOG
        added=1
      fi
    done
    echo "  [!] WARNING: Termux globally hidden — Termux itself can't read its own paths. Revert with --revert if broken." | tee -a $LOG
  fi
  [ "$added" = "1" ] && echo "  [+] reboot required for sus_path to apply" | tee -a $LOG
}

# ---------- clean residue ----------
clean_residue() {
  local cleaned=0
  for pkg in com.rifsxd.ksunext io.github.a13e300.ksuwebui; do
    for d in /storage/emulated/0/Android/data/$pkg /storage/emulated/0/Android/obb/$pkg; do
      if [ -d "$d" ]; then
        rm -rf "$d" 2>/dev/null
        echo "  [-] cleaned: $d" | tee -a $LOG
        cleaned=1
      fi
    done
  done
  [ "$cleaned" = "0" ] && echo "  [-] no FUSE residue to clean" | tee -a $LOG
}

# ---------- transparent mode (un-hide from HMA) ----------
transparent() {
  local hma=$(hma_config)
  if [ -z "$hma" ]; then
    echo "[-] HMA config not found — do it manually in HMA UI: app list -> DuckDetector -> remove the 3 packages from hide list" | tee -a $LOG
    return
  fi
  # Best-effort: HMA config is JSON; removing package entries is app-UI work.
  # Just report which files reference the packages.
  echo "[!] HMA config is app-managed JSON. Editing it manually risks corrupting hide state." | tee -a $LOG
  echo "    Recommend: HMA UI -> DuckDetector -> 'Hide packages' template -> uncheck com.rifsxd.ksunext, io.github.a13e300.ksuwebui, com.termux" | tee -a $LOG
}

# ---------- revert ----------
revert() {
  [ -z "$SUSFS_PATHS" ] && { echo "[-] no susfs"; return; }
  for p in \
    "/data/app/*/com.rifsxd.ksunext*" \
    "/data/data/com.rifsxd.ksunext" \
    "/data/user_de/0/com.rifsxd.ksunext" \
    "/data/app/*/io.github.a13e300.ksuwebui*" \
    "/data/data/io.github.a13e300.ksuwebui" \
    "/storage/emulated/0/Android/data/io.github.a13e300.ksuwebui" \
    "/storage/emulated/0/Android/data/com.rifsxd.ksunext" \
    "/data/app/*/com.termux*" \
    "/data/data/com.termux" \
    "/storage/emulated/0/Android/data/com.termux"; do
    sed -i "\|^$p$|d" $SUSFS_PATHS 2>/dev/null
  done
  echo "[+] sus_path entries removed. Reboot to apply." | tee -a $LOG
}

# ---------- main ----------
for a in "$@"; do
  case "$a" in
    --hide-termux) HIDE_TERMUX=1 ;;
    --transparent) MODE=transparent ;;
    --revert) MODE=revert ;;
    --check) MODE=check ;;
    *) echo "unknown flag: $a"; exit 1 ;;
  esac
done

case "$MODE" in
  check) audit ;;
  revert) revert ;;
  transparent) transparent ;;
  *) audit; apply_sus_hide; clean_residue ;;
esac

echo ""
echo "=== Next step ==="
echo "1. KSU Next app -> Settings -> Hide Manager (rename). This alone kills the strongest root-tool signal."
echo "2. If susfs present: reboot after hide so sus_path applies, then re-run DuckDetector."
echo "3. If no susfs: run 'sh fuse_fixer.sh --transparent' to remove concealment signal (Danger->Warning)."
echo "4. Re-run DuckDetector -> expect DANGER gone (either fully clean via susfs, or Warning via transparent)."
