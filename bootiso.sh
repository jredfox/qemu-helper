iso="iso/${1}.iso"
cow="disks/${1}.qcow2"
arch=$2
qemu_ram="$3"
if [ -z "$3" ]; then
  qemu_ram="4096"
fi

qemu-system-$arch \
  -m "$qemu_ram" \
  -cpu host \
  -smp 4 \
  -hda "$cow" \
  -cdrom "$iso" \
  -boot d \
  -enable-kvm

