unzipSetupEXE() {
	7z e "${1}" -o"$2" "setup.exe" -mtc -mta -mtm -aoa -y >/dev/null
	echo "${2}/setup.exe"
}

getWinBuild() {
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
setup_exe_dir="$(mktemp -d /tmp/getWinBuild-XXXXXX)"
trap "rm -rf $setup_exe_dir" 0

win_build="$(getWinBuild "$(unzipSetupEXE "$1" "$setup_exe_dir")")"
echo "$win_build"