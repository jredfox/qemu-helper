#!/bin/sh

dname="${1}"
for ext in iso ISO Iso isO iSo iSO IsO ISo; do
  if [ -f "iso/${dname}.${ext}" ]; then
    iso="iso/${dname}.${ext}"
    break
  fi
done
if [ ! -z "$iso" ]; then
  iso="$(realpath "$iso")"
fi
cow="disks/${dname}.qcow2"
fwrdir="disks/firmware"
iso_boot="$2"
arch="$3"
qram="${4:-4096}"
qcore="${5:-4}"
if [ "$iso_boot" = "true" ]; then
  if [ -z "$iso" ]; then
    echo "iso not found: iso/${dname}.iso"
    exit 1
  fi
  sname="_iso"
  cdname="INSTALL_QH"
else
  sname=""
  cdname="QH"
fi
title="${title:-$dname}"
gpu_2d="${gpu_2d:-false}"
q_audio="${q_audio:-usb-audio}"
grab_mouse="${grab_mouse:-true}"
if [ -z "$q_mouse" ]; then
  if [ "$grab_mouse" = "true" ]; then
    q_mouse="usb-mouse"
  else
    q_mouse="usb-tablet"
  fi
fi
windows_95="${windows_95:-false}"
if [ "$windows_95" = "true" ]; then
  windows_old="true"
fi
if [ "$windows_old" = "true" ] || [ "$windows_10" = "true" ] || [ "$windows_11" = "true" ]; then
  windows="true"
fi
if command -v md5sum >/dev/null 2>&1; then
    md5_cmd="md5sum"
else
    md5_cmd="md5"
fi
#Flag if we are on mac or linux
isMac="false"
isLinux="false"
if [ "$(printf '%s' "$(uname)" | tr '[:upper:]' '[:lower:]')" = "darwin" ]; then
    isMac="true"
else
    isLinux="true"
fi
#create the temp dir
mkdir -p "tmp"
run_tmp="tmp/${dname}${sname}.sh"

refreshDesktop() {

  touch "$DESKTOP_DIR" 2>/dev/null

  if command -v xdg-desktop-menu >/dev/null 2>&1; then
    xdg-desktop-menu forceupdate >/dev/null 2>&1
  else
    for kde_pkg in kbuildsycoca6 kbuildsycoca5; do
      if command -v "$kde_pkg" >/dev/null 2>&1; then
        "$kde_pkg" >/dev/null 2>&1
        break
      fi
    done
  fi
  
  return 0

}

createDesktop() {

  DESKTOP_GEN="${DESKTOP_GEN:-true}"
  if [ "$DESKTOP_GEN" != "true" ] || [ "$isLinux" != "true" ]; then
    return 1
  fi

  DESKTOP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  if [ ! -e "$DESKTOP_DIR" ]; then
    mkdir -p "$DESKTOP_DIR" || return 1
  fi
  DESKTOP_FILE="${DESKTOP_DIR}/${dname}${sname}.desktop"
  DESKTOP_HASH="$(printf '%s' "${dname}${sname}" | "$md5_cmd" | cut -d' ' -f1)"
  DESKTOP_CLASS="${cdname}_${DESKTOP_HASH}"
  icon="${icon:-qemu}"
  case "$icon" in
    '/'*) ;;
    *'/'*) icon="$(realpath "$icon")" ;;
  esac
  DESKTOP_TITLE="${DESKTOP_TITLE:-$title}"
  install_dir="$(realpath "$PWD")"
  DESKTOP_CMD="$(printf '%s' "$install_dir/boot/${dname}${sname}.sh" | sed -e 's/["`$]/\\\\&/g' -e 's/%/%%/g')"
  printf '%s\n' '[Desktop Entry]' >"$DESKTOP_FILE"
  printf '%s\n' "Name=$DESKTOP_TITLE" >>"$DESKTOP_FILE"
  printf '%s\n' "Path=$install_dir" >>"$DESKTOP_FILE"
  printf '%s\n' "Exec=sh \"${DESKTOP_CMD}\"" >>"$DESKTOP_FILE"
  printf '%s\n' "Icon=${icon}" >>"$DESKTOP_FILE"
  printf '%s\n' "Categories=${DESKTOP_CATEGORIES:-System;Emulator;Development;}" >>"$DESKTOP_FILE"
  printf '%s\n' "Keywords=${DESKTOP_KEYWORDS:-Qemu;Emulator;Qemu-Helper;QemuHelper;Qemu Helper;QH;Windows;Linux;Alpine;Ubuntu;mac;macOS;osx;}" >>"$DESKTOP_FILE"
  printf '%s\n' "Terminal=false" >>"$DESKTOP_FILE"
  printf '%s\n' "Type=Application" >>"$DESKTOP_FILE"
  printf '%s\n' "StartupWMClass=$DESKTOP_CLASS" >>"$DESKTOP_FILE"
  #Make the DESKTOP File Executable
  chmod +x "$DESKTOP_FILE"
  if command -v gio >/dev/null 2>&1; then
    gio set "$DESKTOP_FILE" "metadata::trusted" "true"
  fi
  refreshDesktop ""
  return 0

}

createDesktop ""

onExit() {
  echo "$1" >&2
  printf "%s\n" "Press Enter to Continue..."
  read -r result
  exit 1
}

#Sanity check to ensure both ISO boot and normal boot are not running at the same time or multiple instances of the same one
if lsof "$cow" >/dev/null 2>&1; then
  onExit "${cow} is already running from QEMU or another program!"
fi

getArchy() {
  uparch="$1"
  lname="$(printf '%s' "$uparch" | tr '[:upper:]' '[:lower:]')"
  case "$lname" in
    # ARM 64-bit
    *aarch64*|*arm64*|*armv8*|*armv9*)
      echo "aarch64"
      ;;

    # ARM 32-bit
    *aarch32*|*arm32*|*armv[0-7]*|*armhf*|*armel*|*[!a-z]arm[!a-z]*|arm[!a-z]*|*[!a-z]arm|arm)
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
    *ppc32*|*ppc?32*|*powerpc32*|*powerpc?32*|*[!a-z0-9]ppc[!a-z0-9]*|ppc[!a-z0-9]*|*[!a-z0-9]ppc|ppc)
      echo "ppc"
      ;;

    # powerpc64
    *ppc64*|*powerpc64*|*powerpc*)
      echo "ppc64"
      ;;

    # IBM Z
    *ibm-z*|*s390x*|*[!a-z0-9]s390[!a-z0-9]*|s390[!a-z0-9]*|*[!a-z0-9]s390|s390)
      echo "s390x"
      ;;

    # x86 64-bit
    *x86?64*|*amd64*|*x64*|*64bit*|*64?bit*)
      echo "x86_64"
      ;;

    # x86 32-bit
    *i[0-9]86*|*i[0-9][0-9]86*|*i[0-9][0-9][0-9]86*|*x86?32*|*x86*|*32bit*|*32?bit*|*x32*|*ia?32*|*ia32*)
      echo "i386"
      ;;

    *)
      echo "$1"
      ;;
  esac
}

getFamily() {
  uparch="$1"
  lname="$(printf '%s' "$uparch" | tr '[:upper:]' '[:lower:]')"
  case "$lname" in
    # ARM 64-bit
    *aarch64*|*arm64*|*armv8*|*armv9*|*aarch32*|*arm32*|*armv[0-7]*|*armhf*|*armel*|*[!a-z]arm[!a-z]*|arm[!a-z]*|*[!a-z]arm|arm)
      echo "arm"
      ;;

    # RISC-V
    *risc-v*|*riscv*|*risc64*|*risc?64*|*rv64*)
      echo "riscv"
      ;;

    # powerpc
    *ppc64*|*ppc?64*|*powerpc*|*ppc32*|*ppc?32*|*[!a-z0-9]ppc[!a-z0-9]*|ppc[!a-z0-9]*|*[!a-z0-9]ppc|ppc)
      echo "powerpc"
      ;;

    # IBM Z
    *ibm-z*|*s390x*|*[!a-z0-9]s390[!a-z0-9]*|s390[!a-z0-9]*|*[!a-z0-9]s390|s390)
      echo "s390x"
      ;;

    # x86 intel / amd 32 and 64 bit processors
    *x86*|*amd64*|*x64*|*64bit*|*64?bit*|*i[0-9]86*|*i[0-9][0-9]86*|*i[0-9][0-9][0-9]86*|*32bit*|*32?bit*|*x32*|*ia?32*|*ia32*)
      echo "x86"
      ;;

    *)
      echo "Unsupported"
      ;;
  esac

}

try_decompress()
{

  #Kernal is already decompressed do nothing
  if [ "$isDecompressed" = "true" ]; then
    return 1
  fi

  # The obscure use of the "tr" filter is to work around older versions of
  # "grep" that report the byte offset of the line instead of the pattern.

  # Try to find the header ($1) and decompress from here
  for pos in `tr "$1\n$2" "\n$2=" < "$img" | grep -abo "^$2"`
  do
    pos=${pos%%:*}
    tail -c+$pos "$img" | $3 > "$img_tmp" 2> /dev/null
    if file -b "$img_tmp" | grep -q 'Linux kernel.*boot executable' ||
      readelf -h "$img_tmp" > /dev/null 2>&1
    then
      isDecompressed="true"
      cp -f "$img_tmp" "$img_out"
      echo "Extracted vmlinux using '$3' from offset $pos" >&2
      return 0
    fi
  done

  return 1
}

decompressKernal() {

  if [ -z "$1" ]; then
    echo "extract-vmlinux.sh <kernal> <kernal_extracted>"
    return 1
  fi
  img="$1"
  img_out="${2:-$1}"
  img_tmp="${img_out}.vmlinux"
  mkdir -p "$(dirname "$img_out")"

  # Comment out gzip as qemu already properly handles
  isDecompressed="false"
  #QEMU already handles this plus causes issues on older archs such as x86 32 bit
  if [ "$kb_decompress_gzip" = "true" ]; then
    try_decompress '\037\213\010' xy    gunzip
  fi
  try_decompress '\3757zXZ\000' abcde unxz
  try_decompress 'BZh'          xy    bunzip2
  #LZMA could try thousands or even hundred of thousands of times per kernal instead of 1-5
  if [ "$kb_decompress_lzma" = "true" ]; then
    try_decompress '\135\0\0\0'   xxx   unlzma
  fi
  try_decompress '\211\114\132' xy    'lzop -d'
  try_decompress '\002!L\030'   xxx   'lz4 -d'
  try_decompress '(\265/\375'   xxx   unzstd

  #Cleanup
  rm -f "$img_tmp"
  
  if [ "$isDecompressed" != "true" ]; then
    echo "vmlinux is already decompressed?" >&2
    return 1
  fi

  return 0

}

filterArchive() {

    type=$(file -b "$1")
    type="$(printf '%s' "$type" | tr '[:upper:]' '[:lower:]')"
    case "$type" in
        *gzip*|*lzma*|*xz*|*cpio*|"zip "*|"tar "*|"gz "*|*" tar "*|*" gz "*|*" zip "*)
            echo "$1"
            ;;
        *)
            ;;
    esac

}

unzipKernal() {

    archive="$1"
    outdir="$2"
    test_path="$(filterArchive "$archive")"
    if [ -z "$test_path" ]; then
        echo "kernal is unzipped: $archive"
        return 0
    fi
    mkdir -p "$outdir"
    isArchive="true"
    FILE_DONE="${outdir}/FILE_DONE.tmp.txt"
    echo "$FILE_DONE" >"$FILE_DONE"
    echo "extracting: $archive"
    7z e "$archive" -o"$outdir" -aoa -y >/dev/null
    echo "$archive" >>"$FILE_DONE"
    archives="$(find "$outdir" -maxdepth 1 -type f | while IFS= read -r file; do filterArchive "$file"; done | grep -v -F -x -f "$FILE_DONE")"
    while [ -n "$archives" ]; do
        printf '%s\n' "$archives" | while IFS= read -r file; do
            echo "extracting: $file"
            7z e "$file" -o"$outdir" -aoa -y >/dev/null
            echo "$file" >>"$FILE_DONE"
            if [ "$file" != "$archive" ]; then
                rm -f "$file"
            fi
        done
        archives="$(find "$outdir" -maxdepth 1 -type f | while IFS= read -r file; do filterArchive "$file"; done | grep -v -F -x -f "$FILE_DONE")"
    done
    vmlinux=$(find "$outdir" -maxdepth 1 -type f | grep -v -F -x -f "$FILE_DONE" | head -n 1)
    cp -f "$vmlinux" "$archive"
    rm -rf "$outdir"

}

arch=$(getArchy "$arch")
uarch=$(uname -m)
uarch=$(getArchy "$uarch")
family=$(getFamily "$uarch")
family_target=$(getFamily "$arch")

#Unsupported Arch that doesn't match the host
if [ "$family_target" = "Unsupported" ]; then
  onExit "Unsupported Arch: $arch"
fi

if [ "$kb" = "true" ]; then
  kbdir="disks/kb/${dname}${sname}"
  rm -rf "$kbdir"
  mkdir -p "$kbdir"
  #kb_args add space if it doesn't end with one already
  if [ ! -z "$kb_args" ]; then
    case "$kb_args" in
        *" ") 
          kb_args="$kb_args"
          ;;
        *)    
          kb_args="$kb_args "
          ;;
    esac
  fi
  #remove prepending slash from path variables as 7z doesn't want them
  kb_path="${kb_path#/}"
  kb_initrd="${kb_initrd#/}"
  #Extract kernal and initrd from the linux ISO
  opwd="$PWD"
  cd "$kbdir"
  vmlinuz_path="$kb_path"
  initrd_path="$kb_initrd"
  if [ -z "$vmlinuz_path" ] || [ -z "$initrd_path" ]; then
    results="$(7z l -ba "${iso}" | awk 'toupper(substr($3,1,1)) != "D" { max = (substr($1,1,1) != "." ? 5 : 3); cachedNF = NF; for (i=1; i<=max && i<cachedNF; i++) sub(/^[[:space:]]*[^[:space:]]+/, ""); sub(/^[[:space:]]+/, ""); print }' | sed 's|^[^/]|/&|' | grep -Ei '^(/[^/]+){0,4}/(hwe-)?(vmlinuz|zImage|uImage|bzImage|Image|linux|vmlinux|kernel\.ubuntu|kernal\.ubuntu|initrd|uInitrd|initramfs|initramfs-linux)(\.ubuntu)?(-rt|-cloud|-virt|-vm|-generic|-lts|-hwe){0,7}(\.efi|\.gz|\.lz|\.img|\.tar\.gz|\.cpio\.gz)?$')"
    results_sorted="$(printf '%s' "$results" | awk -F/ '{ print NF-1, $0 }' | sort -n -k1,1 -k2,2 | sed 's|^[^/]*/||')"
    #Handle PowerPC 32 / 64 bit
    if [ "$family_target" = "powerpc" ]; then
      #powerpc generic filter
      results_sorted="$(printf '%s' "$results_sorted" | grep -vEi '^(install|boot|efi)[^/]*/e500mc/')"
      #prefer powerpc64 when 64 bit
      if [ "$arch" = "ppc64" ]; then
        installboot="$(printf '%s' "$results_sorted" | grep -Ei '^(install|boot|efi)[^/]*/(powerpc64|ppc64)(-[a-z0-9]+)?(/|$)')"
        if [ ! -z "$installboot" ]; then
          results_sorted="$installboot"
        fi
      fi
      #prefer powerpc32 when 32 bit
      if [ "$arch" = "ppc" ]; then
        installboot="$(printf '%s' "$results_sorted" | grep -Ei '^(install|boot|efi)[^/]*/(powerpc|ppc|pmac|chrp)(32)?(-[a-z0-9]+)?(/|$)')"
        if [ ! -z "$installboot" ]; then
          results_sorted="$installboot"
        fi
      fi
    fi
    #Prefer vmlinuz/initrd one directory deep for install and boot dirs
    installboot="$(printf '%s' "$results_sorted" | grep -Ei '^(install|boot|efi)[^/]*/[^/]+$')"
    if [ ! -z "$installboot" ]; then
      results_sorted="$installboot"
    else
      netboot="$(printf '%s' "$results_sorted" | grep -Ei '^(install|boot|efi)[^/]*/netboot/([^/]+/)?[^/]+$')"
      if [ ! -z "$netboot" ]; then
        results_sorted="$netboot"
      fi
    fi
    vmlinuz_path="$(printf '%s' "$results_sorted" | grep -Ei '(hwe-)?(vmlinuz|zImage|uImage|bzImage|Image|linux|vmlinux|kernel\.ubuntu|kernal\.ubuntu)(\.ubuntu)?(-rt|-cloud|-virt|-vm|-generic|-lts|-hwe){0,7}(\.efi|\.gz|\.lz|\.img|\.tar\.gz|\.cpio\.gz)?$' | head -n 1)"
    initrd_path="$(printf '%s' "$results_sorted" | grep -Ei '(hwe-)?(initrd|uInitrd|initramfs|initramfs-linux)(\.ubuntu)?(-rt|-cloud|-virt|-vm|-generic|-lts|-hwe){0,7}(\.efi|\.gz|\.lz|\.img|\.tar\.gz|\.cpio\.gz)?$' | head -n 1)"
  else
    echo "skipping dynamic kernal fetch"
  fi
  7z e "${iso}" "$vmlinuz_path" "$initrd_path" -mtc -mta -mtm -aou -y >/dev/null
  echo "kernal: $vmlinuz_path initrd: $initrd_path"
  cd "$opwd"
  if [ -z "$vmlinuz_path" ]; then
    onExit "kernal not found!"
  fi
  kbkernal="$(realpath "$kbdir")/$(basename "$vmlinuz_path")"
  kbinitrd="$(realpath "$kbdir")/$(basename "$initrd_path")"
  unzipKernal "$kbkernal" "$kbdir/tmp"
  decompressKernal "$kbkernal"
  #Set the qemu console serial type needed for kernal booting
  qconsole="$kb_console"
  qconsole_gui="${kb_console_gui:-tty0}"
  if [ -z "$qconsole" ]; then
    qconsole="ttyS0"
    if [ "$family_target" = "arm" ]; then
      qconsole="ttyAMA0"
    fi
    #handle s390x, powerpc
    if [ "$family_target" = "s390x" ] || [ "$family_target" = "powerpc" ]; then
      if [ "$arch" != "ppc" ]; then
        qconsole="hvc0"
      else
        qconsole="ttyPZ0"
      fi
    fi
  fi
fi

qarg() {
  args="$args $1"
}

qdrive() {
  qdrives="$qdrives $1"
}

load_arm_qfwr () {

    mkdir -p "$fwrdir"
    if [ "$arch" = "aarch64" ]; then
      AAVMF_CODE_PATH="/usr/share/AAVMF/AAVMF_CODE.fd"
      AAVMF_VARS_PATH="/usr/share/AAVMF/AAVMF_VARS.fd"
      AAVMF_CODE="$fwrdir/AAVMF_CODE.fd"
      AAVMF_VARS_NORMAL="$fwrdir/${dname}_AAVMF_VARS.fd"
      AAVMF_VARS_ISO="$fwrdir/${dname}_AAVMF_VARS${sname}.fd"
    else
      AAVMF_CODE_PATH="/usr/share/AAVMF/AAVMF32_CODE.fd"
      AAVMF_VARS_PATH="/usr/share/AAVMF/AAVMF32_VARS.fd"
      AAVMF_CODE="$fwrdir/AAVMF_CODE32.fd"
      AAVMF_VARS_NORMAL="$fwrdir/${dname}_AAVMF32_VARS.fd"
      AAVMF_VARS_ISO="$fwrdir/${dname}_AAVMF32_VARS${sname}.fd"
    fi
    if [ "$iso_boot" = "true" ]; then
      AAVMF_VARS="$AAVMF_VARS_ISO"
    else
      AAVMF_VARS="$AAVMF_VARS_NORMAL"
    fi
    #Copy AAVMF_VARS_ISO to AAVMF_VARS_NORMAL if it has boot entries before clearing NVRAM
    if virt-fw-vars "--help" >/dev/null 2>&1; then
      boot_entries="$(virt-fw-vars -i "$AAVMF_VARS_ISO" --print 2>/dev/null | grep -iE '^Boot[0-9]{4}' | grep -iE '[/\\]File')"
    else
      echo "WARNING: Falling back to strings command for EFI boot entries check!"
      boot_entries="$(strings -e l "$AAVMF_VARS_ISO" 2>/dev/null | grep -iE '\\EFI\\|/EFI/')"
    fi
    if [ ! -z "$boot_entries" ]; then
      echo "Setting NVRAM of normal boot"
      cp "$AAVMF_VARS_ISO" "$AAVMF_VARS_NORMAL"
      rm -f "$AAVMF_VARS_ISO"
    fi
    #Optimization
    if [ ! -f "$AAVMF_CODE" ]; then
      cp "$AAVMF_CODE_PATH" "$AAVMF_CODE"
    fi
    if [ "$iso_boot" != "true" ]; then
      if [ ! -f "$AAVMF_VARS" ]; then
        cp "$AAVMF_VARS_PATH" "$AAVMF_VARS"
      fi
    else
      cp "$AAVMF_VARS_PATH" "$AAVMF_VARS"
    fi
    qarg "-drive \"if=pflash,format=raw,unit=0,file=${AAVMF_CODE},readonly=on\""
    qarg "-drive \"if=pflash,format=raw,unit=1,file=${AAVMF_VARS}\""

}

#disable acpi
if [ "$no_acpi" = "true" ]; then
  acpi=",acpi=off"
fi

#Enable Graphics
if [ -z "$no_graphics" ]; then
  if [ "$family" = "$family_target" ] || [ "$family_target" = "x86" ]; then
    no_graphics="false"
  else
    no_graphics="true"
  fi
fi

q_netdev="user,id=net0"
q_netdev_device="virtio-net-device"
q_rng="virtio-rng-pci"
q_usb_cmd="-device \"qemu-xhci\""
case "$arch" in
  aarch64|arm)
    q_cpu="cortex-a72"
    if [ "$arch" = "arm" ]; then
      q_cpu="cortex-a15"
    fi
    q_machine="virt,gic-version=2"
    #Fix Network Controller for Windows Linux Suffers Driver issues with e1000
    if [ "$windows" = "true" ]; then
      q_netdev_device="e1000"
    fi
    #Drives
    if [ "$iso_boot" = "true" ]; then
      qdrive "-device \"virtio-scsi-device,id=scsi0\""
      qdrive "-drive \"file=${iso},format=raw,readonly=on,if=none,id=cdrom0,media=cdrom\""
      qdrive "-device \"scsi-cd,drive=cdrom0,bus=scsi0.0\""
    fi
    qdrive "-drive \"file=${cow},format=qcow2,if=none,id=disk0\""
    qdrive "-device \"virtio-blk-device,drive=disk0\""
    ;;
  riscv64)
    q_cpu="rv64"
    q_machine="virt"
    if [ -z "$no_acpi" ]; then
      if [ "$kb" != "true" ]; then
        acpi=",acpi=off"
      fi
    fi
    q_kernal="/usr/lib/u-boot/qemu-riscv64_smode/uboot.elf"
    if [ "$iso_boot" = "true" ]; then
      qdrive "-drive \"file=${iso},format=raw,readonly=on,if=virtio\""
    fi
    qdrive "-drive \"file=${cow},format=qcow2,if=virtio\""
    ;;
  ppc64le|ppc64|ppc)
    if [ "$arch" != "ppc" ]; then
      q_cpu="power8"
      q_machine="pseries-2.6,cap-htm=off"
    else
      q_cpu="G4"
      q_machine="mac99"
    fi
    q_location_bios="pc-bios"
    q_netdev_device="virtio-net-pci"
    if [ "$iso_boot" = "true" ]; then
      qdrive "-cdrom \"$iso\""
    fi
    qdrive "-hda \"$cow\""
    if [ "$iso_boot" = "true" ]; then
      qdrive "-boot c"
    fi
    qdrive "-prom-env 'auto-boot?=true'"
    qdrive "-prom-env 'vga-ndrv?=true'"
    qdrive "-prom-env 'boot-args=-v'"
    ;;
  s390x)
    q_cpu="max"
    q_machine="s390-ccw-virtio"
    q_netdev_device="virtio-net-ccw"
    q_rng=""
    if [ "$iso_boot" = "true" ]; then
      qdrive "-drive \"file=${iso},format=raw,readonly=on,if=none,id=cdrom0,media=cdrom\""
      qdrive "-device \"virtio-scsi-ccw,id=scsi0\""
      qdrive "-device \"scsi-cd,drive=cdrom0,bus=scsi0.0,bootindex=1\""
      cowindex="2"
    else
      cowindex="1"
    fi
    qdrive "-drive \"file=${cow},format=qcow2,if=none,id=disk0\""
    qdrive "-device \"virtio-blk-ccw,drive=disk0,id=vdisk0,bootindex=${cowindex}\""
    ;;
  i386|x86_64)
    if [ "$arch" = "x86_64" ]; then
      q_cpu="qemu64"
      q_machine="q35"
      q_netdev_device="virtio-net-pci"
      q_intel_vga="virtio"
    else
      q_cpu="pentium3"
      q_machine="pc"
      q_netdev_device="rtl8139"
      q_rng=""
      q_intel_vga="std"
    fi
    #For Windows XP and Windows Vista 64 bit (Vista Unconfirmed)
    if [ "$intel_old" = "true" ] || [ "$windows_old" = "true" ]; then
      q_machine="pc"
    fi
    #Fix Network Controller for Windows Linux Suffers Driver issues with e1000
    if [ "$windows" = "true" ]; then
      if [ "$windows_old" = "true" ]; then
        if [ "$windows_95" = "true" ]; then
          q_netdev_device="ne2k_pci"
        else
          q_netdev_device="rtl8139"
        fi
      else
        q_netdev_device="e1000"
      fi
    fi
    #Fix Mouse Issues
    if [ "$remove_ps2_mouse" = "true" ]; then
      q_machine="${q_machine},i8042=off"
    else
      #TODO: check if vmport is a feature on the host machine instead of just hard coded intel
      q_machine="${q_machine},vmport=off"
    fi
    q_usb_cmd="-usb"
    if [ "$iso_boot" = "true" ]; then
      qdrive "-cdrom \"$iso\""
    fi
    qdrive "-hda \"$cow\""
    if [ "$iso_boot" = "true" ]; then
      qdrive "-boot c"
    fi
    #Fix Windows 10 and Windows 11 Local Accounts Using win11-unattend.iso
    if [ "$windows_11" = "true" ]; then
      qdrive "-drive \"file=win/win11-unattend.iso,media=cdrom,readonly=on\""
    fi
    if [ "$no_graphics" != "true" ]; then
      if [ "$family" != "x86" ]; then
        qdrive "-vga \"${q_intel_vga}\""
        qdrive "-display \"default\""
      fi
    fi
    ;;
  *)
    onExit "NOT IMPLEMENTED YET! Arch: ${arch}"
    ;;
esac

#Enable KVM
if [ "$windows_95" != "true" ]; then
  if qemu-system-$arch -accel help 2>/dev/null | grep -qw kvm; then
    qdrive "-enable-kvm"
    q_cpu="host"
  fi
fi

#Override the network device
if [ ! -z "$network_device" ]; then
  q_netdev_device="$network_device"
fi

if [ "$no_graphics" != "true" ]; then
  qconsole="$qconsole_gui"

  if [ "$gpu_3d" = "true" ] || [ "$gpu_3d_soft" = "true" ]; then
    if [ "$gpu_2d" = "true" ]; then
      onExit "gpu_3d and gpu_2d cannot both be set to true at the same time"
    fi
  fi

  #Set the Display Window
  gpu_vendors="$(glxinfo -B 2>/dev/null | grep -iE 'OpenGL vendor|OpenGL renderer' | grep -iv 'NVIDIA')"
  if [ -z "$gpu_display" ]; then
    #NVIDIA breaks with GTK we need to use sdl
    if [ -z "$gpu_vendors" ] && [ "$gpu_2d" != "true" ]; then
      gpu_display="sdl"
    else
      gpu_display="gtk"
    fi
  fi

  gpu_display="$(printf '%s' "$gpu_display" | tr '[:upper:]' '[:lower:]')"
  case "$gpu_display" in
    sdl*) 
      sdl_display="true"
      ;;
  esac

  #Set the serial to none on SDL unless configured otherwise
  if [ -z "$serial" ]; then
    serial="none"
  fi

  if [ -z "$gpu_display_options" ]; then
    if [ "$gpu_display" = "gtk" ]; then
      gpu_display_options=",zoom-to-fit=off"
    fi
  fi

  #Set Resolution
  if [ ! -z "$xres" ]; then
    xres=",xres=${xres}"
    yres=",yres=${yres}"
  fi

  #3D GPU Acceleration
  if { [ -z "$gpu_3d" ] && [ "$gpu_2d" != "true" ] && [ "$windows_95" != "true" ]; } || [ "$gpu_3d" = "true" ] || [ "$gpu_3d_soft" = "true" ]; then
      #Set the GPU device
      if [ -z "$gpu_device" ]; then
        gpu_device="virtio-vga-gl"
        if { [ -z "$gpu_vendors" ] && [ "$gpu_3d_fallback" = "true" ]; } || [ "$gpu_3d_soft" = "true" ]; then
          gpu_device="virtio-vga"
        fi
      fi
      qdrive "-vga none"
      qdrive "-device \"${gpu_device}${xres}${yres}\""
      qdrive "-display \"${gpu_display}${gpu_display_options},gl=on\""
  fi

  #2D GPU Acceleration with a chance of 3D software rendering
  if [ "$gpu_2d" = "true" ]; then
    if qemu-system-$arch -device help 2>&1 | grep -qw "qxl-vga"; then
      qxl_vram="${qxl_vram:-134217728}"
      qdrive "-vga none"
      qdrive "-device \"qxl-vga,vram_size=${qxl_vram}${xres}${yres}\""
      qdrive "-display \"${gpu_display}${gpu_display_options}\""
    else
      echo "ERROR: qxl-vga isn't found for qemu-system-$arch" >&2
    fi
  fi
  qarg "-name \"$title\""
else
  printf '\033]0;%s\007' "$title"
fi

qarg "-cpu \"${q_cpu}\""
if [ ! -z "$q_machine" ] || [ ! -z "$acpi" ]; then
  qarg "-machine \"${q_machine}${acpi}\""
fi
qarg "-m $qram"
qarg "-smp $qcore"
if [ "$kb" = "true" ]; then
  qarg "-kernel \"${kbkernal}\""
  qarg "-initrd \"${kbinitrd}\""
  qarg "-append \"${kb_args}console=${qconsole}\""
else
  if [ ! -z "$q_kernal" ]; then
    qarg "-kernel \"${q_kernal}\""
  fi
  if [ ! -z "$q_location_bios" ]; then
    qarg "-L \"${q_location_bios}\""
  fi
  if [ "$family_target" = "arm" ]; then
    load_arm_qfwr "INIT"
  fi
fi

if [ "$network_restrict" = "true" ]; then
  net_append=",restrict=on"
fi
if [ "$no_wifi" != "true" ] && [ "$no_network" != "true" ]; then
  qarg "-netdev \"${q_netdev}${net_append}\""
  qarg "-device \"${q_netdev_device},netdev=net0\""
else
  qarg "-net none"
fi
if [ ! -z "$q_rng" ]; then
  qarg "-device \"${q_rng}\""
fi

#Merge arguments
args="${args}${qdrives}"

#Devices
if [ "$no_usb" != "true" ]; then
  qarg "$q_usb_cmd"
  qarg "-device \"usb-kbd\""
  qarg "-device \"${q_mouse}\""
else
  case "$q_mouse" in
    [uU][sS][bB]*)
      echo "USB-Mouse Ignoring ${q_mouse}"
      ;;
    *)
      qarg "-device \"${q_mouse}\""
      ;;
  esac
fi
if [ "$no_graphics" != "true" ]; then
    qarg "-device \"${q_audio}\""
fi

#Disable Graphics
if [ "$no_graphics" = "true" ]; then
  qarg "-nographic"
fi

#Disable rebooting
if [ "$no_reboot" = "true" ]; then
  qarg "-no-reboot"
fi

#Add Custom Serial
if [ ! -z "$serial" ]; then
  qarg "-serial ${serial}"
fi

#Launch QEMU with arguments
echo "cd \"${PWD}\"" >"$run_tmp"
if [ "$sdl_display" = "true" ]; then
  echo "export SDL_MOUSE_RELATIVE_SYSTEM_SCALE=1" >>"$run_tmp"
  echo "export SDL_MOUSE_RELATIVE_MODE_WARP=1" >>"$run_tmp"
  echo "export SDL_HINT_MOUSE_RELATIVE_SYSTEM_SCALE=1" >>"$run_tmp"
  echo "export SDL_HINT_MOUSE_RELATIVE_MODE_WARP=1" >>"$run_tmp"
  echo "export SDL_VIDEO_X11_WMCLASS=\"${DESKTOP_CLASS}\"" >>"$run_tmp"
  echo "export SDL_VIDEO_WAYLAND_WMCLASS=\"${DESKTOP_CLASS}\"" >>"$run_tmp"
else
  exec_exe="bin/exec_a-$uarch"
  if [ -f "$exec_exe" ] && [ "$disable_gtk_icons" != "true" ]; then
    exec_cmd="\"${exec_exe}\" \"${DESKTOP_CLASS}\" "
  else
    echo "Icons are disabled arch: ${uarch} disable_gtk_icons: ${disable_gtk_icons}"
  fi
fi
printf "%s\n\n" "${exec_cmd}qemu-system-${arch}${args}" >>"$run_tmp"
exec sh "$run_tmp"
exit $?
