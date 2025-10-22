#!/bin/sh
set -u
set -e

TUIC_REPO="tuic-protocol/tuic"
HY2_REPO="apernet/hysteria"
TUIC_VERSION="latest"
HY2_VERSION="latest"
PREFIX="/usr/local/bin"
CONFIG_ROOT="/etc"
KEEP_ARCHIVE="false"

usage() {
    cat <<'EOF'
Usage: install-tuic-hy2.sh [options]

Options:
  --tuic-version <tag>   Install the specified TUIC server release tag (default: latest)
  --hy2-version <tag>    Install the specified Hysteria 2 release tag (default: latest)
  --prefix <dir>         Installation directory for binaries (default: /usr/local/bin)
  --config-root <dir>    Root directory for configuration files (default: /etc)
  --keep-archive         Keep downloaded archives in /tmp for inspection
  -h, --help             Show this help message and exit

The script detects the container architecture automatically and
downloads the matching musl (Alpine) compatible builds when available.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --tuic-version)
            shift || { echo "Missing value for --tuic-version" >&2; exit 1; }
            TUIC_VERSION="$1"
            ;;
        --hy2-version)
            shift || { echo "Missing value for --hy2-version" >&2; exit 1; }
            HY2_VERSION="$1"
            ;;
        --prefix)
            shift || { echo "Missing value for --prefix" >&2; exit 1; }
            PREFIX="$1"
            ;;
        --config-root)
            shift || { echo "Missing value for --config-root" >&2; exit 1; }
            CONFIG_ROOT="$1"
            ;;
        --keep-archive)
            KEEP_ARCHIVE="true"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
    shift
done

ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64)
        TUIC_ASSET_PATTERN='x86_64-unknown-linux-musl$'
        HY2_ASSET_PATTERN='linux-amd64$'
        ;;
    aarch64|arm64)
        TUIC_ASSET_PATTERN='aarch64-unknown-linux-musl$'
        HY2_ASSET_PATTERN='linux-arm64$'
        ;;
    armv7l|armv7)
        TUIC_ASSET_PATTERN='armv7-unknown-linux-musleabihf$'
        HY2_ASSET_PATTERN='linux-arm$'
        ;;
    *)
        echo "Unsupported architecture: $ARCH" >&2
        exit 1
        ;;
esac

mkdir -p "$PREFIX"
mkdir -p "$CONFIG_ROOT/tuic" "$CONFIG_ROOT/hysteria"

fetch_release_json() {
    repo="$1"
    version="$2"
    if [ "$version" = "latest" ]; then
        url="https://api.github.com/repos/$repo/releases/latest"
    else
        url="https://api.github.com/repos/$repo/releases/tags/$version"
    fi
    curl -fsSL "$url"
}

select_asset_url() {
    json_input="$1"
    pattern="$2"
    jq -r --arg pattern "$pattern" '[.assets[] | select(.name | test($pattern)) | .browser_download_url][0]' <<EOF
$json_input
EOF
}

select_asset_name() {
    json_input="$1"
    pattern="$2"
    jq -r --arg pattern "$pattern" '[.assets[] | select(.name | test($pattern)) | .name][0]' <<EOF
$json_input
EOF
}

download_and_install() {
    repo="$1"
    version="$2"
    pattern="$3"
    destination_name="$4"

    release_json=$(fetch_release_json "$repo" "$version")
    asset_url=$(select_asset_url "$release_json" "$pattern")
    asset_name=$(select_asset_name "$release_json" "$pattern")

    if [ -z "$asset_url" ] || [ "$asset_url" = "null" ]; then
        echo "Unable to locate asset matching pattern '$pattern' for $repo $version" >&2
        exit 1
    fi

    tmp_dir=$(mktemp -d)
    if [ "$KEEP_ARCHIVE" != "true" ]; then
        trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
    fi

    echo "Downloading $asset_name ..."
    curl -fsSL "$asset_url" -o "$tmp_dir/$asset_name"
    chmod +x "$tmp_dir/$asset_name"

    install -Dm755 "$tmp_dir/$asset_name" "$PREFIX/$destination_name"

    if [ "$KEEP_ARCHIVE" != "true" ]; then
        rm -rf "$tmp_dir"
        trap - EXIT HUP INT TERM
    else
        echo "Download retained at $tmp_dir/$asset_name"
    fi

    echo "Installed $destination_name to $PREFIX/$destination_name"
}

# Install TUIC server
if command -v tuic-server >/dev/null 2>&1; then
    echo "tuic-server already present at $(command -v tuic-server), overwriting..."
fi
download_and_install "$TUIC_REPO" "$TUIC_VERSION" "$TUIC_ASSET_PATTERN" "tuic-server"

# Install Hysteria 2 (hy2)
if command -v hysteria >/dev/null 2>&1; then
    echo "hysteria already present at $(command -v hysteria), overwriting..."
fi
download_and_install "$HY2_REPO" "$HY2_VERSION" "$HY2_ASSET_PATTERN" "hysteria"

echo "\nInstallation complete."
echo "Configuration directories:"
echo "  TUIC:      $CONFIG_ROOT/tuic"
echo "  Hysteria2: $CONFIG_ROOT/hysteria"
echo "Place your configuration files in these directories and start the services manually."
