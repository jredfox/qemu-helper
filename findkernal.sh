iso="${1}"
if [ -z "$iso" ];
	read -p "Enter Linux ISO:"
fi
results="$(7z l -ba "${iso}" | awk 'substr($3,1,1) != "D" { sub(/^([^ ]+ +){5}/, "") ; print }' | sed 's|^[^/]|/&|' | grep -Ei '^(/[^/]+){0,4}/(hwe-)?(vmlinuz|zImage|uImage|Image|linux|vmlinux|initrd|uInitrd|initramfs|initramfs-linux)(-lts)?(\.gz|\.lz|\.img|\.tar\.gz|\.cpio\.gz)?$' | sed 's|^/||')"
results_sorted="$(printf '%s' "$results" | awk '{print length, $0}' | sort -n | cut -d' ' -f2-)"
vmlinuz_path="$(printf '%s' "$results_sorted" | grep -Ei '(hwe-)?(vmlinuz|zImage|uImage|Image|linux|vmlinux)(-lts)?(\.gz|\.lz|\.img|\.tar\.gz|\.cpio\.gz)?$')"
initrd_path="$(printf '%s' "$results_sorted" | grep -Ei '(hwe-)?(initrd|uInitrd|initramfs|initramfs-linux)(-lts)?(\.gz|\.lz|\.img|\.tar\.gz|\.cpio\.gz)?$')"
echo "kernals:"
echo "$vmlinuz_path"
echo "initrd:"
echo "$initrd_path"