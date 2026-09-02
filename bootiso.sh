iso="iso/${1}.iso"
cow="disks/${1}.qcow2"
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
  mkdir -p "firmware"
  cp "/usr/share/AAVMF/AAVMF_CODE.fd" "firmware/AAVMF_CODE.fd"
  cp "/usr/share/AAVMF/AAVMF_VARS.fd" "firmware/AAVMF_VARS.fd"
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
    -drive "if=pflash,format=raw,unit=0,file=firmware/AAVMF_CODE.fd,readonly=on" \
    -drive "if=pflash,format=raw,unit=1,file=firmware/AAVMF_VARS.fd" \
    -netdev "user,id=net0" \
    -device "virtio-net-device,netdev=net0" \
    -device "virtio-rng-pci" \
    -drive "file=${cow},format=qcow2,if=virtio,id=VIRTIO1" \
    -device "virtio-scsi-pci,id=scsi0" \
    -drive "file=${iso},format=raw,readonly=on,if=none,id=cdrom0,media=cdrom" \
    -device "scsi-cd,drive=cdrom0,bus=scsi0.0" \
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

#Handle LightWeight Desktop Enviorment with -device qxl-vga,vram_size=134217728
if [ "$LWDE" = "true" ]; then
  echo "Launching qemu with LWDE with $qcore"
  qemu-system-$arch \
    -m "$qram" \
    -cpu host \
    -smp "$qcore" \
    -hda "$cow" \
    -cdrom "$iso" \
    -boot d \
    -enable-kvm \
    -device "qxl-vga,vram_size=134217728" \
  exit $?
fi

qemu-system-$arch \
  -m "$qram" \
  -cpu host \
  -smp "$qcore" \
  -hda "$cow" \
  -cdrom "$iso" \
  -boot d \
  -enable-kvm

