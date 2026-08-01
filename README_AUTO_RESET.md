# 📦 Reset Identity — Full Stack Pack (NO 3rd Party Module)

Isi pack:

| File | Fungsi | Lokasi pakai |
|------|--------|--------------|
| `reset_identity.sh` | Full reset orchestrator | HP (Termux) |
| `spoof_props.sh` | Build fingerprint + device props | HP (Termux) |
| `imei_spoof.sh` | ril.* IMEI props (best-effort) | HP (Termux) |
| `ip_rotator.sh` | Rotate IP (WiFi/airplane) | HP (Termux) |
| `auto_reset_loop.sh` | Daemon loop reset periodik | HP (Termux) |
| `install.sh` | Installer + boot autostart | HP (Termux) |
| `README_AUTO_RESET.md` | File ini | — |

## 🚀 Install

### Di HP (Termux):
```bash
mkdir -p ~/spoof
cp /sdcard/Download/*.sh ~/spoof/
cd ~/spoof
bash install.sh
```

## ▶️ Cara Pakai di HP

```bash
# Full reset sekali (WiFi IP rotate)
bash ~/spoof/reset_identity.sh

# Full reset skip IP (kalo udah VPN manual)
bash ~/spoof/reset_identity.sh skip

# Komponen terpisah
bash ~/spoof/spoof_props.sh        # build fp + props doang
bash ~/spoof/imei_spoof.sh         # IMEI props doang
bash ~/spoof/ip_rotator.sh airplane  # rotate IP via airplane
bash ~/spoof/ip_rotator.sh wifi    # rotate IP via WiFi DHCP

# Daemon loop tiap 10 menit (full reset)
bash ~/spoof/auto_reset_loop.sh 600

# Stop daemon
killall auto_reset_loop.sh
```

## ⚙️ Edit Target Device (spoof_props.sh)

Default: **Samsung Galaxy S25 Ultra (SM-S938B)**.
Edit variabel `TGT_*` di atas file `spoof_props.sh`:
```bash
TGT_MODEL="SM-S938B"
TGT_DEVICE="pa3q"
TGT_FINGERPRINT="samsung/pa3qxxx/pa3q:16/BP2A.250605.031.A3/S938BXXU1BYC9:user/release-keys"
```

## 📝 Edit Target App (reset_identity.sh)

Default: Shopee, Tokped, TikTok. Edit `TARGET_APPS`:
```bash
TARGET_APPS=(
  "com.shopee.id"
  "com.tokopedia.tkpd"
  "com.ss.android.ugc.aweme"
)
```

## ⚠️ Batasan Jujur

| Sinyal | Status | Keterangan |
|--------|--------|------------|
| Build fingerprint | ✅ Bisa | resetprop — semua partition |
| ro.serialno, hostname | ✅ Bisa | random tiap run |
| Boot state (locked/green) | ✅ Bisa | konsisten dgn TrickyStore |
| MAC address | ✅ Bisa | kernel-level ip link |
| GAID | ✅ Bisa | cmd advertising_id reset |
| App data / SSAID | ✅ Bisa | pm clear → SSAID baru |
| IP address (wifi/airplane) | ✅ Bisa | Tanpa VPN/wg-tools |
| IMEI (props level) | ⚠️ Partial | ril.* props; app yg pake TelephonyManager tetap lihat asli |
| IMEI (binder level) | ❌ Gak bisa | butuh Xposed/LSPosed (Android Faker) |

## 🛡️ Tips Anti-Deteksi Tambahan

1. **Ganti IP** dulu sebelum buka app target (airplane toggle paling reliable di HP tanpa setup)
2. **Tunggu 30-60 detik** setelah reset biar Play Services sync
3. **Email & nomor HP beda** per akun (wajib)
4. **E-wallet / payment method beda** per akun
5. **Jeda 24-72 jam** antara akun baru
6. **Jangan pakai emulator** — TikTok/Shopee/Tokped deteksi emulator via sensor

## 🧩 Module WAJIB di HP

- Magisk + Zygisk (untuk resetprop)
- TrickyStore (boot state spoof)
- Shamiko (root hide)

## 🧩 Module OPTIONAL

- LSPosed + Android Faker (IMEI full spoof)
- DeviceSpoofLab-Magisk (alternative props spoof via GUI)
- PlayIntegrityFork (Play Store certified fingerprint)
