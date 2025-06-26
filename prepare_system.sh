#!/bin/bash

# Exit on any error
set -e

echo "🧹 Preparing system for MT3 installation..."

echo "📦 Updating package lists..."
sudo apt update

echo "🔧 Fixing apt_pkg module issues..."
# Remove any broken symlinks first
sudo rm -f /usr/lib/python3/dist-packages/apt_pkg.so

# Reinstall python3-apt to ensure it's properly installed
sudo apt install --reinstall python3-apt

# Find and create the correct symlink for apt_pkg
APT_PKG_PATH=$(find /usr/lib/python3/dist-packages -name "apt_pkg.cpython-*.so" | head -1)
if [ -n "$APT_PKG_PATH" ]; then
    sudo ln -sf "$APT_PKG_PATH" /usr/lib/python3/dist-packages/apt_pkg.so
    echo "✅ Created symlink: $APT_PKG_PATH -> /usr/lib/python3/dist-packages/apt_pkg.so"
else
    echo "⚠️  Warning: Could not find apt_pkg.cpython-*.so file"
fi

echo "🐍 Checking current Python setup..."
echo "Current python3 version: $(python3 --version)"
echo "Current python version: $(python --version 2>/dev/null || echo 'Not set')"

echo "🔄 Resetting Python alternatives to system default..."
# Remove any custom Python alternatives
sudo update-alternatives --remove-all python3 2>/dev/null || true
sudo update-alternatives --remove-all python 2>/dev/null || true

# Install system Python alternatives
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 2>/dev/null || true
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 2 2>/dev/null || true
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 3 2>/dev/null || true

echo "🧪 Testing apt functionality..."
# Test if apt works properly now
if sudo apt list --upgradable >/dev/null 2>&1; then
    echo "✅ apt is working correctly"
else
    echo "❌ apt is still having issues"
    echo "Trying additional fixes..."

    # Additional fix: update alternatives for python3-apt
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
    sudo apt install --reinstall python3-apt
fi

echo "📋 Installing essential packages..."
sudo apt install -y \
    software-properties-common \
    build-essential \
    git \
    curl \
    wget \
    unzip \
    pkg-config

echo "🐍 Adding deadsnakes PPA for Python 3.10..."
sudo add-apt-repository ppa:deadsnakes/ppa -y

echo "📦 Updating package lists again..."
sudo apt update

echo "✅ System preparation complete!"
echo ""
echo "🎯 Next steps:"
echo "1. Run the MT3 installation script: sudo bash install_mt3.sh"
echo "2. If you encounter any issues, run this preparation script again"
echo ""
echo "🔍 Current Python setup:"
echo "python3: $(python3 --version)"
echo "python: $(python --version 2>/dev/null || echo 'Not set')"
