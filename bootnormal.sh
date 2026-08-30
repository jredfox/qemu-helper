cow="${1}.qcow2"
arch="$2"
if [ -z "$3" ];
  qemu_ram=4096
else
  qemu_ram="$3"
fi
sharedir="share"
cd "disks"

qemu-system-$arch \
  -m 4096 \
  -cpu host \
  -smp 2 \
  -hda "$cow" \
  -enable-kvm \
  -device AC97 \
  -usb -device usb-mouse \
  -virtfs "local,path=$sharedir,mount_tag=hostshare,security_model=none"

