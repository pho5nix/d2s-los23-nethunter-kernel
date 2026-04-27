# Recovery procedures

If the kernel/manager combination misbehaves and you can't boot, this guide gets you back to a working LineageOS install.

## Symptoms and which path to use

| Symptom | Recovery path |
|---|---|
| Phone stuck at Samsung logo / continuous reboot | A. Re-flash stock boot |
| Boots but root manager shows "v2 signature not found" | B. Re-flash matching APK |
| Boots but `su` returns "not found" | C. Enable Superuser toggle |
| Bootloops + can't reach Download Mode | D. Hard recovery |
| Wi-Fi/cell radios broken after flash | E. Re-flash modem partitions |

---

## A. Re-flash stock boot

Most issues come down to a bad boot.img. Roll back:

```bash
# Hold Vol Down + Power for 15-20 seconds to force off
# Then Vol Down + Vol Up + USB cable to reach Download Mode
# Vol Up to confirm

heimdall detect
heimdall flash --BOOT los-stock-boot.img --no-reboot
# Manually long-press power to reboot
```

You're back to vanilla LineageOS in ~30 seconds.

## B. Re-flash matching manager

If the kernel boots but the manager APK reports a signature mismatch, the kernel's KSU-Next embedded hash doesn't match the APK. Reinstall the exact build:

```bash
adb uninstall com.rifsxd.ksunext
curl -L -o KSU-Next.apk https://github.com/KernelSU-Next/KernelSU-Next/releases/download/v3.2.0/KernelSU_Next_v3.2.0_33129-release.apk
adb install KSU-Next.apk
```

The kernel built from this guide pairs with **build 33129** of the manager.

## C. Enable Superuser

Fresh install of KernelSU-Next manager has Superuser disabled by default. In the manager:

1. Go to **Superuser** tab
2. Toggle the master switch ON at the top
3. Reboot
4. Test `adb shell "su -c id"` → expect `uid=0(root)`

## D. Hard recovery (Download Mode unreachable)

Rare, but if Vol Down + Vol Up doesn't bring up Download Mode:

1. Plug in a working USB-C cable to a powered PC
2. Hold **Vol Down + Bixby + Power** for 30 seconds
3. Release; immediately hold **Vol Down + Vol Up + Power** + plug in the cable
4. If still no Download Mode, drain the battery completely (1–2 days unplugged) and try again

If you have hardware buttons issues, a USB Jig (resistor-shorted USB) can force Download Mode on Exynos Samsungs — search for "Samsung 301k jig".

## E. Re-flash modem (radio dead)

The boot partition this guide flashes does NOT touch modem/radio firmware. If your radios suddenly stop working, that's coincidence.
But to recover in general:

1. Get the **stock Samsung firmware** for your specific CSC from a reputable mirror (SamMobile, etc.)
2. Use Heimdall or Odin to flash only `MODEM` and `MODEM_DEBUG` partitions
3. Reboot

---

## Critical files to keep around

Before you flash anything else archive these:

```
backups/
├── boot-stock.img         # Pre-modification LOS boot
├── dtbo-stock.img         # In case dtbo gets touched
├── vbmeta-stock.img       # AVB rollback recovery
├── efs.img                # IMEI/network-binding (DO NOT LOSE)
├── pit.txt                # Partition layout
└── KSU-Next.apk           # Matching manager APK
```

`efs.img` in particular is irreplaceable. It carries your phone's IMEI, security keys and carrier provisioning. Lose it and you may permanently lose cellular.

---

## When all else fails

Cross-flash the stock Samsung firmware for SM-N975F via Odin (Windows) or Heimdall (Linux). This wipes everything but recovers a brick. You'll lose root and Lineage, you'll need to start over from Stage 0.

Sources for stock firmware (verify SHA before flashing):
- SamMobile (paid for fast download, free with throttle)
- SamFirm.NET (download tool)
- Avoid sketchy mirrors, firmware is often laced with malware on third-party sites.
