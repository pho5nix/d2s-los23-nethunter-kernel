#!/bin/bash
# pack-boot-img.sh
# Pack a boot.img using a freshly-built kernel Image and the LOS stock ramdisk.
# Tested on Samsung Galaxy Note 10+ (SM-N975F, d2s) running LineageOS 23.2.
set -euo pipefail

# --- Edit these two paths ---
KERNEL_IMAGE="${KERNEL_IMAGE:-$HOME/d2s-build/freerunner-src/out/d2s/arch/arm64/boot/Image}"
LOS_STOCK_BOOT="${LOS_STOCK_BOOT:-./los-stock-boot.img}"
OUTPUT="${OUTPUT:-d2s-nh-boot.img}"

# --- Constants for d2s on LineageOS 23 ---
HEADER_VERSION=1
OS_VERSION="16.0.0"
OS_PATCH_LEVEL="2026-03"
PAGESIZE=0x00000800
BASE=0x00000000
KERNEL_OFFSET=0x10008000
RAMDISK_OFFSET=0x11000000
SECOND_OFFSET=0x00000000
TAGS_OFFSET=0x10000100
CMDLINE=' androidboot.super_partition=system'
BOOT_PARTITION_LIMIT=57671680  # PIT entry #23

# --- Sanity checks ---
[ -f "$KERNEL_IMAGE" ] || { echo "ERROR: KERNEL_IMAGE not found: $KERNEL_IMAGE"; exit 1; }
[ -f "$LOS_STOCK_BOOT" ] || { echo "ERROR: LOS_STOCK_BOOT not found: $LOS_STOCK_BOOT"; exit 1; }
command -v mkbootimg >/dev/null 2>&1 || { echo "ERROR: mkbootimg not in PATH (pip install --user mkbootimg)"; exit 1; }
command -v abootimg  >/dev/null 2>&1 || { echo "ERROR: abootimg not in PATH (apt install abootimg)"; exit 1; }

# --- Extract LOS stock ramdisk ---
WORK=$(mktemp -d)
trap "rm -rf $WORK" EXIT
echo "[*] Extracting LOS stock ramdisk into $WORK..."
( cd "$WORK" && abootimg -x "$(realpath "$LOS_STOCK_BOOT")" bootimg.cfg zImage initrd.img dtb )

# --- Pack ---
echo "[*] Packing $OUTPUT ..."
mkbootimg \
  --header_version "$HEADER_VERSION" \
  --os_version "$OS_VERSION" \
  --os_patch_level "$OS_PATCH_LEVEL" \
  --kernel "$KERNEL_IMAGE" \
  --ramdisk "$WORK/initrd.img" \
  --pagesize "$PAGESIZE" \
  --base "$BASE" \
  --kernel_offset "$KERNEL_OFFSET" \
  --ramdisk_offset "$RAMDISK_OFFSET" \
  --second_offset "$SECOND_OFFSET" \
  --tags_offset "$TAGS_OFFSET" \
  --board '' \
  --cmdline "$CMDLINE" \
  -o "$OUTPUT"

SIZE=$(stat -c '%s' "$OUTPUT")
echo "[+] Built $OUTPUT (${SIZE} bytes, partition limit ${BOOT_PARTITION_LIMIT})"

if [ "$SIZE" -gt "$BOOT_PARTITION_LIMIT" ]; then
  echo "[!] WARNING: boot.img exceeds partition limit. Strip kernel modules or use a smaller config."
  exit 2
fi

echo "[+] Ready to flash:"
echo "    heimdall flash --BOOT $OUTPUT --no-reboot"
