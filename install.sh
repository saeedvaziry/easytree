#!/bin/bash

set -e

cat << 'EOF'
                        _
   ___  __ _ ___ _   _ | |_ _ __ ___  ___
  / _ \/ _` / __| | | || __| '__/ _ \/ _ \
 |  __/ (_| \__ \ |_| || |_| | |  __/  __/
  \___|\__,_|___/\__, | \__|_|  \___|\___|
                 |___/
EOF

REPO="saeedvaziry/easytree"
BRANCH="main"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
INSTALL_NAME="easytree"

SCRIPT_URL="https://raw.githubusercontent.com/$REPO/$BRANCH/easytree.sh"

echo "Installing easytree from GitHub..."

mkdir -p "$INSTALL_DIR"

if command -v curl &> /dev/null; then
    curl -fsSL "$SCRIPT_URL" -o "$INSTALL_DIR/$INSTALL_NAME"
elif command -v wget &> /dev/null; then
    wget -qO "$INSTALL_DIR/$INSTALL_NAME" "$SCRIPT_URL"
else
    echo "Error: curl or wget is required"
    exit 1
fi

chmod +x "$INSTALL_DIR/$INSTALL_NAME"

echo "Installed successfully!"

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "Note: $INSTALL_DIR is not in your PATH."
    echo "Add the following to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
    echo ""
    echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
    echo ""
fi

echo "Run 'easytree --help' to get started."
