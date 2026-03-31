#!/bin/zsh

# build.sh - Build script for FlaschenTaschen Swift package

set -e

SCRIPT_DIR="$(cd "$(dirname "${ARGV0:A}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"

usage() {
    echo "Usage: build.sh <action> [action] ..."
    echo ""
    echo "Actions:"
    echo "  clean    Remove build artifacts"
    echo "  build    Build all targets with debug symbols"
    echo "  release  Build all targets optimized"
    echo "  test     Run tests"
    echo ""
    echo "Examples:"
    echo "  build.sh build"
    echo "  build.sh clean build"
    echo "  build.sh clean build test"
    exit 1
}

if [[ $# -eq 0 ]]; then
    usage
fi

list_products() {
    echo "Products to build:"
    echo "  Libraries:"
    echo "    • FlaschenTaschenClientKit"
    echo "    • FlaschenTaschenDemoKit"
    echo "  Clients:"
    echo "    • send-text, send-image, send-video"
    echo "  Tools:"
    echo "    • ft-detect, ft-debugger"
    echo "  Demos: simple-example, simple-animation, black, random-dots, plasma,"
    echo "         matrix, blur, quilt, firefly, depth, life, fractal, sierpinski,"
    echo "         maze, lines, hack, words, nb-logo, sf-logo, midi, kbd2midi"
}

run_action() {
    local action=$1
    case "$action" in
        clean)
            echo "🧹 Cleaning build directory..."
            rm -rf "$BUILD_DIR"
            echo "✓ Clean complete"
            ;;

        build)
            echo "🔨 Building all targets (debug)..."
            list_products
            echo ""
            swift build
            echo "✓ Build complete"
            echo "  Binaries: $BUILD_DIR/debug/"
            ;;

        release)
            echo "🚀 Building all targets (release)..."
            list_products
            echo ""
            swift build -c release
            echo "✓ Release build complete"
            echo "  Binaries: $BUILD_DIR/release/"
            ;;

        test)
            echo "🧪 Running tests..."
            swift test
            echo "✓ Tests passed"
            ;;

        *)
            echo "Error: Unknown action '$action'"
            usage
            ;;
    esac
}

# Run each action in sequence
for action in "$@"; do
    run_action "$action"
done
