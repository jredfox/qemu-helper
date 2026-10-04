#!/bin/sh

#install dir of qemu-helper
if [ -z "$install_dir" ]; then
    install_dir="$HOME/vms"
fi

#default ram to give qemu
qram="${qram:-4096}"
#default cores to give qemu
qcore="${qcore:-4}"
#default ram to give qemu for 32 bits
qram32="${qram32:-2048}"
#default cores to give qemu for 32 bits
qcore32="${qcore32:-2}"
#default cores to give qemu for powerpc 32 bits
qcoreppc32="${qcoreppc32:-1}"
#default max disk space for the qcow2 image
qdisk="${qdisk:-50G}"

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
                    sudo apt install -y python3-virt-firmware
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

#repair or create qemu-system-ppc64le symlink if it does not exist
if ! command -v qemu-system-ppc64le >/dev/null 2>&1; then
    qemu_system_ppc64="$(command -v qemu-system-ppc64 2>/dev/null)"
    if [ ! -z "$qemu_system_ppc64" ]; then
        dir_ppc64="$(dirname "$qemu_system_ppc64")"
        qppc64le="$dir_ppc64/qemu-system-ppc64le"
        qppc64el="$dir_ppc64/qemu-system-ppc64el"
        if [ -f "$qppc64el" ]; then
            #TODO: check macOS timestamps
            sudo cp -a "$qppc64el" "$qppc64le" >/dev/null 2>&1
        fi
        if ! command -v qemu-system-ppc64le >/dev/null 2>&1; then
            echo "creating symlink $qppc64le -> qemu-system-ppc64"
            sudo ln -sfn "qemu-system-ppc64" "$qppc64le"
        fi
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
for file in "iso"/*; do
    if [ ! -f "$file" ]; then
        continue
    fi
    name=$(basename "$file")
    case $name in
        *.[iI][sS][oO]) ;;
        *)  continue ;;
    esac
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
for file in "iso"/*; do
    if [ ! -f "$file" ]; then
        continue
    fi
    name=$(basename "$file")
    case $name in
        *.[iI][sS][oO]) ;;
        *)  continue ;;
    esac
    name="${name%.*}"
    if [ -f "disks/${name}.qcow2" ]; then
        echo "Skipping ISO $name"
    else
        qemu-img create -f qcow2 "disks/${name}.qcow2" "$qdisk"
        bootsh="boot/${name}.sh"
        bootisosh="boot/${name}_iso.sh"
        
        #Set Local Variables Initial State per iteration
        bits32="false"
        no_acpi="false"
        kb="false"
        checked="false"
        windows="false"
        windows_old="false"
        windows_95="false"
        gpu_3d_fallback="false"
        chk_iso="false"
        mac="false"
        lname="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"

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

        #Enable Automatic Support for specified OS
        case "$lname" in
            #Detect Alpine Linux
            *alpine*|*alps*)
                gpu_3d_fallback="true"
                ;;

            #Detect Microsoft Windows
            *mswin*|*window*|*microsoft*)
                windows="true"
                ;;

            #Detect mac
            *darwin*|*osx*|*macos*)
                mac="true"
                ;;

            #Detect Possible Windows MS-DOS FreeDOS
            *server*|*win*|*ms*|*dos*|fd*)
                chk_iso="true"
                ;;

            #Contain "mac" but are not mac
            *machine*|*emacs*)
                ;;

            #Detect mac
            *mac*)
                mac="true"
                ;;
        esac

        #Windows Vista and lower compatibility
        if [ "$windows" = "true" ]; then
            case "$lname" in
                *vista*|*xp*|2000[!0-9]*|*[!0-9]2000|*[!0-9]2000[!0-9]*)
                    windows_old="true"
                    windows="false"
                    ;;
                95[!0-9]*|*[!0-9]95|*[!0-9]95[!0-9]*|98[!0-9]*|*[!0-9]98|*[!0-9]98[!0-9]*|*dos*)
                    windows_95="true"
                    windows="false"
                    ;;
            esac
        fi

        #Dynamic Detection of windows and kb for linux
        if { [ "$arch" = "arm" ] && [ "$checked" != "true" ]; } || [ "$chk_iso" = "true" ]; then
            chked_iso="false"
            oefi="$(7z l -ba "iso/${name}.iso" | awk '{ c1 = toupper(substr($1,1,1)); if (c1 == "D" || toupper(substr($3,1,1)) == "D") max = (c1 != "D" ? 3 : 1); else max = (c1 != "." ? 5 : 3); for (i=1; i<=max && i<NF; i++) $i=""; sub(/^[[:space:]]+/, ""); print }' | sed 's|^[^/]|/&|')"
            #Dynamically Detect Windows
            if [ ! -z "$(printf '%s' "$oefi" | grep -Ei '^/(boot/bcd|bootmgr|bootmgr\.efi|efi/microsoft|uefi/microsoft)(/)?$')" ]; then
                windows="true"
                chked_iso="true"
                echo "debug windows found ${name}"
            fi
            #Dynamically Detect Old Windows MS-DOS FreeDOS
            if { [ "$arch" = "i386" ] || [ "$arch" = "x86_64" ]; } && [ "$chked_iso" != "true" ]; then
                #Detect Windows 95/98/me MS-DOS FreeDOS
                if [ ! -z "$(printf '%s' "$oefi" | grep -Ei '^/(win9[^/]*|winme[^/]*|FDOS[^/]*|freedos|CONFIG\.SYS)$')" ]; then
                    windows_95="true"
                    chked_iso="true"
                fi
                #Dynamically Detect Windows 2000 and Higher
                if [ "$chked_iso" != "true" ] && [ ! -z "$(printf '%s' "$oefi" | grep -Ei '^/([^/]+/[^/]+\.cab)$')" ]; then
                    windows_old="true"
                    echo "debug old windows found ${name}"
                fi
            fi
            #Dynamically Determine if kernal boot needs to be enabled for arm32 images
            if [ "$chked_iso" != "true" ] && [ "$arch" = "arm" ] && [ -z "$(printf '%s' "$oefi" | grep -Ei '^/(EFI|BOOT)(/)?$')" ]; then
                kb="true"
                echo "debug arm32 EFI not found ${name}"
            fi
        fi

        #If windows 95/98/me was detected by name or automatically set requirements
        if [ "$windows_95" = "true" ]; then
            arch="i386"
            bits32="true"
            qram32="512"
            qcore32="cpus=1,sockets=1,cores=1,threads=1"
        fi
        
        if [ "$bits32" = "true" ]; then
            qram="$qram32"
            qcore="$qcore32"
        fi
        echo "cd \"${install_dir}\"" >"$bootisosh"
        echo "cd \"${install_dir}\"" >"$bootsh"
        if [ "$kb" = "true" ]; then
            echo "export kb=\"true\"" >>"$bootisosh"
            echo "export kb=\"true\"" >>"$bootsh"
        fi
        if [ "$no_acpi" = "true" ]; then
            echo "export no_acpi=\"true\"" >>"$bootisosh"
            echo "export no_acpi=\"true\"" >>"$bootsh"
        fi
        if [ "$gpu_3d_fallback" = "true" ]; then
            echo "export gpu_3d_fallback=\"true\"" >>"$bootisosh"
            echo "export gpu_3d_fallback=\"true\"" >>"$bootsh"
        fi
        if [ "$windows" = "true" ]; then
            echo "export windows=\"true\"" >>"$bootisosh"
            echo "export windows=\"true\"" >>"$bootsh"
        fi
        if [ "$windows_old" = "true" ]; then
            echo "export windows_old=\"true\"" >>"$bootisosh"
            echo "export windows_old=\"true\"" >>"$bootsh"
            echo "export no_reboot=\"false\"" >>"$bootisosh"
        fi
        if [ "$windows_95" = "true" ]; then
            echo "export windows_95=\"true\"" >>"$bootisosh"
            echo "export windows_95=\"true\"" >>"$bootsh"
            echo "#Set no_usb=\"false\" to allow usb on windows 95/98/2000 After you have installed the drivers"
            echo "export no_usb=\"true\"" >>"$bootisosh"
            echo "export no_usb=\"true\"" >>"$bootsh"
            echo "export q_audio=\"sb16\"" >>"$bootisosh"
            echo "export q_audio=\"sb16\"" >>"$bootsh"
            echo "export no_reboot=\"false\"" >>"$bootisosh"
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
