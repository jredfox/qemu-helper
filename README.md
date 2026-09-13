# qemu-helper
 Easily Setup QEMU Today on Linux with KVM

# FAQ
- Q: Why won't my Ubuntu ARM32/ARM64 ISO won't boot?
  A: Older Linux ARM64 Images may not fully support EFI/UEFI. Enable Kernal Boot to fix this and Configure it if required
- Q: I Enabled Kernal Boot and my Ubuntu (16.10 or older) won't boot or doesn't detect the virtual disk and or ISO. The kernal is probably broken that it found under /install/vmlinuz and you have to Configure Kernal Boot or use a different ISO Image.
- Q: How to fix Ubuntu (16.10 and below) install mirrors not working. Go to select a mirro, scroll all the way to the top where it says "enter a mirror manually" and click enter. Enter "old-releases.ubuntu.com" for the mirror and "/ubuntu/" for the path without the double quotes.
- Q: How to download older Ubuntu x86(32 bit)/x86_64/ARM64/ARM Images
  A: http://old-releases.ubuntu.com
- Q: How to download Ubuntu Server Risc-V Image? Download The RISC-V Framework image https://ubuntu.com/download/risc-v/canonical-built#deepcomputing-fml13v01 making sure NOT to download the live installer as that takes forever to boot just to give you a live usb session with no option to install ubuntu to the virtual disk
- Q: Alpine / Ubuntu IMB-Z (s390x) `switch_root: can't open '/dev/hvc0': No such file or directory`
  A: This is usually safe to ignore as it should fall back to "ttysclp0" console and should only happen when kernal booting. To fix this error message and increase boot time by up to 1 second go into your alpine or ubuntu boot script and add this line `export kb_console=ttysclp0` this of course requires kernal booting to be on.

# Kernal Boot
Kernal boot mode is a mode that allows qemu-helper to boot kernal directly by dynamically getting the kernal and initrd file to boot linux. sometimes the kernal it finds is broken and doesn't work with qemu. When this happens you need to manually configure specify the kernal and initrd yourself. both kb_path and `kb_initrd`

# Enable Kernal Boot By Changing File Names:
- Change the ISO name to contain "-kb-"
- run setup.sh again
- if you already have an installed disk rename the qcow2 image to match the new empty one and run the normal boot script for that distro

# Enable Kernal Boot By Using Export:
- Open Open ~/vms/disks/<MyLinux_iso.sh> and ~/vms/disks/<MyLinux.sh>
- Add `export kb="true"`

# Kernal Boot Config:
- run findkernal.sh <MyLinux.ISO> this will print most the kernal paths and initrd paths found within the ISO. if it fails to find you will have to manually mount the iso and locate the kernal (vmlinuz or linux) and initrd (initrd or initramfs).
- Your going to be editing two scripts. Open ~/vms/disks/<MyLinux_iso.sh> and ~/vms/disks/<MyLinux.sh>
- add "export kb_path=<My Kernal Path>" replacing <My Kernal Path> with the kernal of your choice that you had gotten earlier
- add "export kb_initrd<My Initrd>" replacing <My Initrd> with the initrd of your choice that you had gotten earlier
