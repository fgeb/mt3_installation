# 🚀 Clean MT3 Installation Guide

This guide will help you perform a completely clean installation of MT3 on your Ubuntu system.

## 📋 Prerequisites

- Ubuntu 20.04+ (you're on Ubuntu 24.04 which is perfect)
- Internet connection
- sudo privileges

## 🧹 Step 1: Clean Up Previous Installations

First, let's remove any partial or failed installations:

```bash
sudo bash cleanup_mt3.sh
```

This script will:
- Remove any existing MT3 installation directories
- Clean up virtual environments
- Fix the apt_pkg module issue
- Test that apt is working correctly

## 🎯 Step 2: Perform Clean Installation

Now run the minimal installation script (recommended to avoid PPA issues):

```bash
sudo bash install_mt3_minimal.sh
```

This script will:
- Fix any remaining apt_pkg issues
- Install all system dependencies
- Use your system Python (avoiding PPA problems)
- Create a virtual environment
- Install MT3 and all dependencies
- Download the required checkpoints

## 🔍 Step 3: Verify Installation

After the installation completes, test that everything works:

```bash
# Activate the virtual environment
source ~/mt3_setup/mt3/mt3-venv/bin/activate

# Navigate to the MT3 directory
cd ~/mt3_setup/mt3

# Test that MT3 can be imported
python -c "import mt3; print('✅ MT3 imported successfully!')"

# Check the Python version being used
python --version

# Check that TensorFlow is installed
python -c "import tensorflow as tf; print(f'✅ TensorFlow {tf.__version__} installed')"
```

## 🚨 Troubleshooting

### If you get apt_pkg errors:
```bash
sudo bash fix_apt_pkg.sh
```

### If the installation fails:
1. Run the cleanup script again
2. Check your internet connection
3. Try the safe installation script instead:
   ```bash
   sudo bash install_mt3_safe.sh
   ```

### If you get permission errors:
Make sure you're running the scripts with sudo:
```bash
sudo bash install_mt3_minimal.sh
```

## 📁 What Gets Installed

The installation creates:
- `~/mt3_setup/` - Main installation directory
- `~/mt3_setup/mt3/` - MT3 source code
- `~/mt3_setup/mt3/mt3-venv/` - Python virtual environment
- `~/mt3_setup/checkpoints/` - MT3 model checkpoints
- `~/mt3_setup/google-cloud-sdk/` - Google Cloud SDK

## 🎉 Success Indicators

You'll know the installation was successful when:
- ✅ No error messages during installation
- ✅ MT3 can be imported without errors
- ✅ TensorFlow is installed and working
- ✅ The virtual environment activates properly
- ✅ Checkpoints are downloaded (several GB)

## 🔄 Using MT3 After Installation

To use MT3 in the future:

```bash
# Activate the environment
source ~/mt3_setup/mt3/mt3-venv/bin/activate

# Navigate to MT3 directory
cd ~/mt3_setup/mt3

# Your MT3 commands go here
```

## 📞 Need Help?

If you encounter any issues:
1. Check the error messages carefully
2. Run the cleanup script and try again
3. Make sure your system has enough disk space (at least 10GB free)
4. Ensure you have a stable internet connection
