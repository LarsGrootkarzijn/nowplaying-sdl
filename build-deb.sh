#!/bin/bash
set -e

PACKAGE="nowplaying-sdl"

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
SRC_DIR="$SCRIPT_DIR"

# Parse version from debian/changelog
VERSION=$(dpkg-parsechangelog -S Version)
if [[ -z "$VERSION" ]]; then
    echo "ERROR: Could not parse version from debian/changelog"
    exit 1
fi
echo "Package version: $VERSION"

# Check for DIST environment variable
if [[ -n "$DIST" ]]; then
    echo "Using distribution from DIST environment variable: $DIST"
    CHROOT="${DIST}-amd64-sbuild"
    DIST_ARG="--dist=$DIST"
    CHROOT_ARG="--chroot=$CHROOT"
else
    DIST_ARG=""
    CHROOT_ARG=""
fi

BUILD_DIR="/tmp/${PACKAGE}-build"

# Clean function
clean() {
    echo "Cleaning previous build artifacts..."
    debian/rules clean || true
    rm -rf "$BUILD_DIR"
    rm -f ${PACKAGE}_*.deb ${PACKAGE}_*.changes ${PACKAGE}_*.buildinfo 2>/dev/null
    echo "Cleanup completed."
}

if [[ "$1" == "--clean" ]]; then
    clean
    exit 0
fi

# Prepare build directory
echo "Preparing build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cp -r "$SRC_DIR/"* "$BUILD_DIR/"
cd "$BUILD_DIR"

# Ensure sbuild is installed
if ! command -v sbuild &> /dev/null; then
    echo "Error: sbuild not found. Install it with:"
    echo "  sudo apt-get install sbuild build-essential debhelper dh-python python3-all python3-setuptools"
    exit 1
fi

# Ensure python3-sdl2 is installed
if ! dpkg -l python3-sdl2 &> /dev/null; then
    echo "Installing python3-sdl2..."
    sudo apt-get install -y python3-sdl2
fi

# Build package with sbuild
echo "Building package with sbuild..."
sbuild \
    --chroot-mode=unshare \
    --no-clean-source \
    --enable-network \
    $DIST_ARG \
    $CHROOT_ARG \
    --build-dir="$BUILD_DIR" \
    --verbose

# Move artifacts back
echo "Moving build artifacts..."
mv *.deb "$SCRIPT_DIR/" 2>/dev/null || true
mv *.changes "$SCRIPT_DIR/" 2>/dev/null || true
mv *.buildinfo "$SCRIPT_DIR/" 2>/dev/null || true

echo "Debian package build completed."
echo "Built packages:"
ls -la "$SCRIPT_DIR"/*.deb 2>/dev/null || echo "No packages found"

echo ""
echo "To install the package:"
echo "  sudo dpkg -i ${PACKAGE}_${VERSION}_all.deb"
echo "If dependencies are missing:"
echo "  sudo apt-get install -f"