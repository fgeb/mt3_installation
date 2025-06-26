#!/bin/bash

# Exit on any error
set -e

echo "🧹 MT3 Cleanup Script"
echo "===================="

echo ""
echo "📁 Removing MT3 installation directory..."
if [ -d ~/mt3_setup ]; then
    rm -rf ~/mt3_setup
    echo "✅ Removed ~/mt3_setup"
else
    echo "ℹ️  ~/mt3_setup directory not found"
fi

echo ""
echo "🐍 Removing any MT3 virtual environments..."
find ~ -name "mt3-*" -type d 2>/dev/null | while read dir; do
    if [[ "$dir" == *"venv"* ]] || [[ "$dir" == *"mt3"* ]]; then
        echo "Removing: $dir"
        rm -rf "$dir"
    fi
done

echo ""
echo "📦 Cleaning up any downloaded files..."
if [ -f ~/mt3_setup/google-cloud-cli-474.0.0-linux-x86_64.tar.gz ]; then
    rm -f ~/mt3_setup/google-cloud-cli-474.0.0-linux-x86_64.tar.gz
    echo "✅ Removed Google Cloud CLI download"
fi

echo ""
echo "🔧 Fixing apt_pkg module issue..."
sudo rm -f /usr/lib/python3/dist-packages/apt_pkg.so
sudo apt install --reinstall python3-apt

# Find and create the correct symlink
APT_PKG_PATH=$(find /usr/lib/python3/dist-packages -name "apt_pkg.cpython-*.so" | head -1)
if [ -n "$APT_PKG_PATH" ]; then
    sudo ln -sf "$APT_PKG_PATH" /usr/lib/python3/dist-packages/apt_pkg.so
    echo "✅ Fixed apt_pkg symlink: $APT_PKG_PATH"
else
    echo "⚠️  Could not find apt_pkg.cpython-*.so file"
fi

echo ""
echo "🧪 Testing apt functionality..."
if sudo apt list --upgradable >/dev/null 2>&1; then
    echo "✅ apt is working correctly"
else
    echo "❌ apt is still having issues"
fi

echo ""
echo "🎯 Cleanup complete!"
echo "==================="
echo ""
echo "Your system is now ready for a clean MT3 installation."
echo "Run: sudo bash install_mt3_minimal.sh"
