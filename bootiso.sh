iso="iso/${1}.iso"
cow="disks/${1}.qcow2"
arch=$2
qram="$3"
qcore="$4"
if [ -z "$qram" ]; then
  qram="4096"
fi
if [ -z "$qcore" ]; then
  qcore="4"
fi

qemu-system-$arch \
  -m "$qram" \
  -cpu host \
  -smp 4 \
  -hda "$cow" \
  -cdrom "$iso" \
  -boot d \
  -enable-kvm

