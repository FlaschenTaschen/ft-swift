#!/bin/zsh

# install.sh - Install FlaschenTaschen release binaries to a specified location

set -e

SCRIPT_DIR="$(cd "$(dirname "${ARGV0:A}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"

if [[ $# -ne 1 ]]; then
    echo "Usage: install.sh <destination-path>"
    echo ""
    echo "Installs release binaries to the specified directory."
    echo ""
    echo "Examples:"
    echo "  install.sh /usr/local/bin"
    echo "  install.sh ~/.local/bin"
    exit 1
fi

DEST="$1"
RELEASE_DIR="$BUILD_DIR/release"

if [[ ! -d "$RELEASE_DIR" ]]; then
    echo "Error: Release build not found at $RELEASE_DIR"
    echo "Please run './build.sh release' first."
    exit 1
fi

PRODUCTS=(
    send-text send-image send-video ft-detect ft-debugger
    simple-example simple-animation black random-dots plasma
    matrix blur quilt firefly depth grayscale life fractal
    sierpinski maze lines hack words nb-logo sf-logo midi kbd2midi
)

mkdir -p "$DEST"
echo "📦 Installing binaries to $DEST..."
for product in "${PRODUCTS[@]}"; do
    bin="$RELEASE_DIR/$product"
    if [[ -f "$bin" && -x "$bin" ]]; then
        install -m 755 "$bin" "$DEST/$product"
        echo "  ✓ $product"
    else
        echo "  ⚠ $product not found, skipping"
    fi
done
echo "✓ Install complete"
