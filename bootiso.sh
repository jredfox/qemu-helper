iso="iso/${1}.iso"
cow="disks/${1}.qcow2"
arch=$2
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

#Handle LightWeight Desktop Enviorment with -device qxl-vga,vram_size=134217728
if [ "$LWDE" = "true" ]; then
  echo "Launching qemu with LWDE with $qcore"
  qemu-system-$arch \
    -m "$qram" \
    -cpu host \
    -smp "$qcore" \
    -hda "$cow" \
    -cdrom "$iso" \
    -boot d \
    -enable-kvm \
    -device qxl-vga,vram_size=134217728 \
  exit "$?"
fi

qemu-system-$arch \
  -m "$qram" \
  -cpu host \
  -smp "$qcore" \
  -hda "$cow" \
  -cdrom "$iso" \
  -boot d \
  -enable-kvm

