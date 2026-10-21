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
org_pwd="$PWD"
#Change path to search for resources
export PATH="$PATH:$install_dir/resources"

#Find sudo command
if [ "$(id -u)" -eq 0 ]; then
    sudo_cmd="env"
    echo "WARNING: Running setup.sh as root every sudo command will run with env command instead of sudo"
elif command -v sudo >/dev/null 2>&1; then
    sudo_cmd="sudo"
elif command -v sudo-rs >/dev/null 2>&1; then
    sudo_cmd="sudo-rs"
elif command -v doas >/dev/null 2>&1; then
    sudo_cmd="doas"
elif command -v opendoas >/dev/null 2>&1; then
    sudo_cmd="opendoas"
elif command -v doas-rs >/dev/null 2>&1; then
    sudo_cmd="doas-rs"
elif command -v opendoas-rs >/dev/null 2>&1; then
    sudo_cmd="opendoas-rs"
else
    echo "ERROR: Unable to find sudo sudo-rs doas opendoas etc"
    exit 1
fi

sudo_script() {

    #If user is root return
    if [ "$sudo_cmd" = "env" ]; then
        return 0
    fi

    max_tries="${1:-3}"
    index="1"
    while [ "$index" -le "$max_tries" ]; do
        if "$sudo_cmd" echo "hello" >/dev/null; then
          return 0
        fi
        echo "Password Failed Attempts: $index"
        index=$((index + 1))
    done

    echo "Failed to obtain Admin Permission with ${sudo_cmd}"
    exit 1

}

patchNVRAMPADDING() {

    if [ ! -f "${1}.fd" ]; then
        echo "ERROR NVRAM File not found: \"${1}.fd\""
        return 1
    fi

    PF_CODE="${1}_QH.fd"
    PF_VARS="${2}_QH.fd"
    "$sudo_cmd" rm -f "${PF_CODE}"
    if [ "$(wc -c <"${1}.fd")" -lt "${3}" ]; then
        "$sudo_cmd" cp "${1}.fd" "${PF_CODE}"
        "$sudo_cmd" truncate -s "${3}" "${PF_CODE}"
    else
        "$sudo_cmd" ln -sfn "${1}.fd" "${PF_CODE}"
    fi
    if [ "$(wc -c <"${PF_VARS}")" -lt "${3}" ]; then
        if [ -L "${PF_VARS}" ]; then
            "$sudo_cmd" rm -f "${PF_VARS}"
            "$sudo_cmd" cp "${2}.fd" "${PF_VARS}"
        fi
        "$sudo_cmd" truncate -s "${3}" "${PF_VARS}"
    fi

}

patchNVRAMTimeOut() {

    if [ ! -f "${1}" ]; then
        echo "ERROR NVRAM File not found: \"${1}\""
        return 1
    fi

    "$sudo_cmd" rm -f "${2}"
    printf '%s\n' '{ "version": 2, "variables": [ { "name": "Timeout", "guid": "8be4df61-93ca-11d2-aa0d-00e098032b8c", "attr": 7, "data": "0000" } ] }' >"$install_dir/tmp/timeout.json"
    virt_fw="$(command -v virt-fw-vars 2>/dev/null)"
    if [ ! -z "$virt_fw" ]; then
        "$sudo_cmd" "$virt_fw" -i "${1}" -o "${2}" --set-json "$install_dir/tmp/timeout.json" || "$sudo_cmd" cp -a "${1}" "${2}"
    else
        echo "ERROR: virt-fw-vars not found arm32 arm64 and risc-v timeout will be 5 seconds. To fix this install it and run \"rm -f ~/.qemu-helper\" then finally sh setup.sh again"
        "$sudo_cmd" cp -a "${1}" "${2}"
    fi

}

#install qemu
alpine="false"
if ! qemu-img "--version" >/dev/null 2>&1 || [ "$INSTALL_FORCE" = "true" ] || [ ! -f "$HOME/.qemu-helper" ]; then
    echo "Installing QEMU"
    sudo_script "4"
    #Debian & Ubuntu Based
    if command -v apt >/dev/null 2>&1; then
        "$sudo_cmd" apt update
        "$sudo_cmd" apt install -y qemu-kvm qemu-system virt-manager bridge-utils qemu-efi-aarch64 qemu-efi-arm zstd
        #RISC-V DEPS
        "$sudo_cmd" apt install -y opensbi qemu-system-riscv64 qemu-efi-riscv64
        #Additional Deps
        for pkg in curl lsof python3-virt-firmware; do
            "$sudo_cmd" apt install -y "$pkg"
        done
        #md5sum is required for icons to work
        if ! md5sum "--help" >/dev/null 2>&1 && ! md5 "--help" >/dev/null 2>&1; then
            echo "Installing md5sum"
            "$sudo_cmd" apt install coreutils -y
        fi
        #Install 7z
        if ! command -v 7z >/dev/null 2>&1; then
            for pkg7z in 7zip p7zip-full p7zip-plugins p7zip 7z 7zz; do
                "$sudo_cmd" apt install -y "$pkg7z" || continue
                if command -v 7z >/dev/null 2>&1 || command -v 7zz >/dev/null 2>&1; then
                    break
                fi
            done
        fi
    elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
        #Fedora Support
        pkg_dnf="dnf"
        if ! command -v dnf >/dev/null 2>&1; then
            pkg_dnf="yum"
        fi
        "$sudo_cmd" $pkg_dnf check-update
        for pkg in qemu-kvm 'qemu-system-*' virt-manager bridge-utils edk2-aarch64 edk2-riscv64 opensbi coreutils zstd curl lsof python3-virt-firmware; do
            echo "installing pkg: ${pkg}"
            "$sudo_cmd" $pkg_dnf install -y "$pkg"
        done
        "$sudo_cmd" $pkg_dnf group install -y virtualization
        #Install 7z with symlink of 7zz to 7z
        if ! command -v 7z >/dev/null 2>&1; then
            for pkg7z in 7zip 7z p7zip-full p7zip-plugins p7zip 7zz; do
                "$sudo_cmd" $pkg_dnf install -y "$pkg7z" || continue
                if command -v 7z >/dev/null 2>&1 || command -v 7zz >/dev/null 2>&1; then
                    break
                fi
            done
        fi
    elif command -v apk >/dev/null 2>&1; then
        alpine="true"
        "$sudo_cmd" apk update
        qemu_systems="$("$sudo_cmd" apk search -q 'qemu-system-*')"
        qemu_systems="$(printf '%s' "$qemu_systems" | sed 's/-[0-9][0-9.]*-r[0-9]*$//' | tr '\n' ' ')"
        "$sudo_cmd" apk add qemu qemu-img qemu-modules $qemu_systems virt-manager bridge-utils curl lsof zstd

        #Different alpine versions have different package names
        for pkg in ovmf swtpm virtiofsd qemu-virtiofsd; do
            "$sudo_cmd" apk add "$pkg"
        done
        
        #Install aavmf
        if [ "$alpine_legacy" = "true" ]; then
            mkdir -p "$install_dir/tmp/aavmf"
            "$sudo_cmd" apk fetch --arch aarch64 --no-cache --allow-untrusted aavmf -o "$install_dir/tmp/aavmf" || "$sudo_cmd" apk fetch --no-cache --allow-untrusted aavmf -o "$install_dir/tmp/aavmf" >/dev/null 2>&1
            aavmf_apk="$(find "$install_dir/tmp/aavmf" -maxdepth 1 -type f | head -n 1)"
            "$sudo_cmd" apk add --allow-untrusted "$aavmf_apk"
            rm -rf "$install_dir/tmp/aavmf"
        fi
        
        #Install firmware
        qemu_firmware="$("$sudo_cmd" apk search -q 'edk2*' 'qemu-edk2*' 'qemu-*firmware*' 'qemu-*openbios*')"
        qemu_firmware="$(printf '%s' "$qemu_firmware" | sed 's/-[0-9][0-9.]*-r[0-9]*$//' | tr '\n' ' ')"
        "$sudo_cmd" apk add $qemu_firmware

        #Create symlinks
        qemu_fwr="/usr/share/qemu"
        "$sudo_cmd" mkdir -p "/usr/share/AAVMF" >/dev/null 2>&1
        "$sudo_cmd" ln -sfn "${qemu_fwr}/edk2-aarch64-code.fd" "/usr/share/AAVMF/AAVMF_CODE.fd"
        #AAVMF_VARS.fd and AAVMF32_VARS.fd are the binary identicle
        if [ -f "${qemu_fwr}/edk2-aarch64-vars.fd" ]; then
            "$sudo_cmd" ln -sfn "${qemu_fwr}/edk2-aarch64-vars.fd" "/usr/share/AAVMF/AAVMF_VARS.fd"
        else
            "$sudo_cmd" ln -sfn "${qemu_fwr}/edk2-arm-vars.fd" "/usr/share/AAVMF/AAVMF_VARS.fd"
        fi
        if [ -f "${qemu_fwr}/edk2-arm-code.fd" ]; then
            "$sudo_cmd" ln -sfn "${qemu_fwr}/edk2-arm-code.fd" "/usr/share/AAVMF/AAVMF32_CODE.fd"
            "$sudo_cmd" ln -sfn "${qemu_fwr}/edk2-arm-vars.fd" "/usr/share/AAVMF/AAVMF32_VARS.fd"
        else
            echo "WARNING: arm32 firmware not found we will use the debian package instead"
        fi
        if [ -f "${qemu_fwr}/edk2-riscv-code.fd" ]; then
            "$sudo_cmd" mkdir -p "/usr/share/qemu-efi-riscv64" >/dev/null 2>&1
            "$sudo_cmd" ln -sfn "${qemu_fwr}/edk2-riscv-code.fd" "/usr/share/qemu-efi-riscv64/RISCV_VIRT_CODE.fd"
            "$sudo_cmd" ln -sfn "${qemu_fwr}/edk2-riscv-vars.fd" "/usr/share/qemu-efi-riscv64/RISCV_VIRT_VARS.fd"
        else
            echo "ERROR: RISC-V Firmware is Missing. This means RISC-V ISO and QCOW2 Images won't be able to boot"
        fi

        # md5sum is required for icons to work
        if ! md5sum "--help" >/dev/null 2>&1 && ! md5 "--help" >/dev/null 2>&1; then
            echo "Installing md5sum"
            "$sudo_cmd" apk add coreutils
        fi
        #Install 7z with symlink of 7zz to 7z
        if ! command -v 7z >/dev/null 2>&1; then
            for pkg7z in 7zip 7z p7zip-full p7zip-plugins p7zip 7zz; do
                "$sudo_cmd" apk add "$pkg7z" || continue
                if command -v 7z >/dev/null 2>&1 || command -v 7zz >/dev/null 2>&1; then
                    break
                fi
            done
        fi

        #Create 7z symlink if required
        if [ ! -f "/usr/bin/7z" ]; then
            path7z="$(command -v 7zz 2>/dev/null)"
            if [ ! -z "$path7z" ]; then
                "$sudo_cmd" ln -sfn "$path7z" "/usr/bin/7z"
            fi
        fi

        #Install virt-fw-vars
        "$sudo_cmd" apk add --no-cache python3 py3-cryptography
        tmp_virt="${install_dir}/tmp/virt-fw-vars"
        virt_fw_version="v0.97"
        mkdir -p "${tmp_virt}"
        mkdir -p "${install_dir}/resources"
        curl -A "Mozilla/5.0 (X11; Linux x86_64; rv:152.0) Gecko/20100101 Firefox/152.0" -fsSL "https://gitlab.com/kraxel/virt-firmware/-/archive/${virt_fw_version}/virt-firmware-${virt_fw_version}.zip" -o "${tmp_virt}/virt-firmware-${virt_fw_version}.zip" || exit 1
        7z x "${tmp_virt}/virt-firmware-${virt_fw_version}.zip" -o"${tmp_virt}" -aoa >/dev/null
        vars_src="${tmp_virt}/virt-firmware-${virt_fw_version}/virt"
        rm -rf "${install_dir}/resources/virt"
        cp -rfa "${vars_src}" "${install_dir}/resources/virt"

        # Create the virt-fw-vars launcher
        cat >"${install_dir}/resources/virt-fw-vars" <<'EOL'
#!/usr/bin/python3

import re
import sys

from virt.firmware.vars import main

if __name__ == '__main__':
    sys.argv[0] = re.sub(r'(-script\.pyw|\.exe)?$', '', sys.argv[0])
    sys.exit(main())
EOL

        chmod +x "$install_dir/resources/virt-fw-vars"
        cat >"${install_dir}/resources/pkg_resources.py" <<'EOL'
import os

_virt_fw_root = os.path.dirname(os.path.abspath(__file__))

def resource_filename(pkg_name, pkg_path):
    if not pkg_name.startswith('virt.'):
        error_msg = "pkg_name does not start with virt." + str(pkg_name)
        raise Exception(error_msg)
    return os.path.join(_virt_fw_root, pkg_name.replace('.', '/'), pkg_path)
EOL
        if [ -d "$tmp_virt" ]; then
            rm -rf "$tmp_virt"
        fi
        echo "virt-fw-vars has been installed"
    else
        touch "$HOME/.qemu-helper"
        echo "Unsupported Linux Distro Please Manually install QEMU then run this script again!"
        exit 1
    fi

    #Create 7z symlink if required
    if [ "$alpine" != "true" ] && [ ! -f "/usr/bin/7z" ]; then
        path7z="$(command -v 7zz 2>/dev/null)"
        if [ ! -z "$path7z" ]; then
            "$sudo_cmd" ln -sfn "$path7z" "/usr/bin/7z"
        fi
    fi

    #Make tmp dir
    mkdir -p "$install_dir/tmp"

    #Install arm32 efi firmware
    efi_arm32_code="/usr/share/AAVMF/AAVMF32_VARS.fd"
    if [ ! -f "$efi_arm32_code" ]; then
        qemu_efi_dir="$install_dir/tmp/qemu-efi-arm"
        mkdir -p "$qemu_efi_dir"
        qemu_efi_deb="$qemu_efi_dir/qemu-efi-arm.deb"
        for efi_arm32_url in 'https://launchpadlibrarian.net/794789100/qemu-efi-arm_2024.02-2ubuntu0.2_all.deb' 'https://launchpad.net/ubuntu/+archive/primary/+files/qemu-efi-arm_2022.02-3ubuntu0.22.04.7_all.deb' 'https://launchpadlibrarian.net/753273806/qemu-efi-arm_0~20191122.bd85bf54-2ubuntu3.6_all.deb'; do
            echo "Downloading $efi_arm32_url"
            curlstatus="$(curl -A "Mozilla/5.0 (X11; Linux x86_64; rv:152.0) Gecko/20100101 Firefox/152.0" -fsSL -o "$qemu_efi_deb" -w "%{http_code}" "$efi_arm32_url")"
            ecode=$?
            if [ "$ecode" != "0" ] || [ "$curlstatus" -ge 400 ] || [ "$curlstatus" = "0" ]; then
                echo "Download failed: ${efi_arm32_url} with http error: ${curlstatus}"
                rm -f "${qemu_efi_deb}"
            else
                break
            fi
        done
        if [ -f "$qemu_efi_deb" ]; then
            echo "Installing qemu-efi-arm"
            7z x "$qemu_efi_deb" -o"$qemu_efi_dir" "data.tar" "data.tar.zst" "data.tar.xz" -aoa -y >/dev/null
            #Handle data.tar.zst
            if [ -f "$qemu_efi_dir/data.tar.zst" ]; then
                cd "$qemu_efi_dir"
                unzstd "$qemu_efi_dir/data.tar.zst"
                cd "$org_pwd"
            fi
            #Handle data.tar.xz
            if [ -f "$qemu_efi_dir/data.tar.xz" ]; then
                7z x "$qemu_efi_dir/data.tar.xz" -o"$qemu_efi_dir" -aoa -y >/dev/null
            fi
            7z x "$qemu_efi_dir/data.tar" -o"$qemu_efi_dir" -aoa -y >/dev/null
            rm -rf -- "$qemu_efi_deb" "$qemu_efi_dir/"data.tar*
            if [ "$alpine" != "true" ]; then
                "$sudo_cmd" cp -rf --preserve=timestamps "$qemu_efi_dir"/* "/"
            else
                "$sudo_cmd" cp -rf "$qemu_efi_dir"/* "/"
            fi
        fi
        rm -rf "$qemu_efi_dir"
    fi

    #Modify the NVRAM to disabled the timeout of 5 seconds option arm and risc-v
    patchNVRAMTimeOut "/usr/share/AAVMF/AAVMF_VARS.fd" "/usr/share/AAVMF/AAVMF_VARS_QH.fd"
    patchNVRAMTimeOut "/usr/share/AAVMF/AAVMF32_VARS.fd" "/usr/share/AAVMF/AAVMF32_VARS_QH.fd"
    if [ -f "/usr/share/edk2/riscv/RISCV_VIRT_VARS.fd" ]; then
        patchNVRAMTimeOut "/usr/share/edk2/riscv/RISCV_VIRT_VARS.fd" "/usr/share/edk2/riscv/RISCV_VIRT_VARS_QH.fd"
        patchNVRAMPADDING "/usr/share/edk2/riscv/RISCV_VIRT_CODE" "/usr/share/edk2/riscv/RISCV_VIRT_VARS" "33554432"
    else
        patchNVRAMTimeOut "/usr/share/qemu-efi-riscv64/RISCV_VIRT_VARS.fd" "/usr/share/qemu-efi-riscv64/RISCV_VIRT_VARS_QH.fd"
        patchNVRAMPADDING "/usr/share/qemu-efi-riscv64/RISCV_VIRT_CODE" "/usr/share/qemu-efi-riscv64/RISCV_VIRT_VARS" "33554432"
    fi
    rm -f "$install_dir/tmp/timeout.json"

    #Cleanup
    "$sudo_cmd" rm -rf "$install_dir/resources/__pycache__"

    #Create the installed dir file
    touch "$HOME/.qemu-helper"
fi

#repair or create qemu-system-ppc64le symlink if it does not exist
if ! command -v qemu-system-ppc64le >/dev/null 2>&1; then
    qemu_system_ppc64="$(command -v qemu-system-ppc64 2>/dev/null)"
    if [ ! -z "$qemu_system_ppc64" ]; then
        dir_ppc64="$(dirname "$qemu_system_ppc64")"
        qppc64le="$dir_ppc64/qemu-system-ppc64le"
        qppc64el="$dir_ppc64/qemu-system-ppc64el"
        echo "Creating qemu-system-ppc64le"
        sudo_script "4"
        if [ -f "$qppc64el" ]; then
            #TODO: check macOS timestamps
            "$sudo_cmd" cp -a "$qppc64el" "$qppc64le" >/dev/null 2>&1
        fi
        if ! command -v qemu-system-ppc64le >/dev/null 2>&1; then
            echo "creating symlink $qppc64le -> qemu-system-ppc64"
            "$sudo_cmd" ln -sfn "qemu-system-ppc64" "$qppc64le"
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
mkdir -p "tmp"
mkdir -p "resources"
#Disables or enables DESKTOP_GEN for all generated boot scripts
DESKTOP_GEN="${DESKTOP_GEN:-true}"
#copy the installation files if not already extracted to the install dir
if [ "$install_dir" != "$current_dir" ]; then
    echo "copying install files"
    mv "$current_dir/iso"/* "$install_dir/iso/" >/dev/null 2>&1
    cp -rf "$current_dir"/*.sh "$install_dir/"
    cp -f "$current_dir/resources"/* "$install_dir/resources/" >/dev/null 2>&1
fi

unzipSetupEXE() {
    if [ -z "${2}" ]; then
        return 0
    fi
    rm -rf "${2}" >/dev/null 2>&1
    mkdir -p "${2}"
    7z e "${1}" -o"$2" "setup.exe" -mtc -mta -mtm -aoa -y -ssc- >/dev/null
    if [ -f "${2}/setup.exe" ]; then
        echo "${2}/setup.exe"
    else
        echo "$(find "${2}" -maxdepth 1 -type f -print | grep -Ei 'setup\.exe')"
    fi
}

getWinBuild() {
    if [ ! -f "$1" ]; then
        echo ""
        return 0
    fi
    setup_exe="$1"
    s_dir="$(dirname "$setup_exe")"
    7z e "${setup_exe}" -o"$s_dir" ".rsrc/version.txt" -mtc -mta -mtm -aoa -y >/dev/null
    for enc in UTF-16 UTF-16LE UTF-16BE WINDOWS-1252 UTF-8; do
        setup_line="$(iconv -f "$enc" -t UTF-8 "$s_dir/version.txt" 2>/dev/null | tr -d '\r' | grep -Ei "^PRODUCTVERSION*" | head -n 1)"
        if [ ! -z "$setup_line" ]; then
            break
        fi
    done
    build="$(printf '%s' "$setup_line" | awk -F',' '{ sub(/^PRODUCTVERSION[[:space:]]*/, ""); print($3) }')"
    echo "$build"
}

#Create a Temp Directory for setup.exe and version.txt
setup_exe_dir="$(mktemp -d tmp/qemu-helper-XXXXXX)"
trap "rm -rf \"$setup_exe_dir\"" 0

#create powerpc32 symlinks
for file in "iso"/*; do
    name=$(basename "$file")
    case "$name" in
        *.[iI][sS][oO]) ;;
        *)  continue ;;
    esac
    ext="${name##*.}"
    ext=".${ext}"
    name="${name%.*}"
    lname="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
    lnk_name="iso/${name}-ppc32${ext}"
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
            oefi="$(7z l -ba "iso/${name}${ext}" | awk 'toupper(substr($1,1,1)) == "D" || toupper(substr($3,1,1)) == "D" { max = (toupper(substr($1,1,1)) != "D" ? 3 : 1); for (i=1; i<=max && i<NF; i++) $i=""; sub(/^[[:space:]]+/, ""); print }' | sed 's|^[^/]|/&|' | grep -vEi '^/(install|boot|efi)[^/]*/e500mc(/|$)' | grep -vEi '^/(install|boot|efi)[^/]*/(powerpc64|ppc64)(-[a-z0-9]+)?(/|$)' | grep -Ei '^/(install|boot|efi)[^/]*/(powerpc|ppc|pmac|chrp)(32)?(-[a-z0-9]+)?(/|$)')"
            if [ ! -z "$oefi" ]; then
                echo "creating symlink: $lnk_name"
                ln -sfn "${name}${ext}" "$lnk_name"
            fi
        fi
    fi
done

#install cows
for file in "iso"/*; do
    name=$(basename "$file")
    case "$name" in
        *.[iI][sS][oO]) ;;
        *)  continue ;;
    esac
    ext="${name##*.}"
    ext=".${ext}"
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
        windows_10="false"
        windows_11="false"
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
            #Detect Alpine Linux & KDE Plasma
            *alpine*|*alps*|*[!a-z]kde[!a-z]*|kde[!a-z]*|*[!a-z]kde|*kubuntu*)
                gpu_3d_fallback="true"
                ;;

            #Detect Microsoft Windows
            *mswin*|*winms*|*window*|*microsoft*)
                windows="true"
                ;;

            #Detect mac
            *darwin*|*osx*|*macos*)
                mac="true"
                ;;

            #Detect Possible Windows MS-DOS FreeDOS
            *server*|*win*|*ms*|*vista*|*dos*|fd*)
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

        #Windows XP and lower compatibility
        if [ "$windows" = "true" ]; then
            case "$lname" in
                #vista already supported
                *nxp*|*wxp*|*sxp*|*[!a-z]xp[!a-z]*|xp[!a-z]*|*[!a-z]xp|2000[!0-9]*|*[!0-9]2000|*[!0-9]2000[!0-9]*)
                    windows_old="true"
                    windows="false"
                    ;;
                *xp*)
                    echo "WARNING: XP in file name using slow method to determine if ${name} is Windows XP"
                    chk_iso="true"
                    windows="false"
                    ;;
                95[!0-9]*|*[!0-9]95|*[!0-9]95[!0-9]*|98[!0-9]*|*[!0-9]98|*[!0-9]98[!0-9]*|*dos*)
                    windows_95="true"
                    windows="false"
                    ;;
                #Check ISO for windows me edition. Covers WinMe,WindowME, WindowsME, Windows-me,Windows-me-pro
                *nme*|*wme*|*sme*|*[!a-z]me[!a-z]*|me[!a-z]*|*[!a-z]me|*millen*|*milen*)
                    chk_iso="true"
                    windows="false"
                    ;;
            esac
        fi

        #Dynamic Detection of windows and kb for linux
        if { [ "$arch" = "arm" ] && [ "$checked" != "true" ]; } || [ "$chk_iso" = "true" ]; then
            chked_iso="false"
            oefi="$(7z l -ba "iso/${name}${ext}" | awk '{ c1 = toupper(substr($1,1,1)); if (c1 == "D" || toupper(substr($3,1,1)) == "D") max = (c1 != "D" ? 3 : 1); else max = (c1 != "." ? 5 : 3); cachedNF = NF; for (i=1; i<=max && i<cachedNF; i++) sub(/^[[:space:]]*[^[:space:]]+/, ""); sub(/^[[:space:]]+/, ""); print }' | sed 's|^[^/]|/&|')"
            #Dynamically Detect Windows
            if [ ! -z "$(printf '%s' "$oefi" | grep -Ei '^/(boot/bcd|bootmgr|bootmgr\.efi|efi/microsoft|uefi/microsoft)(/)?$')" ]; then
                windows="true"
                chked_iso="true"
            fi
            #Dynamically Detect Old Windows MS-DOS FreeDOS
            if { [ "$arch" = "i386" ] || [ "$arch" = "x86_64" ]; } && [ "$chked_iso" != "true" ]; then
                #Detect Windows 95/98/me MS-DOS FreeDOS
                if [ ! -z "$(printf '%s' "$oefi" | grep -Ei '^/(win9|winme|FDOS)[^/]*$|^/(freedos|config\.SYS)$')" ]; then
                    windows_95="true"
                    chked_iso="true"
                fi
                #Dynamically Detect Windows 2000 and Higher
                if [ "$chked_iso" != "true" ] && [ ! -z "$(printf '%s' "$oefi" | grep -Ei '^/([^/]+/[^/]+\.cab)$')" ]; then
                    windows_old="true"
                    chked_iso="true"
                fi
            fi
            #Dynamically Determine if kernal boot needs to be enabled for arm32 images
            if [ "$chked_iso" != "true" ] && [ "$arch" = "arm" ] && [ -z "$(printf '%s' "$oefi" | grep -Ei '^/(EFI|BOOT)(/)?$')" ]; then
                kb="true"
            fi
        fi

        #If windows 95/98/me was detected by name or automatically set requirements
        if [ "$windows_95" = "true" ]; then
            arch="i386"
            bits32="true"
            qram32="500"
            qcore32="cpus=1,sockets=1,cores=1,threads=1"
        fi

        #Windows 10+ Support
        if [ "$windows" = "true" ]; then
            win_build="$(getWinBuild "$(unzipSetupEXE "iso/${name}${ext}" "$setup_exe_dir")")"
            case "$win_build" in
                ''|*[!0-9]*)
                    echo "ERROR win_build is not a number ${win_build} for iso ${name}"
                    win_build=""
                ;;
            esac
            if [ ! -z "$win_build" ]; then
                echo "win build found $win_build ${name}"
                if [ "$win_build" -ge 10240 ] && [ "$win_build" -le 21999 ]; then
                    windows="false"
                    windows_10="true"
                    echo "windows 10 found $name"
                fi
                if [ "$win_build" -ge 22000 ]; then
                    windows="false"
                    windows_11="true"
                    echo "windows 11+ found $name"
                fi
            fi
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
        if [ "$DESKTOP_GEN" != "true" ]; then
            echo "export DESKTOP_GEN=\"false\"" >>"$bootisosh"
            echo "export DESKTOP_GEN=\"false\"" >>"$bootsh"
        fi
        if [ "$DESKTOP_SYNC" = "true" ]; then
            echo "export DESKTOP_SYNC=\"true\"" >>"$bootisosh"
            echo "export DESKTOP_SYNC=\"true\"" >>"$bootsh"
        fi
        if [ "$windows_11" = "true" ]; then
            echo "export windows_11=\"true\"" >>"$bootisosh"
            echo "export windows_11=\"true\"" >>"$bootsh"
            echo "export no_wifi=\"true\"" >>"$bootisosh"
        fi
        if [ "$windows_10" = "true" ]; then
            echo "export windows_10=\"true\"" >>"$bootisosh"
            echo "export windows_10=\"true\"" >>"$bootsh"
            echo "export no_wifi=\"true\"" >>"$bootisosh"
        fi
        if [ "$windows" = "true" ]; then
            echo "export windows=\"true\"" >>"$bootisosh"
            echo "export windows=\"true\"" >>"$bootsh"
        fi
        if [ "$windows_old" = "true" ]; then
            echo "export windows_old=\"true\"" >>"$bootisosh"
            echo "export windows_old=\"true\"" >>"$bootsh"
        fi
        if [ "$windows_95" = "true" ]; then
            echo "export windows_95=\"true\"" >>"$bootisosh"
            echo "export windows_95=\"true\"" >>"$bootsh"
            echo "#Set no_usb=\"false\" to allow usb on windows 95/98/me After you have installed the drivers" >>"$bootisosh"
            echo "#Set no_usb=\"false\" to allow usb on windows 95/98/me After you have installed the drivers" >>"$bootsh"
            echo "export no_usb=\"true\"" >>"$bootisosh"
            echo "export no_usb=\"true\"" >>"$bootsh"
            echo "export q_audio=\"sb16\"" >>"$bootisosh"
            echo "export q_audio=\"sb16\"" >>"$bootsh"
        fi
        echo "exec sh boot.sh \"${name}\" true ${arch} ${qram} ${qcore}" >>"$bootisosh"
        echo "exec sh boot.sh \"${name}\" false ${arch} ${qram} ${qcore}" >>"$bootsh"
        chmod +x "$bootisosh"
        chmod +x "$bootsh"

        #Reset Variables
        qram="$org_qram"
        qcore="$org_qcore"
        qram32="$org_qram32"
        qcore32="$org_qcore32"
    fi
done
