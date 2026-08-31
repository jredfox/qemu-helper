cow="${1}.qcow2"
arch="$2"
qram="$3"
qcores="$4"
if [ -z "$qram" ]; then
  qram="4096"
fi
if [ -z "$qcores" ]; then
  qcores="4"
fi
sharedir="../share"
cd "disks"

qemu-system-$arch \
  -m "$qram" \
  -cpu host \
  -smp "$qcores" \
  -hda "$cow" \
  -enable-kvm \
  -device AC97 \
  -usb -device usb-mouse \
  -virtfs "local,path=$sharedir,mount_tag=hostshare,security_model=none"

