cow="${1}.qcow2"
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
sharedir="../share"
cd "disks"

if [ "$arch" = "aarch64" ]; then
  qemu-system-aarch64 \
    -cpu cortex-a72 \
    -machine virt,gic-version=2 \
    -m "$qram" \
    -smp "$qcore" \
    -device qemu-xhci \
    -device usb-kbd \
    -device usb-tablet \
    -device virtio-keyboard-pci \
    -device virtio-mouse-pci \
    -drive if=pflash,format=raw,unit=0,file=AAVMF_CODE.fd,readonly=on \
    -drive if=pflash,format=raw,unit=1,file=AAVMF_VARS.fd \
    -netdev user,id=net0 \
    -device virtio-net-device,netdev=net0 \
    -device virtio-rng-pci \
    -drive file=${cow},format=qcow2,if=virtio \
    -nographic
  exit $?
fi

#BOOT RISC-V
if [ "$arch" = "riscv64" ]; then
  qemu-system-riscv64 \
    -cpu rv64 \
    -machine virt,acpi=off \
    -m "$qram" \
    -smp "$qcore" \
    -nographic \
    -kernel /usr/lib/u-boot/qemu-riscv64_smode/uboot.elf \
    -netdev user,id=net0 \
    -device virtio-net-device,netdev=net0 \
    -device virtio-rng-pci \
    -drive file="$cow",format=qcow2,if=virtio
  exit $?
fi

#Handle LightWeight Desktop Enviorment with -device qxl-vga,vram_size=134217728
if [ "$LWDE" = "true" ]; then
  qemu-system-$arch \
    -m "$qram" \
    -cpu host \
    -smp "$qcore" \
    -hda "$cow" \
    -enable-kvm \
    -device AC97 \
    -usb -device usb-mouse \
    -device qxl-vga,vram_size=134217728 \
    -virtfs "local,path=$sharedir,mount_tag=hostshare,security_model=none"
  exit "$?"
fi

qemu-system-$arch \
  -m "$qram" \
  -cpu host \
  -smp "$qcore" \
  -hda "$cow" \
  -enable-kvm \
  -device AC97 \
  -usb -device usb-mouse \
  -virtfs "local,path=$sharedir,mount_tag=hostshare,security_model=none"

