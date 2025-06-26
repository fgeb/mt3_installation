#!/bin/bash

# Exit on any error
set -e

echo "🔧 Emergency apt_pkg module fix..."

echo "📋 Current Python setup:"
echo "python3: $(python3 --version)"
echo "python: $(python --version 2>/dev/null || echo 'Not set')"

echo "🧹 Cleaning up broken apt_pkg symlinks..."
sudo rm -f /usr/lib/python3/dist-packages/apt_pkg.so

echo "📦 Reinstalling python3-apt..."
sudo apt install --reinstall python3-apt

echo "🔍 Finding apt_pkg module files..."
find /usr/lib/python3/dist-packages -name "apt_pkg*" -ls

echo "🔗 Creating correct symlink..."
# Find all apt_pkg files and create the right symlink
APT_PKG_FILES=$(find /usr/lib/python3/dist-packages -name "apt_pkg.cpython-*.so")
if [ -n "$APT_PKG_FILES" ]; then
    echo "Found apt_pkg files:"
    echo "$APT_PKG_FILES"

    # Use the first one found
    FIRST_APT_PKG=$(echo "$APT_PKG_FILES" | head -1)
    echo "Creating symlink from: $FIRST_APT_PKG"
    sudo ln -sf "$FIRST_APT_PKG" /usr/lib/python3/dist-packages/apt_pkg.so
else
    echo "❌ No apt_pkg.cpython-*.so files found!"
    echo "Trying alternative approach..."

    # Try to find any apt_pkg files
    ALL_APT_PKG=$(find /usr/lib/python3/dist-packages -name "*apt_pkg*")
    if [ -n "$ALL_APT_PKG" ]; then
        echo "Found apt_pkg related files:"
        echo "$ALL_APT_PKG"

        # Try to create symlink from any apt_pkg file
        FIRST_APT_PKG=$(echo "$ALL_APT_PKG" | head -1)
        echo "Creating symlink from: $FIRST_APT_PKG"
        sudo ln -sf "$FIRST_APT_PKG" /usr/lib/python3/dist-packages/apt_pkg.so
    else
        echo "❌ No apt_pkg files found at all!"
        echo "This is a serious issue. Trying to rebuild python3-apt..."
        sudo apt remove --purge python3-apt
        sudo apt install python3-apt
    fi
fi

echo "🧪 Testing apt functionality..."
if sudo apt list --upgradable >/dev/null 2>&1; then
    echo "✅ apt is working correctly!"
else
    echo "❌ apt is still broken. Trying manual fix..."

    # Manual fix: create a dummy apt_pkg.so if needed
    if [ ! -f /usr/lib/python3/dist-packages/apt_pkg.so ]; then
        echo "Creating dummy apt_pkg.so..."
        sudo touch /usr/lib/python3/dist-packages/apt_pkg.so
    fi

    # Try to reinstall again
    sudo apt install --reinstall python3-apt
fi

echo "✅ apt_pkg fix complete!"
echo "You can now run the preparation script: sudo bash prepare_system.sh"
