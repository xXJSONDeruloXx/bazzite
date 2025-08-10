# vim: set ft=make :

# Manage Proton GE versions
proton-ge VERSION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh

    GEREPO_API="https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases"
    COMPAT_DIR="$HOME/.steam/root/compatibilitytools.d"
    mkdir -p "$COMPAT_DIR"

    get_installed() {
        ls -1 "$COMPAT_DIR" 2>/dev/null | grep -E '^GE-Proton' || true
    }

    get_available() {
        curl -s "$GEREPO_API" | jq -r '.[].tag_name' | grep -E '^GE-Proton'
    }

    install_version() {
        local ver="$1"
        local url
        url=$(curl -s "$GEREPO_API" | jq -r '.[] | select(.tag_name=="'"$ver"'") | .assets[] | select(.name | endswith(".tar.gz")) | .browser_download_url')
        if [[ -z "$url" ]]; then
            echo "Version $ver not found."
            return 1
        fi
        echo "Downloading $ver..."
        curl -L "$url" | tar -xz -C "$COMPAT_DIR"
        echo "$ver installed in $COMPAT_DIR."
    }

    remove_version() {
        local ver="$1"
        rm -rf "$COMPAT_DIR/$ver"
        echo "$ver removed from $COMPAT_DIR."
    }

    if [[ "{{ VERSION }}" == "help" ]]; then
        echo "Usage: ujust proton-ge [version|latest]"
        exit 0
    elif [[ -n "{{ VERSION }}" ]]; then
        if [[ "{{ VERSION }}" == "latest" ]]; then
            ver=$(get_available | head -n1)
        else
            ver="{{ VERSION }}"
        fi
        install_version "$ver"
        exit $?
    fi

    while true; do
        OPTION=$(ugum choose \
            "Install Latest" \
            "Install Specific Version" \
            "Remove Installed Version" \
            "List Installed Versions" \
            "Exit")
        case "$OPTION" in
            "Install Latest")
                ver=$(get_available | head -n1)
                install_version "$ver"
                ;;
            "Install Specific Version")
                mapfile -t versions < <(get_available)
                ver=$(ugum choose "${versions[@]}")
                [[ -n "$ver" ]] && install_version "$ver"
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
            "Exit")
                break
                ;;
            *)
                echo "Invalid choice."
                ;;
        esac
    done
