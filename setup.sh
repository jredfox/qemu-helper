#!/bin/sh

#install dir of qemu-helper
if [ -z "$install_dir" ]; then
    install_dir="$HOME/vms"
fi
install_dir_q="\"$install_dir\""
#default ram to give qemu
if [ -z "$qemu_ram" ]; then
    qemu_ram="4096"
fi
#default cores to give qemu
if [ -z "$qcore" ]; then
    qcore="4"
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
        echo "Unsupported Linux Distro Please Manually install QEMU then run this script again"
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
        
        LWDE="false"
        case $(printf '%s' "$name" | tr '[:upper:]' '[:lower:]') in
            *xfce*|*mate*|*lxqt*|*lxde*|*budgie*)
                LWDE="true"
                ;;
        esac

        #Extract the arch from from the ISO and translate the arch aliases to be standard
        arch_name=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')
        case "$arch_name" in

            # ARM 64-bit
            *aarch64*|*arm64*|*armv8*|*armv9*)
                arch="aarch64"
                ;;

            # ARM 32-bit
            *aarch32*|*arm32*|*armv[0-7]*|*armhf*|*armel*)
                arch="arm"
                ;;

            # RISC-V
            *risc-v*|*riscv*|*risc64*|*risc?64*)
                arch="riscv64"
                ;;

            # IBM Z
            *ibm-z*|*s390x*)
                arch="s390x"
                ;;

            # x86 64-bit
            *x86?64*|*amd64*|*x64*|*64bit*|*64?bit*)
                arch="x86_64"
                ;;

            # x86 32-bit
            *i[0-9]86*|*i[0-9][0-9]86*|*i[0-9][0-9][0-9]86*|*x86?32*|*x86*|*32bit*|*32?bit*|*x32*|*ia-32*)
                arch="i386"
                ;;

            *)
                arch="x86_64"
                ;;
        esac
        echo "cd ${install_dir_q}" >"$bootsh"
        echo "sh bootnormal.sh ${name} ${arch} ${qemu_ram} ${qcore} ${LWDE}" >>"$bootsh"
        echo "cd ${install_dir_q}" >"$bootisosh"
        echo "sh bootiso.sh ${name} ${arch} ${qemu_ram} ${qcore} ${LWDE}" >>"$bootisosh"
        chmod +x "$bootsh"
        chmod +x "$bootisosh"
    fi
done
