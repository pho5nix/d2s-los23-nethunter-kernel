# Kali NetHunter - SM Galaxy Note 10+ (d2s / SM-N975F)

Custom kernel + KernelSU-Next + Kali NetHunter on **LineageOS 23.2 microG** (Android 16) for the Exynos 9825 Note 10+.

This guide is the result of a multi-day reverse-engineering. It documents the **only known working path** as of April 2026 for this device on LineageOS 23.

**Tested working configuration**
- Device: Samsung Galaxy Note 10+ (SM-N975F, codename `d2s`, Exynos 9825)
- ROM: LineageOS 23.2 microG d2s (March 2026 build)
- Kernel: `4.14.356-FrEeRuNnErKeRnEl-v3.7-R3+`
- Root: KernelSU-Next v3.2.0-legacy-susfs-v2 (build 33136)
- Manager: KernelSU-Next v3.2.0 (build 33129)
- SuSFS: v2.1.0 (NON-GKI)
- NetHunter: 2026.1 / Kali rolling chroot

---

## Reasons for creating this guide

**Magisk does not boot on LineageOS 23 d2s** (open issue, both vbmeta-disabled and patched ramdisks bootloop). KernelSU-Next is the only viable root path. Most online guides target older Android versions or different forks and Note 10+ users on LOS 23 hit five separate dead ends before this approach worked:

1. KSU 0.9.5 with kprobes - manager reports "Unsupported"
2. KSU 0.9.5 with manual hooks - hooks fire in dmesg but `task_prctl` LSM never triggers
3. KernelSU-Next legacy branch from main repo - manager hash mismatch
4. V0lk3n's NetHunter kernel - boots, but no working KSU integration
5. Direct kernel build on `/mnt/x` (WSL2 / NTFS) - case-insensitive filesystem corrupts `xt_HL.c` ↔ `xt_hl.c` (different files in upstream, same inode on NTFS)

The working approach uses **FreeRunner kernel source** (`Lordify97/FreeRunnerKernel`) which already integrates `sidex15/KernelSU-Next` `legacy-susfs-v2` branch correctly, plus the bundled `nethunter.config` fragment, built on a **case-sensitive ext4 filesystem**.

---

## Hardware/software prerequisites

- Device: Samsung Galaxy Note 10+ (SM-N975F). Codename: d2s. SoC: Exynos 9825
- OEM unlocked bootloader (Settings → Developer options → OEM unlocking)
- LineageOS 23.2 microG (or any LOS 23 build) flashed and booted
- A Linux build host (or WSL2 with build dir on **ext4** - NOT on `/mnt/c`, `/mnt/x`, etc.)
  - Recommended: ~10 GB free on ext4
  - 16 GB+ RAM, 8+ CPU cores ideal
- Heimdall flasher (Linux/macOS/Windows)
- ADB
- Approximately 4 GB total downloads (toolchain, source, chroot)
- Zadig (for binding WinUSB to the gadget serial device - check Device Manager if on Windows)

**WSL2 case-insensitivity warning**: If you use WSL2 on Windows, build *only* under `~/` (your Linux home dir, ext4). Building on `/mnt/x/...` or `/mnt/c/...` (NTFS via 9p) will silently fail because `xt_HL.c` and `xt_hl.c` collide. This is also true for `/mnt/wsl` and any drvfs mount.

---

## Stage 1 - Backup everything

Boot to **Download Mode** (`Vol Down + Vol Up + USB cable`) and dump these partitions before anything:

```bash
heimdall print-pit > pit.txt    # PIT layout reference
heimdall download-pit --output backup.pit
# Use a Heimdall GUI or specific commands per partition for:
#   boot, dtbo, vbmeta, efs
```

Keep these images safe - they let you roll back if anything goes wrong.

---

## Stage 2 - Set up the build environment

On your Linux/WSL2 host, in your **ext4** home directory:

```bash
mkdir -p ~/android/toolchains
cd ~/android/toolchains

# Download ZyClang-23 (the toolchain FreeRunner is built/tested with)
wget https://github.com/ZyCromerZ/Clang/releases/download/23.0.0git-20260130-release/Clang-23.0.0git-20260130.tar.gz
mkdir -p ZyClang-23 && cd ZyClang-23
tar xzf ../Clang-23.0.0git-20260130.tar.gz
./bin/clang --version    # should print "ZyC clang version 23.0.0git"
```

Tools you also need: `git`, `zip`, `make`, `bc`, `flex`, `bison`, `libssl-dev`, `python3`, `ccache` (optional but speeds up rebuilds).

```bash
sudo apt update
sudo apt install -y git zip make bc flex bison libssl-dev python3 ccache abootimg
# For boot.img repacking (mkbootimg):
pip install --user mkbootimg
```

---

## Stage 3 - Clone and build the kernel

```bash
mkdir -p ~/d2s-build && cd ~/d2s-build
git clone https://github.com/Lordify97/FreeRunnerKernel.git freerunner-src
cd freerunner-src
git submodule update --init --recursive
```

This pulls KernelSU-Next at tag `v3.2.0-legacy-susfs-v2` (commit `00cb93e`) as a submodule. **Do not** swap to a different KSU-Next branch, the legacy-susfs-v2 fork is what matches the embedded manager hash.

Patch `build.sh` for your environment (it expects ZyClang-23 in `~/Android/ToolChain/`):

```bash
# Point to our toolchain location
sed -i 's|TOOLCHAIN_DIR=.*|TOOLCHAIN_DIR="$HOME/android/toolchains/ZyClang-23"|' build.sh

# We don't need GitHub CLI for local builds
sed -i 's|for cmd in git zip gh; do|for cmd in git zip; do|' build.sh
```

Sanity check that the case-collision-prone files are distinct:

```bash
stat -c '%i %n' net/netfilter/xt_HL.c net/netfilter/xt_hl.c
# Two different inode numbers = ext4, you're good.
# Same inode = case-insensitive filesystem, build will fail.
```

Build:

```bash
./build.sh
# Prompt 1: Build type → 3 (KernelSU-Next + NetHunter)
# Prompt 2: Device     → 7 (d2s)
```

Build time: **~5–8 min** with ZyClang-23 + ccache on a modern machine. The script merges `arch/arm64/configs/nethunter.config` onto `exynos9820-d2s_defconfig`, so you get NetHunter features (mac80211, USB HID gadget, RTL8814AU/MT7601U/etc., Bluetooth, hostname=`kali`) on top of stock LOS d2s config.

Output:
- Image: `out/d2s/arch/arm64/boot/Image` (~50 MB, raw uncompressed)
- AnyKernel zip: `releases/ksu-nethunter/FrEeRuNnErKeRnEl-d2s-v3.7-KernelSU-Next-v3.2.0-NetHunter-Anykernel3.zip`

---

## Stage 4 - Pack the boot.img

The d2s bootloader **does not decompress `Image.gz`** even though stock kernels ship gzipped. You must pack the raw `Image` directly. AnyKernel zips assume custom recovery but we don't have TWRP, so we build our own boot.img using the LOS stock ramdisk:

```bash
mkdir -p /tmp/d2s-flash && cd /tmp/d2s-flash

# Copy your LineageOS stock boot.img here as los-stock-boot.img
# Yyou can dump it via Heimdall or extract it from the LOS zip

# Extract stock ramdisk (we keep LOS init + properties)
mkdir unpacked && cd unpacked
abootimg -x ../los-stock-boot.img bootimg.cfg zImage initrd.img dtb
cd ..

# Copy the kernel we just built
cp ~/d2s-build/freerunner-src/out/d2s/arch/arm64/boot/Image .

# Pack new boot.img
mkbootimg \
  --header_version 1 \
  --os_version 16.0.0 \
  --os_patch_level 2026-03 \
  --kernel Image \
  --ramdisk unpacked/initrd.img \
  --pagesize 0x00000800 \
  --base 0x00000000 \
  --kernel_offset 0x10008000 \
  --ramdisk_offset 0x11000000 \
  --second_offset 0x00000000 \
  --tags_offset 0x10000100 \
  --board '' \
  --cmdline ' androidboot.super_partition=system' \
  -o d2s-nh-boot.img

# Sanity-check size
ls -la d2s-nh-boot.img
# Must be < 57671680 bytes (BOOT partition limit per PIT entry #23)
```

The offsets above match what `abootimg -x` reports for the LOS stock boot.img on this device. If you build for a different ROM re-extract and use that ROM's offsets.

---

## Stage 5 - Flash

Boot phone to **Download Mode** (`Vol Down + Vol Up + cable`, then `Vol Up` to confirm):

```bash
# Linux
heimdall detect
heimdall flash --BOOT d2s-nh-boot.img --no-reboot
# manually reboot when ready
```

Windows:

```powershell
.\heimdall.exe detect
.\heimdall.exe flash --BOOT d2s-nh-boot.img --no-reboot
```

If the device gets stuck or detection fails, re-install the **Samsung USB driver** and use **Zadig** to bind WinUSB to the gadget serial device.

---

## Stage 6 - Install KernelSU-Next manager

Phone boots into LineageOS as normal. Verify the kernel is live:

```bash
adb shell uname -a
# Linux ... 4.14.356-FrEeRuNnErKeRnEl-v3.7-R3+ ...

adb shell ls /sys/module/ | grep -E 'mac80211|cfg80211'
# mac80211, cfg80211

adb logcat -d | grep -i kernelsu | head -10
# Should show "KernelSU: /system/bin/init second_stage executed"
```

Install the matching manager APK (must match build 33129/33136):

```bash
curl -L -o KSU-Next.apk https://github.com/KernelSU-Next/KernelSU-Next/releases/download/v3.2.0/KernelSU_Next_v3.2.0_33129-release.apk
adb install KSU-Next.apk
```

Open the KSU manager. You should see:
- **Working** Built-in (Legacy)
- Version: v3.2.0-legacy-susfs-v2 (33136)
- Hook mode: Manual
- SuSFS version: Supported / v2.1.0 (NON-GKI)

**If the manager shows "v2 signature not found":** you've installed the wrong manager build. The kernel and manager must share the same KSU-Next signature. Always use the v3.2.0 build 33129 APK paired with this kernel.

In the manager:
1. Go to **Superuser** tab
2. Enable the master toggle (top of the list), by default fresh installs leave Superuser disabled

Reboot. Test:

```bash
adb shell "su -c id"
# uid=0(root) gid=0(root) groups=0(root) context=u:r:ksu:s0
```

If you get `uid=0` root works.

---

## Stage 7 - NetHunter userspace

Download the NetHunter app suite:

```bash
# NetHunter Store
curl -L -o NetHunterStore.apk https://store.nethunter.com/NetHunterStore.apk

# NetHunter App (use the latest version from store.nethunter.com)
curl -L -o NetHunter.apk https://store.nethunter.com/repo/com.offsec.nethunter_2026040200.apk

# NetHunter Terminal
curl -L -o NetHunterTerm.apk https://store.nethunter.com/repo/com.offsec.nhterm_2026010400.apk

# BusyBox (from F-Droid — the store version may 404)
curl -L -o BusyBox.apk https://f-droid.org/repo/ru.meefik.busybox_51.apk

adb install NetHunterStore.apk
adb install NetHunter.apk
adb install NetHunterTerm.apk
adb install BusyBox.apk
```

Grant root to all four apps in **KernelSU-Next → Superuser** before continuing.

### BusyBox handling on Android 16 dynamic partitions

The Meefik BusyBox app tries to write to `/system/xbin`, which is read-only. **Skip the in-app installer.** KernelSU-Next ships its own busybox at `/data/adb/ksu/bin/busybox`. Symlink it where NetHunter can find it:

```bash
adb shell "su -c 'mkdir -p /data/local/xbin && ln -sf /data/adb/ksu/bin/busybox /data/local/xbin/busybox'"
```

Open the **NetHunter** app. It auto-detects busybox via the symlink.

### Install Kali chroot

In NetHunter app:
1. Hamburger menu → **Kali Chroot Manager**
2. **Install Chroot** → **Download latest** → **MINIMAL** (~600 MB, full version is much larger)
3. Wait for download + decompression (10–20 min on decent wifi)
4. When prompted, **Mount the environment**

### DNS / network in the chroot

Kali chroot doesn't always inherit Android's resolver. If `apt update` hangs or DNS fails:

```bash
# In NetHunter Terminal → KALI session
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
ping -c 3 1.1.1.1
```

If your network has a firewall, allow outbound to Kali repo CDN (`*.kali.org`, `kali.download`) on port 80/443.

### Install metapackages

Open NetHunter Terminal → KALI session. Pick what you need rather than everything:

| Metapackage | Tools | When to use |
|---|---|---|
| `kali-linux-nethunter` | NetHunter-specific (DuckHunter, MITMf, etc.) | Always |
| `kali-tools-wireless` | aircrack-ng, kismet, wifite, reaver, hostapd | Wi-Fi attacks |
| `kali-tools-sniffing-spoofing` | wireshark, tcpdump, ettercap, bettercap, responder | MITM/sniffing |
| `kali-tools-web` | burp, sqlmap, gobuster, nikto, wpscan | Web app pentesting |
| `kali-tools-passwords` | hydra, john, hashcat | Password attacks |
| `kali-tools-information-gathering` | nmap, masscan, recon-ng | Recon |
| `kali-linux-default` | All of the above + more (~3 GB) | Full toolkit |

Minimal-footprint pentester install:

```bash
apt update
apt install -y kali-linux-nethunter kali-tools-wireless kali-tools-sniffing-spoofing
```

Each metapackage takes 10–30 min depending on size and connection.

---

## Stage 8 - Enable HID / BadUSB / monitor mode

After everything's installed:

- **HID attacks** (USB Arsenal): NetHunter app → **USB Arsenal** → enable HID → grant DuckHunter permissions
- **Wi-Fi monitor mode**: external adapter recommended (built-in Broadcom doesn't support injection). Tested working: RTL8814AU (88XXAU driver), Atheros AR9271 (ATH9K_HTC), MT7601U. All compiled in via nethunter.config.
- **BadUSB**: USB Arsenal → BadUSB MITM → connect as gadget

---

## Things that will NOT work

| Component | Reason |
|---|---|
| Magisk on LOS 23 d2s | Boot loops on every variant tested |
| KSU 0.9.5 (any hook mode) | LSM hooks don't fire on this kernel |
| Built-in Wi-Fi monitor mode | Broadcom firmware blob refuses inject |
| OneUI ROM with this kernel | AOSP-only, will not boot |
| TWRP install via flashable zip | We don't have TWRP. That's why we hand-pack boot.img |
| Building on `/mnt/c`, `/mnt/x`, NTFS | Case-insensitive FS corrupts kernel source |
| `Image.gz-dtb` | d2s bootloader expects raw `Image`, not gzipped |

---

## Recovery

If the new kernel boot loops:

1. Force off (`Vol Down + Power` 15–20 sec)
2. Vol Down + Vol Up + USB cable → Download Mode
3. Re-flash the original LOS stock boot:

```bash
heimdall flash --BOOT los-stock-boot.img
```

You're back to vanilla LOS 23 in 30 seconds. Keep `los-stock-boot.img` somewhere safe.

---

## Credits

This setup stands on work by many people. None of this would exist without them.

- **@Lordify97** - FreeRunnerKernel source maintainer (the build that finally worked)
- **@FreeRunner4ever** / **@LeDrew2017** - original FreeRunnerKernel author
- **@linux4** - Exynos 9820/9825 device trees and kernel base
- **@sidex15** - KernelSU-Next legacy-susfs-v2 fork (the one with the matching signature)
- **@rifsxd** - KernelSU-Next maintainer
- **@simonpunk** - susfs4ksu
- **@tiann** - original KernelSU
- **@ZyCromerZ** - ZyClang toolchain
- **Offensive Security / Kali team** - NetHunter framework
- **LineageOS team** - base ROM

This guide just connects the dots that already exist. Full credit belongs upstream.

---

## Files in this repo

```
├── README.md                              # This file
├── boot-img-build/
│   ├── pack-boot-img.sh                   # Stage 4 helper script
│   └── bootimg.cfg.reference              # Reference offsets/cmdline
├── prebuilt/
│   ├── d2s-nh-boot.img                    # Ready-to-flash boot.img (optional)
│   └── d2s-nh-boot.img.sha256
├── docs/
│   ├── recovery.md                        # Detailed recovery procedures
│   ├── troubleshooting.md                 # Issues we hit and how we fixed them
│   └── changelog.md                       # Per-build notes
└── LICENSE                                # GPL-2.0 (kernel) + project license
```

---

## License

The kernel source itself is **GPL-2.0** (Linux kernel). The boot.img repacking scripts and this documentation are **MIT** unless otherwise noted. Respect upstream licenses for KernelSU-Next, NetHunter and FreeRunnerKernel.

---

## Disclaimer

This is a security research / penetration-testing setup. Use it on networks and devices you own or have explicit written permission to test. The author and contributors are not responsible for misuse.I am not responsible if you brick your phone(ALWAYS backup and READ the instructions SLOW and CAREFULLY). Bricked phones happen, read the recovery section before flashing.
