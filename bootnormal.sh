cow="${1}.qcow2"
arch="$2"
qemu_ram="$3"
if [ -z "$3" ]; then
  qemu_ram="4096"
fi
sharedir="../share"
cd "disks"

qemu-system-$arch \
  -m "$qemu_ram" \
  -cpu host \
  -smp 2 \
  -hda "$cow" \
  -enable-kvm \
  -device AC97 \
  -usb -device usb-mouse \
  -virtfs "local,path=$sharedir,mount_tag=hostshare,security_model=none"

