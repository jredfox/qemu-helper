#!/bin/sh

try_decompress()
{

	#Kernal is already decompressed do nothing
	if [ "$isDecompressed" = "true" ]; then
		return 1
	fi

	# The obscure use of the "tr" filter is to work around older versions of
	# "grep" that report the byte offset of the line instead of the pattern.

	# Try to find the header ($1) and decompress from here
	for	pos in `tr "$1\n$2" "\n$2=" < "$img" | grep -abo "^$2"`
	do
		pos=${pos%%:*}
		tail -c+$pos "$img" | $3 > "$img_tmp" 2> /dev/null
		if file "$img_tmp" | grep -q 'Linux kernel.*boot executable' ||
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

# Check invocation:
extract_vmlinux() {

	img="$1"
	img_out="$2"
	if [ -z "$img" ]; then
		echo "extract-vmlinux.sh <kernal> <kernal_extracted>"
		return 1
	fi
	if [ -z "$img_out" ]; then
		img_out="$img"
	fi
	img="$1"
	img_out="${2:-$1}"
	img_tmp="${img_out}.vmlinux"
	mkdir -p "$(dirname "$img_out")"

	# Comment out gzip as qemu already properly handles
	isDecompressed="false"
	try_decompress '\037\213\010' xy    gunzip
	try_decompress '\3757zXZ\000' abcde unxz
	try_decompress 'BZh'          xy    bunzip2
	try_decompress '\135\0\0\0'   xxx   unlzma
	try_decompress '\211\114\132' xy    'lzop -d'
	try_decompress '\002!L\030'   xxx   'lz4 -d'
	try_decompress '(\265/\375'   xxx   unzstd

	if [ "$isDecompressed" != "true" ]; then
		echo "Vmlinux cannot be found! Has it already been decompressed?" >&2
		return 1
	fi

	return 0

}


extract_vmlinux "$1" "$2"
exit $?