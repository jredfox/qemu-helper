iso="iso/${1}.iso"
cow="disks/${1}.qcow2"
arch=$2
if [ -z "$3" ];
  qemu_ram="4096"
else
  qemu_ram="$3"
fi

qemu-system-$arch \
  -m "$qemu_ram" \
  -cpu host \
  -smp 2 \
  -hda "$cow" \
  -cdrom "$iso" \
  -boot d \
  -enable-kvm

