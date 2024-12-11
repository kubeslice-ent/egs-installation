
#!/bin/bash

# Set script name and version
SCRIPT_NAME="egs-installer"
VERSION="1.0.0"

# Create temporary build directory
BUILD_DIR="build"
mkdir -p $BUILD_DIR

echo "🔨 Creating binary package for $SCRIPT_NAME v$VERSION..."

# Create the binary structure
cat > $BUILD_DIR/binary.sh << 'EOF'
#!/bin/bash
############ Binary Header ############

# Embedded base64 data will be appended here
PAYLOAD_START=$(awk '/^__PAYLOAD_BELOW__/ {print NR + 1; exit 0; }' $0)

# Extract to temporary directory
TEMP_DIR=$(mktemp -d)
EXTRACT_DIR="$TEMP_DIR/egs-installer"
mkdir -p "$EXTRACT_DIR"

# Extract payload
tail -n +$PAYLOAD_START $0 | base64 --decode | tar xz -C "$EXTRACT_DIR"

# Execute the main script with all arguments
"$EXTRACT_DIR/egs-installer.sh" "$@"

# Cleanup
rm -rf "$TEMP_DIR"

exit 0

__PAYLOAD_BELOW__
EOF

# Package the installer and dependencies
echo "📦 Packaging installer and dependencies..."
tar czf - egs-installer.sh | base64 >> $BUILD_DIR/binary.sh

# Make binary executable
chmod +x $BUILD_DIR/binary.sh

# Move to final location
mv $BUILD_DIR/binary.sh "./$SCRIPT_NAME"

# Cleanup
rm -rf $BUILD_DIR

echo "✅ Binary created successfully: ./$SCRIPT_NAME"