#!/bin/bash

# List available users
echo "Available users:"
awk -F: '$3 >= 1000 && $6 ~ /^\/home/ {print " - "$1}' /etc/passwd
echo ""


# Check sudo access upfront
if ! sudo -v 2>/dev/null; then
    echo "Error: This script requires sudo privileges."
    exit 1
fi

# Prompt for target user
read -p "Enter target username: " TARGET_USER </dev/tty

# Check if user exists
if ! id "$TARGET_USER" &>/dev/null; then
    echo "Error: User '$TARGET_USER' does not exist."
    exit 1
fi

# Check if target user is the current user
if [ "$TARGET_USER" = "$USER" ]; then
    echo "Error: Target user is the same as the current user ('$USER'). Nothing to do."
    exit 1
fi

# Prompt for vscode-server source path
read -p "Enter path to .vscode-server (press Enter for default: $HOME/.vscode-server): " VSCODE_SOURCE </dev/tty
VSCODE_SOURCE=${VSCODE_SOURCE:-$HOME/.vscode-server}

# Check if vscode-server directory exists
if [ ! -d "$VSCODE_SOURCE" ]; then
    echo "Error: Directory '$VSCODE_SOURCE' does not exist."
    exit 1
fi

# Auto-detect VS Code path
VSCODE_PATH=$(which code)

if [ -z "$VSCODE_PATH" ]; then
    echo "⚠️  VS Code not found in PATH."
    read -p "Enter VS Code full path manually (e.g. /mnt/c/.../bin/code):  " VSCODE_PATH </dev/tty
fi

VSCODE_BIN_DIR=$(dirname "$VSCODE_PATH")
echo "✓ VS Code found at: $VSCODE_PATH"


TARGET_HOME="/home/$TARGET_USER"

echo ""
echo "Summary:"
echo "  Target user    : $TARGET_USER"
echo "  Source dir     : $VSCODE_SOURCE"
echo "  Destination    : $TARGET_HOME/.vscode-server"
echo "  VS Code PATH   : $VSCODE_PATH"
echo ""
read -p "Proceed? (y/n): " CONFIRM </dev/tty
if [[ "$CONFIRM" != "y" ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "[1/3] Copying .vscode-server..."
if [ -d "$TARGET_HOME/.vscode-server" ]; then
    echo "Warning: '$TARGET_HOME/.vscode-server' already exists and will be overwritten."
    read -p "Continue? (y/n): " OVERWRITE_CONFIRM </dev/tty
    if [[ "$OVERWRITE_CONFIRM" != "y" ]]; then
        echo "Aborted."
        exit 0
    fi
fi
if ! sudo cp -r "$VSCODE_SOURCE" "$TARGET_HOME/"; then
    echo "Error: Failed to copy .vscode-server."
    exit 1
fi

echo "[2/3] Setting ownership..."
if ! sudo chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.vscode-server"; then
    echo "Error: Failed to set ownership."
    exit 1
fi

echo "[3/3] Adding VS Code to PATH..."
sudo -u "$TARGET_USER" bash -c "grep -qF '$VSCODE_BIN_DIR' '$TARGET_HOME/.bashrc' || echo 'export PATH=\"\$PATH:$VSCODE_BIN_DIR\"' >> '$TARGET_HOME/.bashrc'"

echo ""
echo "✓ Setup complete for $TARGET_USER!"
echo " run: source ~/.bashrc or restart terminal to apply PATH changes."
