#!/bin/sh

#install dir of qemu-helper
if [ -z "$install_dir" ]; then
    install_dir="$HOME/vms"
fi
#default ram to give qemu
if [ -z "$qram" ]; then
    qram="4096"
fi
#default cores to give qemu
if [ -z "$qcore" ]; then
    qcore="4"
fi
#default ram to give qemu for 32 bits
if [ -z "$qram32" ]; then
    qram32="2048"
fi
#default cores to give qemu for 32 bits
if [ -z "$qcore32" ]; then
    qcore32="2"
fi
#default cores to give qemu for powerpc 32 bits
if [ -z "$qcoreppc32" ]; then
    qcoreppc32="1"
fi
#default max disk space for the qcow2 image
if [ -z "$qdisk" ]; then
    qdisk="50G"
fi
org_qram="$qram"
org_qcore="$qcore"
org_qram32="$qram32"
org_qcore32="$qcore32"

#install qemu
if ! output=$(qemu-img "--version" >/dev/null 2>&1); then
    echo "Installing QEMU"
    #Debian & Ubuntu Based
    if command -v apt >/dev/null 2>&1; then
        sudo apt update
        sudo apt install -y qemu-kvm qemu-system virt-manager bridge-utils qemu-efi-aarch64 qemu-efi-arm
        #RISC-V DEPS
        sudo apt install -y opensbi qemu-system-riscv64 qemu-efi-riscv64 u-boot-qemu
        #TODO: install 7z or py7zip depending upon what is avaliable
        if ! virt-fw-vars "--help" >/dev/null 2>&1; then
            printf "%s" "Do you want to install virt-fw-vars which is recomended for older Ubuntu Arm64 images? [Y/N] "
            read -r result
            case "$result" in
                [Yy]*) 
                    sudo apt install -y python3-virt-firmware virt-fw-vars
                    ;;
            esac
        fi
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
        echo "Unsupported Linux Distro Please Manually install QEMU then run this script again!"
        exit 1
    fi
fi
#create qemu-system-ppc64le symlink if it does not exist
if ! command -v qemu-system-ppc64le >/dev/null 2>&1; then
    qemu_system_ppc64="$(command -v qemu-system-ppc64 2>/dev/null)"
    if [ ! -z "$qemu_system_ppc64" ]; then
        qppc64le="$(dirname "$qemu_system_ppc64")/qemu-system-ppc64le"
        echo "creating symlink $qppc64le -> qemu-system-ppc64"
        sudo ln -sfn "qemu-system-ppc64" "$qppc64le"
    fi
fi
#make install_dir absolute
mkdir -p "$install_dir"
install_dir="$(realpath "$install_dir")"
current_dir="$( cd -- "$(dirname "${0}")" >/dev/null 2>&1 ; pwd -P )"
#cd into the install dir
cd "$install_dir" || exit 1
#create dirs
mkdir -p "boot"
mkdir -p "disks"
mkdir -p "iso"
mkdir -p "share"
#copy the installation files if not already extracted to the install dir
if [ "$install_dir" != "$current_dir" ]; then
    echo "copying install files"
    mv "$current_dir/iso"/* "$install_dir/iso/" >/dev/null 2>&1
    cp -rf "$current_dir"/*.sh "$install_dir/"
fi

#create powerpc32 symlinks
for file in "iso"/*.iso; do
    if [ ! -f "$file" ]; then
        continue
    fi
    name=$(basename "$file")
    name="${name%.*}"
    lname="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
    lnk_name="iso/${name}-ppc32.iso"
    case "$lname" in
        # powerpc64 little edian
        *ppc64el*|*ppc64le*|*powerpc64le*|*powerpc64el*)
            arch="ppc64le"
            ;;

        # powerpc32
        *ppc32*|*ppc?32*|*powerpc32*|*powerpc?32*|*[!a-z0-9]ppc[!a-z0-9]*|ppc[!a-z0-9]*|*[!a-z0-9]ppc|ppc)
            arch="ppc32"
            ;;

        # powerpc64
        *ppc64*|*powerpc64*|*powerpc*)
            arch="ppc64"
            ;;

        *)
            arch=""
            ;;
    esac
    
    if [ "$arch" = "ppc64" ]; then
        #prevent accidental overwrite of similar ISO files
        if [ ! -f "$lnk_name" ]; then
            oefi="$(7z l -ba "iso/${name}.iso" | awk 'toupper(substr($1,1,1)) == "D" || toupper(substr($3,1,1)) == "D" { max = (toupper(substr($1,1,1)) != "D" ? 3 : 1); for (i=1; i<=max && i<NF; i++) $i=""; sub(/^[[:space:]]+/, ""); print }' | sed 's|^[^/]|/&|' | grep -vEi '^/(install|boot|efi)[^/]*/e500mc(/|$)' | grep -vEi '^/(install|boot|efi)[^/]*/(powerpc64|ppc64)(-[a-z0-9]+)?(/|$)' | grep -Ei '^/(install|boot|efi)[^/]*/(powerpc|ppc|pmac|chrp)(32)?(-[a-z0-9]+)?(/|$)')"
            if [ ! -z "$oefi" ]; then
                echo "creating symlink: $lnk_name"
                ln -sfn "${name}.iso" "$lnk_name"
            fi
        fi
    fi
done

#install cows
for file in "iso"/*.iso; do
    if [ ! -f "$file" ]; then
        echo "Skipping non file: $file"
        continue
    fi
    name=$(basename "$file")
    name="${name%.*}"
    if [ -f "disks/${name}.qcow2" ]; then
        echo "Skipping ISO $name"
    else
        qemu-img create -f qcow2 "disks/${name}.qcow2" "$qdisk"
        bootsh="boot/${name}.sh"
        bootisosh="boot/${name}_iso.sh"
        
        #Set Local Variables Initial State per iteration
        LWDE="false"
        bits32="false"
        no_acpi="false"
        kb="false"
        checked="false"
        lname="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"

        #Enable LightWeight Deskop Enviorment Flag
        case "$lname" in
            *xfce*|*[!a-z]mate*|mate*|*lxqt*|*lxde*|*budgie*|*lubuntu*|*xubuntu*)
                LWDE="true"
                ;;
        esac

        #Extract the arch from from the ISO and translate the arch aliases to be standard
        case "$lname" in
            # ARM 64-bit
            *aarch64*|*arm64*|*armv8*|*armv9*)
                arch="aarch64"
                ;;

            # ARM 32-bit
            *aarch32*|*arm32*|*armv[0-7]*|*armhf*|*armel*|*[!a-z]arm[!a-z]*|arm[!a-z]*|*[!a-z]arm|arm)
                arch="arm"
                bits32="true"
                ;;

            # RISC-V
            *risc-v*|*riscv*|*risc64*|*risc?64*|*rv64*)
                arch="riscv64"
                ;;

            # powerpc64 little edian
            *ppc64el*|*ppc64le*|*powerpc64le*|*powerpc64el*)
                arch="ppc64le"
                ;;

            # powerpc32
            *ppc32*|*ppc?32*|*powerpc32*|*powerpc?32*|*[!a-z0-9]ppc[!a-z0-9]*|ppc[!a-z0-9]*|*[!a-z0-9]ppc|ppc)
                arch="ppc32"
                bits32="true"
                qcore32="$qcoreppc32"
                ;;

            # powerpc64
            *ppc64*|*powerpc64*|*powerpc*)
                arch="ppc64"
                kb="true"
                ;;

            # IBM Z
            *ibm-z*|*s390x*|*[!a-z0-9]s390[!a-z0-9]*|s390[!a-z0-9]*|*[!a-z0-9]s390|s390)
                arch="s390x"
                ;;

            # x86 64-bit
            *x86?64*|*amd64*|*x64*|*64bit*|*64?bit*)
                arch="x86_64"
                ;;

            # x86 32-bit
            *i[0-9]86*|*i[0-9][0-9]86*|*i[0-9][0-9][0-9]86*|*x86?32*|*x86*|*32bit*|*32?bit*|*x32*|*ia?32*|*ia32*)
                arch="i386"
                bits32="true"
                ;;

            *)
                arch="x86_64"
                ;;
        esac

        #Enable Kernal Boot and Disable ACPI
        case "$lname" in
            *-kb[!a-z]*|*-kb)
                kb="true"
                checked="true"
                ;;

            *-old[!a-z]*|*-old)
                if [ "$arch" = "arm" ]; then
                    kb="true"
                else
                    no_acpi="true"
                fi
                checked="true"
                ;;

            *-no-acpi[!a-z]*|*-no-acpi)
                no_acpi="true"
                checked="true"
                ;;
        esac

        #Dynamically Determine if kernal boot needs to be enabled for arm32 images
        if [ "$arch" = "arm" ]; then
            if [ "$checked" != "true" ]; then
                oefi="$(7z l -ba "iso/${name}.iso" | awk 'toupper(substr($1,1,1)) == "D" || toupper(substr($3,1,1)) == "D" { max = (toupper(substr($1,1,1)) != "D" ? 3 : 1); for (i=1; i<=max && i<NF; i++) $i=""; sub(/^[[:space:]]+/, ""); print }' | sed 's|^[^/]|/&|' | grep -Ei '^/(EFI|BOOT)(/)?$')"
                if [ -z "$oefi" ]; then
                    kb="true"
                fi
            fi
        fi
        
        if [ "$bits32" = "true" ]; then
            qram="$qram32"
            qcore="$qcore32"
        fi
        echo "cd \"${install_dir}\"" >"$bootisosh"
        echo "cd \"${install_dir}\"" >"$bootsh"
        if [ "$LWDE" = "true" ]; then
            echo "export LWDE=\"true\"" >>"$bootisosh"
            echo "export LWDE=\"true\"" >>"$bootsh"
        fi
        if [ "$kb" = "true" ]; then
            echo "export kb=\"true\"" >>"$bootisosh"
            echo "export kb=\"true\"" >>"$bootsh"
        fi
        if [ "$no_acpi" = "true" ]; then
            echo "export no_acpi=\"true\"" >>"$bootisosh"
            echo "export no_acpi=\"true\"" >>"$bootsh"
        fi
        echo "sh boot.sh \"${name}\" true ${arch} ${qram} ${qcore}" >>"$bootisosh"
        echo "sh boot.sh \"${name}\" false ${arch} ${qram} ${qcore}" >>"$bootsh"
        chmod +x "$bootisosh"
        chmod +x "$bootsh"

        #Reset Variables
        qram="$org_qram"
        qcore="$org_qcore"
        qram32="$org_qram32"
        qcore32="$org_qcore32"
    fi
done
