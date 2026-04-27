# Troubleshooting

Issues we hit during the original setup in chronological order and how each was resolved. Useful when things look wrong, chances are we've seen the same symptom.

## 1. Magisk-patched boot loops on LOS 23

**Symptom:** Magisk app patches `boot.img` successfully but the device boot-loops (Samsung logo → reboot) after flashing.

**Tried:** Two different patched boots, vbmeta-disabled, fresh install.

**Conclusion:** Open issue (Magisk #9515 unresolved). Confirmed broken on LineageOS 23.x for d2s as of April 2026. **Use KernelSU-Next instead.**

---

## 2. KSU 0.9.5 with kprobes - "Unsupported"

**Symptom:** Kernel boots, manager APK launches but home screen says **"Unsupported"**.

**Cause:** Stock kprobe path in upstream, KSU 0.9.5 expects newer kernel features that 4.14.356 doesn't implement consistently.

**Solution:** Skip KSU 0.9.5. Use KernelSU-Next.

---

## 3. KSU 0.9.5 with manual hooks - `task_prctl` doesn't fire

**Symptom:** Kernel patched with manual hooks in `fs/exec.c`, `fs/open.c`, `fs/read_write.c`, `fs/stat.c`, `drivers/input/input.c`, `fs/devpts/inode.c`. dmesg shows `KernelSU: stop input_hook` and `stop execve_hook` firing, but the LSM hook `task_prctl` never triggers post-boot.

**Cause:** Same as Issue #1874 in KernelSU repo (another N975F user, also unresolved). Likely SELinux LSM ordering on this Samsung kernel branch.

**Solution:** Skip manual hooks. Use KernelSU-Next legacy-susfs-v2.

---

## 4. KernelSU-Next legacy from main repo - hash mismatch

**Symptom:** Kernel boots, manager v1.1.1 launches and shows: **"KernelSU Next v2 signature not found in kernel! [!KSU_NEXT || != size/hash]"**

**Cause:** The `legacy` branch of `KernelSU-Next/KernelSU-Next` has a different embedded manager hash than the one ship in v1.1.1 APK. Branches drift, tags don't.

**Solution:** Use `sidex15/KernelSU-Next` branch `legacy-susfs-v2` (commit `00cb93e`). This has hash `79e590113c4c4c0c222978e413a5faa801666957b1212a328e46c00c69821bf7` and size `0x3e6` — matching the v3.2.0 build 33129 manager APK.

---

## 5. V0lk3n NetHunter kernel - works for NetHunter but no KSU root

**Symptom:** Kernel boots with mac80211/cfg80211 modules visible (`/sys/module/`). HID gadget files exist. But `su` is not present and KSU-Next won't initialize.

**Cause:** V0lk3n's NetHunter port doesn't include any KSU integration, it's a pure NetHunter kernel.

**Solution:** Switched to FreeRunner kernel which has both NetHunter (via `nethunter.config`) AND KSU-Next built in.

---

## 6. WSL2 / NTFS - `xt_HL.o` missing target

**Symptom:** Kernel build halts with:
```
make[3]: *** No rule to make target 'net/netfilter/xt_HL.o', needed by 'net/netfilter/built-in.o'.  Stop.
```

**Cause:** The Linux netfilter tree has TWO separate source files — `xt_HL.c` (TARGET, hop-limit modify) and `xt_hl.c` (MATCH, hop-limit match). On a case-insensitive filesystem (Windows NTFS via WSL2 `/mnt/x`), these collapse to the same inode. One overwrites the other on git checkout. The build then misses one of the two files.

**Diagnostic:**
```bash
stat -c '%i %n' net/netfilter/xt_HL.c net/netfilter/xt_hl.c
```
If both report the same inode number, the FS is case-insensitive.

**Resolution:** Build in your Linux home directory (ext4) or any case-sensitive volume. Never `/mnt/c`, `/mnt/x`, or any NTFS/exFAT/APFS-on-Windows mount.

We confirmed:
- `/tmp` (ext4) - case-sensitive ✅
- `/home/$USER` (ext4) - case-sensitive ✅
- `/mnt/x` (drvfs/9p over NTFS) - case-INsensitive ❌

---

## 7. d2s bootloader rejects `Image.gz-dtb`

**Symptom:** boot.img packed with `Image.gz-dtb` (compressed kernel + appended DTB) → boot loop. boot.img with raw `Image` (uncompressed) → works.

**Cause:** Samsung d2s bootloader doesn't decompress `Image.gz` even though stock kernels are gzip-shipped. The DTB is loaded from a separate partition (`dtb`/`dtbo`) on this device, not appended.

**Solution:** Always pack `Image` (raw, ~50 MB) — never `Image.gz` or `Image.gz-dtb`. This is what `pack-boot-img.sh` does.

---

## 8. KernelSU-Next manager build mismatch

**Symptom:** Manager works but reports build 33129 while kernel reports build 33136.

**Cause:** Kernel built from `legacy-susfs-v2` branch which is *ahead* of the v3.2.0 release tag (33129). Branches accumulate fixes that aren't tagged.

**Solution:** Cosmetic warning only. The signature/hash check passes because `KSU_NEXT_MANAGER_HASH` and `_SIZE` are still pinned to v3.2.0 values in the Kbuild. Newer kernel build numbers within the same major version are forward-compatible.

---

## 9. BusyBox installer - "No space left on device"

**Symptom:** Meefik BusyBox app's "Install" button reports:
```
Copying busybox to /system/xbin ... fail
cp: write error: No space left on device
```

**Cause:** Android 16 with dynamic partitions - `/system` is read-only OverlayFS-style, regardless of `mount -o remount,rw`.

**Solution:** Skip the BusyBox app installer. Use KSU's bundled busybox:

```bash
adb shell "su -c 'mkdir -p /data/local/xbin && ln -sf /data/adb/ksu/bin/busybox /data/local/xbin/busybox'"
```

NetHunter app finds it via path scan and works fine.

---

## 10. KSU-Next "Mount system: Meta | Not installed"

**Status:** Not actually a problem. Metamodule is for modules that need to overlay `/system` files. NetHunter doesn't need that, it operates entirely from `/data/local/nhsystem/` (the chroot).

If you do want metamodule support later install `meta-overlayfs` from KSU-Next module repo.

---

## 11. Kali chroot - `apt update` hangs / firewalled

**Symptom:** `apt update` shows `Ign:1 http://http.kali.org/kali kali-rolling InRelease` and stalls at 0%.

**Causes (any of):**
- DNS not configured in chroot (`/etc/resolv.conf` empty)
- Firewall blocks outbound to Kali repos
- Network proxy not propagated into chroot

**Resolution:**
```bash
# In NetHunter Terminal → KALI session
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# Test raw connectivity
ping -c 2 1.1.1.1            # Routing/firewall test
ping -c 2 google.com         # DNS test

# If on a proxied network:
export http_proxy=http://proxy:port
export https_proxy=http://proxy:port
apt update
```

Allow these on your firewall: `*.kali.org`, `kali.download`, ports 80 + 443.
