iso="${1}"
if [ -z "$iso" ]; then
	read -p "Enter Linux ISO:" iso
	iso="$(printf '%s' "$iso" | sed 's/^["'\'']//; s/["'\'']$//')"
fi
results="$(7z l -ba "${iso}" | awk 'substr($3,1,1) != "D" { sub(/^([^ ]+ +){5}/, "") ; print }' | sed 's|^[^/]|/&|' | grep -Ei '^(/[^/]+){0,4}/(hwe-)?(vmlinuz|zImage|uImage|bzImage|Image|linux|vmlinux|kernel|kernal|initrd|uInitrd|initramfs|initramfs-linux)(\.ubuntu)?(-rt|-cloud|-virt|-vm|-generic|-lts|-hwe){0,7}(\.gz|\.lz|\.img|\.tar\.gz|\.cpio\.gz)?$')"
results_sorted="$(printf '%s' "$results" | awk -F/ '{ print NF-1, $0 }' | sort -n -k1,1 -k2,2 | sed 's|^[^/]*/||')"
vmlinuz_path="$(printf '%s' "$results_sorted" | grep -Ei '(hwe-)?(vmlinuz|zImage|uImage|bzImage|Image|linux|vmlinux|kernel|kernal)(\.ubuntu)?(-rt|-cloud|-virt|-vm|-generic|-lts|-hwe){0,7}(\.gz|\.lz|\.img|\.tar\.gz|\.cpio\.gz)?$')"
initrd_path="$(printf '%s' "$results_sorted" | grep -Ei '(hwe-)?(initrd|uInitrd|initramfs|initramfs-linux)(\.ubuntu)?(-rt|-cloud|-virt|-vm|-generic|-lts|-hwe){0,7}(\.gz|\.lz|\.img|\.tar\.gz|\.cpio\.gz)?$')"
echo "kernals:"
echo "$vmlinuz_path"
echo "initrd:"
echo "$initrd_path"