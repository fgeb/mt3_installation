#!/bin/bash

# Exit on any error
set -e

echo "🚀 Safe MT3 Installation Script"
echo "==============================="

# Step 1: Fix apt_pkg module issue
echo ""
echo "🔧 Step 1: Fixing apt_pkg module issue..."
sudo rm -f /usr/lib/python3/dist-packages/apt_pkg.so
sudo apt install --reinstall python3-apt

# Find and create the correct symlink
APT_PKG_PATH=$(find /usr/lib/python3/dist-packages -name "apt_pkg.cpython-*.so" | head -1)
if [ -n "$APT_PKG_PATH" ]; then
    sudo ln -sf "$APT_PKG_PATH" /usr/lib/python3/dist-packages/apt_pkg.so
    echo "✅ Created symlink: $APT_PKG_PATH -> /usr/lib/python3/dist-packages/apt_pkg.so"
else
    echo "⚠️  Warning: Could not find apt_pkg.cpython-*.so file"
fi

# Step 2: Check current Python versions
echo ""
echo "🐍 Step 2: Checking available Python versions..."
echo "Current python3 version: $(python3 --version)"
echo "Available Python versions:"
ls /usr/bin/python* | grep -E "python[0-9](\.[0-9]+)?$" || echo "No additional Python versions found"

# Step 3: Try to add deadsnakes PPA safely
echo ""
echo "🐍 Step 3: Adding Python 3.10 repository (safe method)..."
if ! sudo add-apt-repository ppa:deadsnakes/ppa -y; then
    echo "⚠️  add-apt-repository failed, trying manual method..."

    # Manual method to add the PPA
    echo "deb http://ppa.launchpad.net/deadsnakes/ppa/ubuntu $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/deadsnakes-ppa.list
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys F23C5A6CF475977595C89F51BA6932366A755776
fi

# Step 4: Update package lists
echo ""
echo "📦 Step 4: Updating package lists..."
sudo apt update

# Step 5: Check if Python 3.10 is available
echo ""
echo "🔍 Step 5: Checking Python 3.10 availability..."
if apt list python3.10 2>/dev/null | grep -q "python3.10"; then
    echo "✅ Python 3.10 is available"
    PYTHON_AVAILABLE=true
else
    echo "❌ Python 3.10 not available, checking system Python versions..."
    PYTHON_AVAILABLE=false

    # Check what Python versions are available
    SYSTEM_PYTHON_VERSIONS=$(apt list --installed | grep "python3\." | grep -E "python3\.[0-9]+$" | cut -d'/' -f1 | sort -V)
    if [ -n "$SYSTEM_PYTHON_VERSIONS" ]; then
        echo "Available system Python versions:"
        echo "$SYSTEM_PYTHON_VERSIONS"

        # Use the highest available Python version
        HIGHEST_PYTHON=$(echo "$SYSTEM_PYTHON_VERSIONS" | tail -1)
        echo "Will use: $HIGHEST_PYTHON"
    else
        echo "No additional Python versions found, will use system Python 3"
    fi
fi

# Step 6: Install system dependencies
echo ""
echo "📋 Step 6: Installing system dependencies..."
sudo apt install -y \
    software-properties-common \
    build-essential \
    git \
    curl \
    wget \
    unzip \
    pkg-config \
    sox \
    ffmpeg \
    libsndfile1 \
    gcc \
    libffi-dev \
    libssl-dev \
    zip \
    g++

# Step 7: Install Python and dependencies
echo ""
echo "🐍 Step 7: Installing Python and dependencies..."
if [ "$PYTHON_AVAILABLE" = true ]; then
    echo "Installing Python 3.10..."
    sudo apt install -y \
        python3.10 \
        python3.10-venv \
        python3.10-dev \
        python3-apt
    PYTHON_CMD="python3.10"
else
    echo "Using system Python..."
    sudo apt install -y \
        python3-venv \
        python3-dev \
        python3-apt
    PYTHON_CMD="python3"
fi

# Step 8: Create project directory and clone MT3
echo ""
echo "📁 Step 8: Setting up MT3 project..."
mkdir -p ~/mt3_setup && cd ~/mt3_setup
git clone https://github.com/magenta/mt3.git
cd mt3

# Step 9: Create virtual environment
echo ""
echo "🐍 Step 9: Creating virtual environment..."
$PYTHON_CMD -m venv mt3-venv
source mt3-venv/bin/activate

# Step 10: Install Python dependencies
echo ""
echo "📦 Step 10: Installing Python dependencies..."
pip install --upgrade pip
pip install --upgrade setuptools wheel

echo "Installing MT3..."
pip install -e .

# Install TensorFlow
echo ""
echo "🤖 Step 11: Installing TensorFlow..."
pip install tensorflow==2.11.0

# Install additional dependencies
echo ""
echo "📚 Step 12: Installing additional dependencies..."
pip install gin-config t5x note-seq

# Step 13: Install Google Cloud SDK
echo ""
echo "☁️ Step 13: Installing Google Cloud SDK..."
cd ~/mt3_setup
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-474.0.0-linux-x86_64.tar.gz
tar -xf google-cloud-cli-474.0.0-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh --quiet

# Add to PATH for current shell
source ./google-cloud-sdk/path.bash.inc

# Step 14: Download MT3 checkpoints
echo ""
echo "📥 Step 14: Downloading MT3 checkpoints..."
mkdir -p checkpoints
cd checkpoints
gsutil -m cp -r gs://mt3/checkpoints/ismir2021 .
cd ..

echo ""
echo "🎉 Installation complete!"
echo "========================"
echo ""
echo "Python version used: $($PYTHON_CMD --version)"
echo ""
echo "To activate your MT3 environment in the future, run:"
echo "  source ~/mt3_setup/mt3/mt3-venv/bin/activate"
echo ""
echo "To test the installation, run:"
echo "  source ~/mt3_setup/mt3/mt3-venv/bin/activate"
echo "  cd ~/mt3_setup/mt3"
echo "  python -c \"import mt3; print('MT3 imported successfully!')\""
