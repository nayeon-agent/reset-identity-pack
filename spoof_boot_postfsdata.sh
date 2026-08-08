#!/system/bin/sh
# ============================================================
#  99-spoof-boot.sh — PRE-ZYGOTE identity props (post-fs-data)
#  ============================================================
#  Jalan SEBELUM zygote fork → android.os.Build.* constants
#  ikut ke-spoof (Build.BOOTLOADER, Build.MODEL, dll).
#  service.d (late_start) TERLAMBAT — Build sudah di-cache.
#
#  Fix: ro.boot.bootloader (Build.BOOTLOADER = N950FXXUGDVG5
#  di report DuckDetector) + re-apply fingerprint biar semua
#  Build constant konsisten S22.
#
#  Aman: gak set prop berbahaya (ro.debuggable/ro.secure/
#  vbmeta/flash.locked) — itu tetap di service.d/biarkan.
# ============================================================

TGT_MODEL="SM-S901B"
TGT_DEVICE="r0s"
TGT_PRODUCT="r0sxxx"
TGT_FP="samsung/r0sxxx/r0s:16/BP2A.250605.031.A3/S901BXXSNGZD7:user/release-keys"
TGT_BOOTLOADER="S901BXXSNGZD7"
TGT_BUILD_ID="BP2A.250605.031.A3"
TGT_SECPATCH="2026-08-05"

# Bootloader — kernel cmdline baca ini; set sebelum zygote
resetprop -n ro.boot.bootloader "$TGT_BOOTLOADER"
# Build.BOOTLOADER baca "ro.bootloader" (bukan ro.boot.bootloader!)
# AOSP Build.java: BOOTLOADER = getString("ro.bootloader")
resetprop -n ro.bootloader "$TGT_BOOTLOADER"

# Fingerprint semua partition
resetprop -n ro.build.fingerprint "$TGT_FP"
resetprop -n ro.system.build.fingerprint "$TGT_FP"
resetprop -n ro.vendor.build.fingerprint "$TGT_FP"
resetprop -n ro.bootimage.build.fingerprint "$TGT_FP"
resetprop -n ro.odm.build.fingerprint "$TGT_FP"
resetprop -n ro.product.build.fingerprint "$TGT_FP"

# Flavor + description (Build.FLAVOR / Build.DESCRIPTION)
resetprop -n ro.build.flavor "${TGT_PRODUCT}-user"
resetprop -n ro.build.description "${TGT_PRODUCT}-user $TGT_BUILD_ID user release-keys"
resetprop -n ro.build.id "$TGT_BUILD_ID"
resetprop -n ro.build.display.id "$TGT_BUILD_ID"

# Model — semua partition (Build.MODEL)
resetprop -n ro.product.model "$TGT_MODEL"
resetprop -n ro.product.system.model "$TGT_MODEL"
resetprop -n ro.product.vendor.model "$TGT_MODEL"
resetprop -n ro.product.odm.model "$TGT_MODEL"
resetprop -n ro.product.device "$TGT_DEVICE"
resetprop -n ro.product.name "$TGT_PRODUCT"
resetprop -n ro.product.product "$TGT_PRODUCT"

# Security patch per-partition
resetprop -n ro.build.version.security_patch "$TGT_SECPATCH"
resetprop -n ro.system.build.version.security_patch "$TGT_SECPATCH"
resetprop -n ro.vendor.build.version.security_patch "$TGT_SECPATCH"
resetprop -n ro.product.build.version.security_patch "$TGT_SECPATCH"

# Build host/user (Build.HOST / Build.USER)
resetprop -n ro.build.host "21DN2919"
resetprop -n ro.build.user "dpi"

exit 0
