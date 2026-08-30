#install dir of qemu-helper
if [ -z "$install_dir" ]; then
    install_dir="$HOME/vms"
fi
#default ram to give qemu
if [ -z "$qemu_ram" ]; then
    qemu_ram="4096"
fi

#install qemu
if ! output=$(qemu-img "--version" > /dev/null 2>&1); then
    echo "Installing QEMU"
    #Debian & Ubuntu Based
    if command -v apt >/dev/null 2>&1; then
        sudo apt update
        sudo apt install -y qemu-kvm qemu-system virt-manager bridge-utils
    elif command -v dnf >/dev/null 2>&1; then
        #Fedora Support
        qemu_sys=qemu-system-x86
        if ! dnf list --quiet "$qemu_sys" >/dev/null 2>&1; then
            qemu_sys=qemu-system-aarch64
        fi
        sudo dnf install -y qemu-system
        sudo dnf install -y $qemu_sys
        sudo dnf install -y qemu-kvm virt-manager
    else
        echo Unsupported Linux Distro Please Manually install QEMU then run this script again
    fi
fi
#cd into the install dir
cd "$install_dir"
#create dirs
mkdir -p "disks"
mkdir -p "boot"
mkdir -p "iso"
mkdir -p "share"
#install cows
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
        echo "cd $install_dir" >"$bootsh"
        echo "sh bootnormal.sh ${name} ${arch} ${qemu_ram}" >>"$bootsh"
        echo "cd $install_dir" >"$bootisosh"
        echo "sh bootiso.sh ${name} ${arch} ${qemu_ram}" >>"$bootisosh"
        chmod +x "$bootsh"
        chmod +x "$bootisosh"
    fi
done
