
#!/bin/bash

# Installation paths
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="egs-installer"

echo "🚀 Installing EGS Installer..."

# Check if running with sudo/root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root or with sudo"
    exit 1
fi

# Create binary using make_binary.sh
./make_binary.sh

# Copy binary to installation directory
cp "./$SCRIPT_NAME" "$INSTALL_DIR/"

# Make executable
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

echo "✅ Installation complete. Run 'egs-installer --help' to get started."