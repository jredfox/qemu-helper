dname="${1}"
iso="iso/${dname}.iso"
iso="$(realpath "$iso")"
cow="disks/${dname}.qcow2"
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
#create the temp dir
mkdir -p "tmp"

getArchy() {
  case "$1" in
    # ARM 64-bit
    *aarch64*|*arm64*|*armv8*|*armv9*)
        echo "aarch64"
        ;;

    # ARM 32-bit
    *aarch32*|*arm32*|*armv[0-7]*|*armhf*|*armel*|*[!a-z]arm[!a-z]*|arm[!a-z]*|*[!a-z]arm)
        echo "arm"
        ;;

    # RISC-V
    *risc-v*|*riscv*|*risc64*|*risc?64*|*rv64*)
        echo "riscv64"
        ;;

    # powerpc64 little edian
    *ppc64el*|*ppc64le*|*powerpc64le*|*powerpc64el*)
        echo "ppc64le"
        ;;

    # powerpc32
    *ppc32*|*ppc?32*|*powerpc32*|*powerpc?32*)
        echo "ppc32"
        ;;

    # powerpc64
    *ppc64*|*powerpc64*|*powerpc*)
        echo "ppc64"
        ;;

    # IBM Z
    *ibm-z*|*s390x*|*[!a-z0-9]s390[!a-z0-9]*|s390[!a-z0-9]*|*[!a-z0-9]s390)
        echo "s390x"
        ;;

    # x86 64-bit
    *x86?64*|*amd64*|*x64*|*64bit*|*64?bit*)
        echo "x86_64"
        ;;

    # x86 32-bit
    *i[0-9]86*|*i[0-9][0-9]86*|*i[0-9][0-9][0-9]86*|*x86?32*|*x86*|*32bit*|*32?bit*|*x32*|*ia-32*)
        echo "i386"
        ;;

    *)
        echo "Unsupported"
        ;;
    esac
}

getFamily() {

  case "$1" in
    # ARM 64-bit
    *aarch64*|*arm64*|*armv8*|*armv9*|*aarch32*|*arm32*|*armv[0-7]*|*armhf*|*armel*|*[!a-z]arm[!a-z]*|arm[!a-z]*|*[!a-z]arm)
        echo "arm"
        ;;

    # RISC-V
    *risc-v*|*riscv*|*risc64*|*risc?64*|*rv64*)
        echo "riscv"
        ;;

    # powerpc
    *ppc64*|*ppc?64*|*powerpc*|*ppc32*|*ppc?32*)
        echo "powerpc"
        ;;

    # IBM Z
    *ibm-z*|*s390x*|*[!a-z0-9]s390[!a-z0-9]*|s390[!a-z0-9]*|*[!a-z0-9]s390)
        echo "s390x"
        ;;

    # x86 intel / amd 32 and 64 bit processors
    *x86*|*amd64*|*x64*|*64bit*|*64?bit*|*i[0-9]86*|*i[0-9][0-9]86*|*i[0-9][0-9][0-9]86*|*32bit*|*32?bit*|*x32*|*ia-32*)
        echo "x86"
        ;;

    *)
        echo "$1"
        ;;
  esac

}

arch_org="$arch"
arch=$(getArchy "$arch")
uarch=$(uname -m)
family=$(getFamily "$uarch")
family_target=$(getFamily "$arch")

if [ "$kb" = "true" ]; then
  kbdir="disks/kb/${dname}"
  rm -rf "$kbdir"
  mkdir -p "$kbdir"
  #Extract kernal and initrd from the linux ISO
  opwd="$PWD"
  cd "$kbdir"
  vmlinuz_path="$kb_path"
  initrd_path="$kb_initrd"
  if [ -z "$vmlinuz_path" ] || [ -z "$initrd_path" ]; then
    results="$(7z l -ba "${iso}" | awk 'substr($3,1,1) != "D" { sub(/^([^ ]+ +){5}/, "") ; print }' | sed 's|^[^/]|/&|' | grep -Ei '^(/[^/]+){0,4}/(hwe-)?(vmlinuz|zImage|uImage|bzImage|Image|linux|vmlinux|vmlinuz-virt|initrd|uInitrd|initramfs|initramfs-linux)(-lts)?(\.gz|\.lz|\.img|\.tar\.gz|\.cpio\.gz)?$' | sed 's|^/||')"
    results_sorted="$(printf '%s' "$results" | awk '{print length, $0}' | sort -n | cut -d' ' -f2-)"
    vmlinuz_path="$(printf '%s' "$results_sorted" | grep -Ei '(hwe-)?(vmlinuz|zImage|uImage|bzImage|Image|linux|vmlinux|vmlinuz-virt)(-lts)?(\.gz|\.lz|\.img|\.tar\.gz|\.cpio\.gz)?$' | head -n 1)"
    initrd_path="$(printf '%s' "$results_sorted" | grep -Ei '(hwe-)?(initrd|uInitrd|initramfs|initramfs-linux)(-lts)?(\.gz|\.lz|\.img|\.tar\.gz|\.cpio\.gz)?$' | head -n 1)"
  else
    echo "skipping dynamic kernal fetch"
  fi
  7z e "${iso}" "$vmlinuz_path" "$initrd_path" -mtc -mta -mtm -aou -y >/dev/null
  echo "kernal: $vmlinuz_path initrd: $initrd_path"
  cd "$opwd"
  kbkernal="$(find "$kbdir" -maxdepth 1 -type f | grep -Ei '/(hwe-)?(vmlinuz|zImage|uImage|bzImage|Image|linux|vmlinux|vmlinuz-virt)(-lts)?(\.gz|\.lz|\.img|\.tar\.gz|\.cpio\.gz)?$' | head -n 1)"
  kbinitrd="$(find "$kbdir" -maxdepth 1 -type f | grep -Ei '/(hwe-)?(initrd|uInitrd|initramfs|initramfs-linux)(-lts)?(\.gz|\.lz|\.img|\.tar\.gz|\.cpio\.gz)?$' | head -n 1)"
  
  #Set the qemu console serial type needed for kernal booting
  qconsole="$kb_console"
  if [ -z "$qconsole" ]; then
    qconsole="ttyS0"
    if [ "$family_target" = "arm" ]; then
      qconsole="ttyAMA0"
    fi
    #handle s390x, powerpc
    if [ "$family_target" = "s390x" ] || [ "$family_target" = "powerpc" ]; then
      if [ "$arch" != "ppc32" ]; then
        qconsole="hvc0"
      fi
    fi
  fi
fi

qarg() {
  args="$args $1"
}

if [ "$family" = "$family_target" ]; then
  #disable acpi
  if [ "$no_acpi" = "true" ]; then
    qarg "-machine acpi=off"
  fi
  qarg "-m $qram"
  qarg "-cpu host"
  qarg "-smp $qcore"
  qarg "-cdrom \"$iso\""
  qarg "-hda \"$cow\""
  qarg "-boot d"
  if [ "$kb" = "true" ]; then
      if [ "$family_target" != "arm" ]; then
        echo "WARNING: Kernal Booting is broken outside of arm archs as they expect random append strings! Errors and bugs are bound to happen!"
      fi
      qarg "-kernel \"$kbkernal\""
      qarg "-initrd \"$kbinitrd\""
      qarg "-append \"${kb_args}console=${qconsole}\""
  fi
  #Check KVM Status
  if qemu-system-$arch -accel help 2>&1 | grep -qw kvm; then
      echo "qemu-system-$arch has KVM"
      qarg "-enable-kvm"
  else
    echo "ERROR qemu-system-$arch has no KVM!"
  fi

  #Handle LightWeight Desktop Enviorment
  if [ "$no_graphics" = "true" ]; then
    qarg "-nographic"
  else
    if [ "$LWDE" = "true" ]; then
      if qemu-system-$arch -device help 2>&1 | grep -qw "qxl-vga"; then
        echo "qemu-system-$arch has LWDE"
        qarg "-device qxl-vga,vram_size=134217728"
      else
        echo "ERROR Unsupported LWDE arch $arch guessing virtio-gpu-pci"
        qarg "-device virtio-gpu-pci"
      fi
    fi
  fi

  #Disable rebooting in the ISO installer by default
  if [ "$allow_reboot" != "true" ]; then
    qarg "-no-reboot"
  fi
  
  #Launch QEMU with arguments
  printf "%s\n\n" "qemu-system-${arch}${args}" >"tmp/run-${dname}.sh"
  exec sh "tmp/run-${dname}.sh"
  exit $?

fi

#Unsupported Arch that doesn't match the host
if [ "$arch" = "Unsupported" ]; then
  echo "Unsupported Arch: $arch_org"
  exit 1
fi

#disable acpi
if [ "$no_acpi" = "true" ]; then
  acpi=",acpi=off"
fi

#Support arm64
if [ "$family_target" = "arm" ]; then
  if [ "$arch" = "aarch64" ]; then
    qarg "-cpu \"cortex-a72\""
  else
    qarg "-cpu \"cortex-a15\""
  fi
  qarg "-machine \"virt,gic-version=2$acpi\""
  qarg "-m $qram"
  qarg "-smp $qcore"
  qarg "-device \"qemu-xhci\""
  qarg "-device \"usb-kbd\""
  qarg "-device \"usb-tablet\""
  qarg "-device \"virtio-keyboard-pci\""
  qarg "-device \"virtio-mouse-pci\""
  if [ "$kb" = "true" ]; then
    qarg "-kernel \"$kbkernal\""
    qarg "-initrd \"$kbinitrd\""
    qarg "-append \"${kb_args}console=${qconsole}\""
  else
    mkdir -p "$fwrdir"
    if [ "$arch" = "aarch64" ]; then
      AAVMF_CODE_PATH="/usr/share/AAVMF/AAVMF_CODE.fd"
      AAVMF_VARS_PATH="/usr/share/AAVMF/AAVMF_VARS.fd"
      AAVMF_CODE="$fwrdir/AAVMF_CODE.fd"
      AAVMF_VARS="$fwrdir/${dname}_iso.fd"
    else
      AAVMF_CODE_PATH="/usr/share/AAVMF/AAVMF32_CODE.fd"
      AAVMF_VARS_PATH="/usr/share/AAVMF/AAVMF32_VARS.fd"
      AAVMF_CODE="$fwrdir/AAVMF_CODE32.fd"
      AAVMF_VARS="$fwrdir/${dname}32_iso.fd"
    fi
    #Optimization
    if [ ! -f "$AAVMF_CODE" ]; then
      cp "$AAVMF_CODE_PATH" "$AAVMF_CODE"
    fi
    #TODO:fix AAVMF_VARS.fd handling
    cp "$AAVMF_VARS_PATH" "$AAVMF_VARS"
    qarg "-drive \"if=pflash,format=raw,unit=0,file=${AAVMF_CODE},readonly=on\""
    qarg "-drive \"if=pflash,format=raw,unit=1,file=${AAVMF_VARS}\""
  fi
  qarg "-netdev \"user,id=net0\""
  qarg "-device \"virtio-net-device,netdev=net0\""
  qarg "-device \"virtio-rng-pci\""
  #Drives
  qarg "-device \"virtio-scsi-device,id=scsi0\""
  qarg "-drive \"file=${iso},format=raw,readonly=on,if=none,id=cdrom0,media=cdrom\""
  qarg "-device \"scsi-cd,drive=cdrom0,bus=scsi0.0\""
  qarg "-drive \"file=${cow},format=qcow2,if=none,id=disk0\""
  qarg "-device \"virtio-blk-device,drive=disk0\""
fi

qarg "-nographic"
#Disable rebooting in the ISO installer by default
if [ "$allow_reboot" != "true" ]; then
  qarg "-no-reboot"
fi

#Launch QEMU with arguments
printf "%s\n\n" "qemu-system-${arch}${args}" >"tmp/run-${dname}.sh"
exec sh "tmp/run-${dname}.sh"
exit $?

#BOOT RISC-V ISO
if [ "$arch" = "riscv64" ]; then
  qemu-system-riscv64 \
    -cpu "rv64" \
    -machine "virt,acpi=off" \
    -m "$qram" \
    -smp "$qcore" \
    -kernel "/usr/lib/u-boot/qemu-riscv64_smode/uboot.elf" \
    -netdev "user,id=net0" \
    -device "virtio-net-device,netdev=net0" \
    -device "virtio-rng-pci" \
    -drive "file=${iso},format=raw,readonly=on,if=virtio" \
    -drive "file=${cow},format=qcow2,if=virtio" \
    -nographic
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
    -drive "file=${iso},format=raw,readonly=on,if=none,id=cdrom0,media=cdrom" \
    -device "virtio-scsi-ccw,id=scsi0" \
    -device "scsi-cd,drive=cdrom0,bus=scsi0.0,bootindex=1" \
    -drive "file=${cow},format=qcow2,if=none,id=disk0" \
    -device "virtio-blk-ccw,drive=disk0,id=vdisk0,bootindex=2" \
    -nographic
  exit $?
fi

#PowerPC 64 bit little endian
if [ "$arch" = "ppc64le" ]; then
  qemu-system-ppc64le \
      -L pc-bios \
      -cpu power8  \
      -machine "pseries-2.6,cap-htm=off"  \
      -m "$qram" \
      -smp "$qcore" \
      -hda "$cow" \
      -cdrom "$iso" \
      -boot d \
      -device usb-kbd \
      -device usb-mouse \
      -nographic \
      -prom-env 'auto-boot?=true' \
      -prom-env 'vga-ndrv?=true' \
      -prom-env 'boot-args=-v'
  exit $?
fi

# x86_64 and x86 can work with graphics even when the host arch isn't x86 (32 or 64 bit)
if [ "$arch" = "x86_64" ]; then
    qemu-system-x86_64 \
      -machine "q35" \
      -cpu "qemu64" \
      -smp "$qcore" \
      -m "$qram" \
      -hda "$cow" \
      -cdrom "$iso" \
      -boot d \
      -vga "virtio" \
      -display "default" \
      -netdev "user,id=net0" \
      -device "virtio-net-pci,netdev=net0"
    exit $?
fi

# x86_64 and x86 can work with graphics even when the host arch isn't x86 (32 or 64 bit)
if [ "$arch" = "i386" ]; then
    qemu-system-i386 \
      -machine "pc" \
      -cpu "pentium3" \
      -smp "$qcore" \
      -m "$qram" \
      -hda "$cow" \
      -cdrom "$iso" \
      -boot d \
      -vga "std" \
      -display "default" \
      -netdev "user,id=net0" \
      -device "rtl8139,netdev=net0"
    exit $?
fi
