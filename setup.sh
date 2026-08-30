#install qemu
if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y qemu-kvm qemu-system virt-manager bridge-utils
elif command -v dnf >/dev/null 2>&1; then
    qemu_sys=qemu-system-x86
    if ! dnf list --quiet "$qemu_sys" >/dev/null 2>&1; then
        qemu_sys=qemu-system-aarch64
    fi
    sudo dnf install -y qemu-system
    sudo dnf install -y $qemu_sys
    sudo dnf install -y qemu-kvm virt-manager
else
    echo Unsupported Linux Distro Please Manually install QEMU then delete the install qemu block and run this script again
fi
#setup share dir
sharedir="$HOME/vms/share"
mkdir -p "$sharedir"
#install cows
cd "$HOME/vms"
mkdir -p "disks"
mkdir -p "boot"
mkdir -p "iso"
for file in "iso"/*.iso; do
    name=$(basename "$file")
    name="${name%.*}"
    if [ -f "disks/${name}.qcow2" ]; then
        echo Skipping ISO $name
    else
        qemu-img create -f qcow2 "disks/${name}.qcow2" 50G
        bootsh="boot/${name}.sh"
        bootisosh="boot/${name}_iso.sh"
        arch="${name##*-}"
        echo "cd $HOME/vms/boot" >"$bootsh"
        echo "bash ../bootnormal.sh ${name} ${arch}" >>"$bootsh"
        echo "cd $HOME/vms/boot" >"$bootisosh"
        echo "bash ../bootiso.sh ${name} ${arch}" >>"$bootisosh"
        chmod +x "$bootsh"
        chmod +x "$bootisosh"
    fi
done
