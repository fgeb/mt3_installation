#!/bin/bash

# Exit on any error
set -e

echo "🚀 MT3 Installation Script"
echo "=========================="

# Get the correct home directory even when running as root
if [ "$EUID" -eq 0 ]; then
    # If running as root, get the home directory of the user who invoked sudo
    REAL_USER=${SUDO_USER:-$(logname)}
    HOME_DIR=$(eval echo ~$REAL_USER)
    echo "⚠️  Script is running as root. Using home directory: $HOME_DIR"
else
    HOME_DIR=$HOME
    echo "Using home directory: $HOME_DIR"
fi

# Change to the correct home directory
cd "$HOME_DIR"
echo "Working directory: $(pwd)"

# Step 1: Fix apt_pkg module issue
echo ""
echo "🔧 Step 1: Fixing apt_pkg module issue..."
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

# Step 2: Update package lists
echo ""
echo "📦 Step 2: Updating package lists..."
sudo apt update

# Step 3: Install system dependencies
echo ""
echo "📋 Step 3: Installing system dependencies..."
sudo apt install -y \
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
    g++ \
    python3-venv \
    python3-dev \
    python3-pip

# Step 4: Clean up any existing installation
echo ""
echo "🧹 Step 4: Cleaning up any existing installation..."
if [ -d "$HOME_DIR/mt3_setup" ]; then
    rm -rf "$HOME_DIR/mt3_setup"
    echo "✅ Removed existing $HOME_DIR/mt3_setup"
fi

# Step 5: Create project directory and clone MT3
echo ""
echo "📁 Step 5: Setting up MT3 project in home directory..."
mkdir -p "$HOME_DIR/mt3_setup" && cd "$HOME_DIR/mt3_setup"
git clone https://github.com/magenta/mt3.git
cd mt3

# Step 6: Create virtual environment
echo ""
echo "🐍 Step 6: Creating virtual environment..."
python3 -m venv mt3-venv
source mt3-venv/bin/activate

# Step 7: Install Python dependencies
echo ""
echo "📦 Step 7: Installing Python dependencies..."
pip install --upgrade pip
pip install --upgrade setuptools wheel

echo "Installing MT3..."
pip install -e .

# Install TensorFlow
echo ""
echo "🤖 Step 8: Installing TensorFlow..."
pip install tensorflow==2.11.0

# Install additional dependencies
echo ""
echo "📚 Step 9: Installing additional dependencies..."
pip install gin-config t5x note-seq

# Step 10: Install Google Cloud SDK
echo ""
echo "☁️ Step 10: Installing Google Cloud SDK..."
cd "$HOME_DIR/mt3_setup"
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-474.0.0-linux-x86_64.tar.gz
tar -xf google-cloud-cli-474.0.0-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh --quiet

# Add to PATH for current shell
source ./google-cloud-sdk/path.bash.inc

# Step 11: Download MT3 checkpoints
echo ""
echo "📥 Step 11: Downloading MT3 checkpoints..."
mkdir -p checkpoints
cd checkpoints
gsutil -m cp -r gs://mt3/checkpoints/ismir2021 .
cd ..

# Step 12: Create audio folder and copy test file
echo ""
echo "🎵 Step 12: Setting up audio folder..."
mkdir -p "$HOME_DIR/audio"

# Copy test audio file if it exists in the current directory
if [ -f "test_audio.wav" ]; then
    cp test_audio.wav "$HOME_DIR/audio/"
    echo "✅ Copied test_audio.wav to $HOME_DIR/audio/"
elif [ -f "*.wav" ]; then
    cp *.wav "$HOME_DIR/audio/"
    echo "✅ Copied wav files to $HOME_DIR/audio/"
else
    echo "ℹ️  No wav files found in current directory"
fi

echo ""
echo "🎉 Installation complete!"
echo "========================"
echo ""
echo "📁 Installation location: $HOME_DIR/mt3_setup"
echo "🎵 Audio folder: $HOME_DIR/audio"
echo "🐍 Python version: $(python3 --version)"
echo ""
echo "To activate your MT3 environment, run:"
echo "  source $HOME_DIR/mt3_setup/mt3/mt3-venv/bin/activate"
echo ""
echo "To test the installation, run:"
echo "  source $HOME_DIR/mt3_setup/mt3/mt3-venv/bin/activate"
echo "  cd $HOME_DIR/mt3_setup/mt3"
echo "  python -c \"import mt3; print('✅ MT3 imported successfully!')\""
