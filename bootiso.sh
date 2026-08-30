iso="iso/${1}.iso"
cow="disks/${1}.qcow2"
arch=$2
workingdir="$HOME/vms"
cd "$workingdir"

qemu-system-$arch \
  -m 2048 \
  -cpu host \
  -smp 2 \
  -hda "$cow" \
  -cdrom "$iso" \
  -boot d \
  -enable-kvm

