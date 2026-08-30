cow="${1}.qcow2"
arch="$2"
workingdir="$HOME/vms/disks"
sharedir="$HOME/vms/share"
cd "$workingdir"

qemu-system-$arch \
  -m 2048 \
  -cpu host \
  -smp 2 \
  -hda "$cow" \
  -enable-kvm \
  -device AC97 \
  -usb -device usb-mouse \
  -virtfs "local,path=$sharedir,mount_tag=hostshare,security_model=none"

