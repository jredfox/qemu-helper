iso="iso/${1}.iso"
iso="$(realpath "$iso")"
cow="disks/${1}.qcow2"
fwrdir="disks/firmware"
arch="$2"
qram="$3"
qcore="$4"
LWDE="$5"
if [ -z "$qram" ]; then
  qram="4096"
fi
if [ -z "$qcore" ]; then
  qcore="4"
fi
if [ -z "$LWDE" ]; then
  LWDE="false"
fi

if [ "$arch" = "aarch64" ]; then
  kb="true"
  if [ "$kb" = "true" ]; then
    kbdir="disks/kb/${1}"
    rm -rf "$kbdir"
    mkdir -p "$kbdir"
    #Extract kernal and initrd from the linux ISO
    opwd="$PWD"
    cd "$kbdir"
    vmlinuz_path="$kb_path"
    initrd_path="$kb_initrd"
    if [ -z "$vmlinuz_path" ] || [ -z "$initrd_path" ]; then
      results="$(7z l -ba "${iso}" | awk 'substr($3,1,1) != "D" { sub(/^([^ ]+ +){5}/, "") ; print }' | sed 's|^[^/]|/&|' | grep -Ei '^(/[^/]+){0,4}/(hwe-)?(vmlinuz|zImage|uImage|Image|linux|vmlinux|initrd|uInitrd|initramfs|initramfs-linux)(-lts)?(\.gz|\.lz|\.img|\.tar\.gz|\.cpio\.gz)?$' | sed 's|^/||')"
      results_sorted="$(printf '%s' "$results" | awk '{print length, $0}' | sort -n | cut -d' ' -f2-)"
      vmlinuz_path="$(printf '%s' "$results_sorted" | grep -Ei '(hwe-)?(vmlinuz|zImage|uImage|Image|linux|vmlinux)(-lts)?(\.gz|\.lz|\.img|\.tar\.gz|\.cpio\.gz)?$' | head -n 1)"
      initrd_path="$(printf '%s' "$results_sorted" | grep -Ei '(hwe-)?(initrd|uInitrd|initramfs|initramfs-linux)(-lts)?(\.gz|\.lz|\.img|\.tar\.gz|\.cpio\.gz)?$' | head -n 1)"
    fi
    7z e "${iso}" "$vmlinuz_path" "$initrd_path" -aou -y >/dev/null
    echo "kernal: $vmlinuz_path initrd: $initrd_path"
    echo "if you experience issues with kernal booting read the FAQ"
    cd "$opwd"
    kbkernal="$(find "$kbdir" -maxdepth 1 -type f | grep -Ei '/(hwe-)?(vmlinuz|zImage|uImage|Image|linux|vmlinux)(-lts)?(\.gz|\.lz|\.img|\.tar\.gz|\.cpio\.gz)?$' | head -n 1)"
    kbinitrd="$(find "$kbdir" -maxdepth 1 -type f | grep -Ei '/(hwe-)?(initrd|uInitrd|initramfs|initramfs-linux)(-lts)?(\.gz|\.lz|\.img|\.tar\.gz|\.cpio\.gz)?$' | head -n 1)"
    qemu-system-aarch64 \
      -cpu "cortex-a72" \
      -machine "virt,gic-version=2" \
      -m "$qram" \
      -smp "$qcore" \
      -device "qemu-xhci" \
      -device "usb-kbd" \
      -device "usb-tablet" \
      -device "virtio-keyboard-pci" \
      -device "virtio-mouse-pci" \
      -kernel "$kbkernal" \
      -initrd "$kbinitrd" \
      -append "console=ttyAMA0" \
      -netdev "user,id=net0" \
      -device "virtio-net-device,netdev=net0" \
      -device "virtio-rng-pci" \
      -device "virtio-scsi-pci,id=scsi0" \
      -drive "file=${iso},format=raw,readonly=on,if=none,id=cdrom0,media=cdrom" \
      -device "scsi-cd,drive=cdrom0,bus=scsi0.0" \
      -drive "file=${cow},format=qcow2,if=virtio" \
      -nographic
  fi
  mkdir -p "$fwrdir"
  fwrcode="$fwrdir/${1}_AAVMF_CODE_iso.fd"
  fwrvars="$fwrdir/${1}_AAVMF_VARS_iso.fd"
  cp "/usr/share/AAVMF/AAVMF_CODE.fd" "$fwrcode"
  cp "/usr/share/AAVMF/AAVMF_VARS.fd" "$fwrvars"
  qemu-system-aarch64 \
    -cpu "cortex-a72" \
    -machine "virt,gic-version=2" \
    -m "$qram" \
    -smp "$qcore" \
    -device "qemu-xhci" \
    -device "usb-kbd" \
    -device "usb-tablet" \
    -device "virtio-keyboard-pci" \
    -device "virtio-mouse-pci" \
    -drive "if=pflash,format=raw,unit=0,file=${fwrcode},readonly=on" \
    -drive "if=pflash,format=raw,unit=1,file=${fwrvars}" \
    -netdev "user,id=net0" \
    -device "virtio-net-device,netdev=net0" \
    -device "virtio-rng-pci" \
    -device "virtio-scsi-pci,id=scsi0" \
    -drive "file=${iso},format=raw,readonly=on,if=none,id=cdrom0,media=cdrom" \
    -device "scsi-cd,drive=cdrom0,bus=scsi0.0" \
    -drive "file=${cow},format=qcow2,if=virtio" \
    -nographic
  exit $?
fi

#BOOT ARM32 ISO
if [ "$arch" = "arm" ]; then
  mkdir -p "$fwrdir"
  fwrcode="$fwrdir/${1}_AAVMF_CODE_32_iso.fd"
  fwrvars="$fwrdir/${1}_AAVMF_VARS_32_iso.fd"
  cp "/usr/share/AAVMF/AAVMF32_CODE.fd" "$fwrcode"
  cp "/usr/share/AAVMF/AAVMF32_VARS.fd" "$fwrvars"
  qemu-system-arm \
    -cpu "cortex-a15" \
    -machine "virt,gic-version=2" \
    -m "$qram" \
    -smp "$qcore" \
    -device "qemu-xhci" \
    -device "usb-kbd" \
    -device "usb-tablet" \
    -device "virtio-keyboard-pci" \
    -device "virtio-mouse-pci" \
    -drive "if=pflash,format=raw,unit=0,file=${fwrcode},readonly=on" \
    -drive "if=pflash,format=raw,unit=1,file=${fwrvars}" \
    -netdev "user,id=net0" \
    -device "virtio-net-device,netdev=net0" \
    -device "virtio-rng-pci" \
    -drive "if=none,file=${iso},id=cdrom,media=cdrom" \
    -device "virtio-scsi-device" \
    -device "scsi-cd,drive=cdrom" \
    -drive "if=none,file=${cow},id=hd0,format=qcow2" \
    -device "virtio-blk-device,drive=hd0" \
    -nographic
  exit $?
fi

#BOOT RISC-V ISO
if [ "$arch" = "riscv64" ]; then
  qemu-system-riscv64 \
    -cpu "rv64" \
    -machine "virt,acpi=off" \
    -m "$qram" \
    -smp "$qcore" \
    -kernel "/usr/lib/u-boot/qemu-riscv64_smode/uboot.elf" \
    -netdev "user,id=net0" \
    -device "virtio-net-device,netdev=net0" \
    -device "virtio-rng-pci" \
    -drive "file=${iso},format=raw,readonly=on,if=virtio" \
    -drive "file=${cow},format=qcow2,if=virtio" \
    -nographic
  exit $?
fi

#BOOT IBM-Z (s390x)
if [ "$arch" = "s390x" ]; then
  qemu-system-s390x \
    -cpu max \
    -m "$qram" \
    -smp "$qcore" \
    -machine "s390-ccw-virtio" \
    -netdev "user,id=net0" \
    -device "virtio-net-ccw,netdev=net0" \
    -drive "file=${iso},format=raw,readonly=on,if=none,id=cdrom0,media=cdrom" \
    -device "virtio-scsi-ccw,id=scsi0" \
    -device "scsi-cd,drive=cdrom0,bus=scsi0.0,bootindex=1" \
    -drive "file=${cow},format=qcow2,if=none,id=disk0" \
    -device "virtio-blk-ccw,drive=disk0,id=vdisk0,bootindex=2" \
    -nographic
  exit $?
fi

#Handle LightWeight Desktop Enviorment with -device qxl-vga,vram_size=134217728
if [ "$LWDE" = "true" ]; then
  echo "Launching qemu with LWDE with $qcore"
  qemu-system-$arch \
    -m "$qram" \
    -cpu host \
    -smp "$qcore" \
    -cdrom "$iso" \
    -hda "$cow" \
    -boot d \
    -enable-kvm \
    -device "qxl-vga,vram_size=134217728"
  exit $?
fi

qemu-system-$arch \
  -m "$qram" \
  -cpu host \
  -smp "$qcore" \
  -cdrom "$iso" \
  -hda "$cow" \
  -boot d \
  -enable-kvm

