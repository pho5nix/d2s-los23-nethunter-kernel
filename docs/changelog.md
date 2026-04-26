# Changelog

## v1.0 - April 26, 2026

Initial public release. Confirmed-working configuration:

- **Device:** Samsung Galaxy Note 10+ (SM-N975F / d2s)
- **ROM:** LineageOS 23.2 microG d2s (March 2026)
- **Kernel base:** FreeRunnerKernel v3.7-R3 (`Lordify97/FreeRunnerKernel`)
- **Kernel version string:** `4.14.356-FrEeRuNnErKeRnEl-v3.7-R3+`
- **Root:** KernelSU-Next v3.2.0-legacy-susfs-v2 (build 33136)
- **Manager:** KernelSU-Next v3.2.0 (build 33129)
- **SuSFS:** v2.1.0 NON-GKI
- **Toolchain:** ZyClang-23 (Clang 23.0.0git, build 20260130)
- **NetHunter:** 2026.1 (Kali rolling minimal chroot)

Build time: ~5:30 min on a modern x86_64 host with ZyClang-23 + ccache + ext4.

### What works

- KernelSU-Next root (`uid=0` in shell)
- SuSFS for hiding from Play Integrity / banking apps
- NetHunter chroot (Kali rolling)
- NetHunter app suite (App, Store, Terminal, KeX)
- mac80211 / cfg80211 (external Wi-Fi adapter monitor mode)
- USB HID gadget (DuckHunter, BadUSB)
- Bluetooth HCI USB/UART/BCM/VHCI
- External wifi: 88XXAU (RTL8814AU), ATH9K_HTC, MT7601U, RTL8XXXU, etc.

### Known limitations

- Magisk does NOT work on this LOS 23 build (Magisk #9515)
- Built-in Broadcom Wi-Fi cannot do monitor mode / injection (vendor blob limitation)
- OneUI ROMs incompatible with this kernel (AOSP-only)
- TWRP not used; boot.img is hand-packed via mkbootimg

### Files in this release

- `prebuilt/d2s-nh-boot.img` - Pre-built ready-to-flash boot.img (51,339,264 bytes)
- `prebuilt/d2s-nh-boot.img.sha256` - checksum
- `boot-img-build/pack-boot-img.sh` - repack helper (build your own)
- Source not redistributed - clone from upstream Lordify97/FreeRunnerKernel
