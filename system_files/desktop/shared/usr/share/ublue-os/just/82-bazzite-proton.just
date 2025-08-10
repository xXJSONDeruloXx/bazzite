# vim: set ft=make :

# Manage custom Proton forks
proton FORK="" VERSION="":
	#!/usr/bin/bash
	source /usr/lib/ujust/ujust.sh
	
	declare -A FORK_REPOS=(
	[ge]="GloriousEggroll/proton-ge-custom"
	[cachyos]="CachyOS/Proton"
	[experimental]="ValveSoftware/Proton"
	)
	
	declare -A FORK_PREFIX=(
	[ge]="^GE-Proton"
	[cachyos]="."
	[experimental]="^experimental"
	)
	
	declare -A FORK_LABEL=(
	[ge]="Proton GE"
	[cachyos]="CachyOS Proton"
	[experimental]="Proton Experimental"
	)
	
	COMPAT_DIR="$HOME/.steam/root/compatibilitytools.d"
	mkdir -p "$COMPAT_DIR"
	
	choose_fork() {
	local choice=$(ugum choose "${FORK_LABEL[@]}" "Exit")
	if [[ "$choice" == "Exit" || -z "$choice" ]]; then
	exit 0
	fi
	for key in "${!FORK_LABEL[@]}"; do
	if [[ "${FORK_LABEL[$key]}" == "$choice" ]]; then
	echo "$key"
	return
	fi
	done
	}
	
	get_installed() {
	ls -1 "$COMPAT_DIR" 2>/dev/null || true
	}
	
	get_available() {
	local fork=$1
	local repo=${FORK_REPOS[$fork]}
	local prefix=${FORK_PREFIX[$fork]}
	curl -s "https://api.github.com/repos/$repo/releases" | jq -r '.[].tag_name' | grep -E "$prefix"
	}
	
	install_version() {
	local fork=$1
	local ver=$2
	local repo=${FORK_REPOS[$fork]}
	local url
	url=$(curl -s "https://api.github.com/repos/$repo/releases" | jq -r '.[] | select(.tag_name=="'"$ver"'") | .assets[] | select(.name | endswith(".tar.gz") or endswith(".tar.xz") or endswith(".tar.zst")) | .browser_download_url' | head -n1)
	if [[ -z "$url" ]]; then
	echo "Version $ver not found for $fork."
	return 1
	fi
	echo "Downloading $ver..."
	curl -L "$url" | tar -x -C "$COMPAT_DIR"
	echo "$ver installed in $COMPAT_DIR."
	}
	
	remove_version() {
	local ver=$1
	rm -rf "$COMPAT_DIR/$ver"
	echo "$ver removed from $COMPAT_DIR."
	}
	
	usage() {
	echo "Usage: ujust proton [fork] [version|latest]"
	echo "Available forks:"
	for key in "${!FORK_LABEL[@]}"; do
	echo "  $key - ${FORK_LABEL[$key]}"
	done
	}
	
	if [[ "{{ FORK }}" == "help" || "{{ VERSION }}" == "help" ]]; then
	usage
	exit 0
	fi
	
	fork="{{ FORK }}"
	ver="{{ VERSION }}"
	
	if [[ -n "$fork" && -n "$ver" ]]; then
	[[ "$ver" == "latest" ]] && ver=$(get_available "$fork" | head -n1)
	install_version "$fork" "$ver"
	exit $?
	fi
	
	if [[ -z "$fork" ]]; then
	fork=$(choose_fork)
	fi
	
	while true; do
	OPTION=$(ugum choose "Install Latest" "Install Specific Version" "Remove Installed Version" "List Installed Versions" "Switch Fork" "Exit")
	case "$OPTION" in
	"Install Latest")
	ver=$(get_available "$fork" | head -n1)
	install_version "$fork" "$ver"
	;;
	"Install Specific Version")
	mapfile -t versions < <(get_available "$fork")
	ver=$(ugum choose "${versions[@]}")
	[[ -n "$ver" ]] && install_version "$fork" "$ver"
	;;
	"Remove Installed Version")
	mapfile -t installed < <(get_installed)
	if [[ ${#installed[@]} -eq 0 ]]; then
	echo "No installed versions found."
	else
	ver=$(ugum choose "${installed[@]}")
	[[ -n "$ver" ]] && remove_version "$ver"
	fi
	;;
	"List Installed Versions")
	inst=$(get_installed)
	if [[ -z "$inst" ]]; then
	echo "No installed versions found."
	else
	echo "$inst"
	fi
	;;
	"Switch Fork")
	fork=$(choose_fork)
	;;
	"Exit")
	break
	;;
	*)
	echo "Invalid choice."
	;;
	esac
	done
