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
sharedir="share"

if [ "$arch" = "aarch64" ]; then
  mkdir -p "$fwrdir"
  fwrcode="$fwrdir/AAVMF_CODE_${1}.fd"
  fwrvars="$fwrdir/AAVMF_VARS_${1}.fd"
  if [ ! -f "$fwrcode" ]; then
    cp "/usr/share/AAVMF/AAVMF_CODE.fd" "$fwrcode"
  fi
  if [ ! -f "$fwrvars" ]; then
    cp "/usr/share/AAVMF/AAVMF_VARS.fd" "$fwrvars"
  fi
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
    -drive "file=${cow},format=qcow2,if=virtio" \
    -nographic
  exit $?
fi

#BOOT ARM32
if [ "$arch" = "arm" ]; then
  mkdir -p "$fwrdir"
  fwrcode="$fwrdir/AAVMF_CODE_32${1}.fd"
  fwrvars="$fwrdir/AAVMF_VARS_32${1}.fd"
  if [ ! -f "$fwrcode" ]; then
    cp "/usr/share/AAVMF/AAVMF32_CODE.fd" "$fwrcode"
  fi
  if [ ! -f "$fwrvars" ]; then
    cp "/usr/share/AAVMF/AAVMF32_VARS.fd" "$fwrvars"
  fi
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
    -drive "if=none,file=${cow},id=hd0,format=qcow2" \
    -device "virtio-blk-device,drive=hd0" \
    -nographic
  exit $?
fi

#BOOT RISC-V
if [ "$arch" = "riscv64" ]; then
  qemu-system-riscv64 \
    -cpu "rv64" \
    -machine "virt,acpi=off" \
    -m "$qram" \
    -smp "$qcore" \
    -nographic \
    -kernel "/usr/lib/u-boot/qemu-riscv64_smode/uboot.elf" \
    -netdev "user,id=net0" \
    -device "virtio-net-device,netdev=net0" \
    -device "virtio-rng-pci" \
    -drive "file=${cow},format=qcow2,if=virtio"
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
    -drive "file=${cow},format=qcow2,if=none,id=disk0" \
    -device "virtio-blk-ccw,drive=disk0,id=vdisk0,bootindex=1" \
    -nographic
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
    -device "AC97" \
    -usb -device "usb-mouse" \
    -device "qxl-vga,vram_size=134217728" \
    -virtfs "local,path=$sharedir,mount_tag=hostshare,security_model=none"
  exit $?
fi

qemu-system-$arch \
  -m "$qram" \
  -cpu host \
  -smp "$qcore" \
  -hda "$cow" \
  -enable-kvm \
  -device "AC97" \
  -usb -device "usb-mouse" \
  -virtfs "local,path=$sharedir,mount_tag=hostshare,security_model=none"

