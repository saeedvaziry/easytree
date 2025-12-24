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
INSTALL_NAME="easytree"
SCRIPT_URL="https://raw.githubusercontent.com/$REPO/$BRANCH/easytree.sh"

# Check if easytree is already installed
EXISTING_INSTALL=""
if command -v easytree &> /dev/null; then
    EXISTING_INSTALL=$(command -v easytree)
    # Resolve if it's a function by checking if file exists
    if [[ ! -f "$EXISTING_INSTALL" ]]; then
        # It might be a shell function, search in common paths
        for dir in "$HOME/.local/bin" "/usr/local/bin" "$HOME/bin"; do
            if [[ -f "$dir/$INSTALL_NAME" ]]; then
                EXISTING_INSTALL="$dir/$INSTALL_NAME"
                break
            fi
        done
    fi
fi

# Download the script
download_script() {
    local dest="$1"

    if command -v curl &> /dev/null; then
        curl -fsSL "$SCRIPT_URL" -o "$dest"
    elif command -v wget &> /dev/null; then
        wget -qO "$dest" "$SCRIPT_URL"
    else
        echo "Error: curl or wget is required"
        exit 1
    fi

    chmod +x "$dest"
}

# Setup shell function
setup_shell_function() {
    local install_path="$1"

    SHELL_FUNCTION='
# easytree - git worktree manager
easytree() {
    if [[ "$1" == "create" || "$1" == "open" || "$1" == "rm" ]]; then
        local result
        result=$("'"$install_path"'" "$@")
        local exit_code=$?
        if [[ $exit_code -eq 0 && -n "$result" && -d "$result" ]]; then
            cd "$result" || return 1
        fi
        return $exit_code
    else
        "'"$install_path"'" "$@"
    fi
}
'

    SHELL_RC=""
    if [[ "$SHELL" == */zsh ]]; then
        SHELL_RC="$HOME/.zshrc"
    elif [[ "$SHELL" == */bash ]]; then
        SHELL_RC="$HOME/.bashrc"
    fi

    if [[ -n "$SHELL_RC" && -f "$SHELL_RC" ]]; then
        # Remove old easytree function if exists (for updates)
        if grep -q "easytree()" "$SHELL_RC" 2>/dev/null; then
            temp_file=$(mktemp)
            awk '
                /^# easytree - git worktree manager$/ { skip=1; next }
                /^easytree\(\) \{$/ { skip=1; next }
                skip && /^\}$/ { skip=0; next }
                !skip { print }
            ' "$SHELL_RC" > "$temp_file"
            mv "$temp_file" "$SHELL_RC"
        fi

        echo "" >> "$SHELL_RC"
        echo "$SHELL_FUNCTION" >> "$SHELL_RC"
        echo "Shell function added to $SHELL_RC"
        echo ""
        echo "Restart your shell or run: source $SHELL_RC"
    elif [[ -n "$SHELL_RC" ]]; then
        echo "" >> "$SHELL_RC"
        echo "$SHELL_FUNCTION" >> "$SHELL_RC"
        echo "Shell function added to $SHELL_RC"
        echo ""
        echo "Restart your shell or run: source $SHELL_RC"
    else
        echo ""
        echo "Add this function to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
        echo "$SHELL_FUNCTION"
    fi
}

# Collect writable paths
collect_paths() {
    AVAILABLE_PATHS=()
    local seen=""

    # Check directories in PATH
    IFS=':' read -ra PATH_DIRS <<< "$PATH"
    for dir in "${PATH_DIRS[@]}"; do
        [[ -z "$dir" ]] && continue
        [[ -d "$dir" && -w "$dir" ]] || continue

        # Check for duplicates
        case "$seen" in
            *"|$dir|"*) continue ;;
        esac
        seen="$seen|$dir|"
        AVAILABLE_PATHS+=("$dir")
    done

    # Add common paths if writable
    for suggested in "$HOME/.local/bin" "$HOME/bin"; do
        parent_dir=$(dirname "$suggested")
        if [[ -d "$parent_dir" && -w "$parent_dir" ]]; then
            case "$seen" in
                *"|$suggested|"*) continue ;;
            esac
            seen="$seen|$suggested|"
            AVAILABLE_PATHS+=("$suggested")
        fi
    done
}

# Handle update
if [[ -n "$EXISTING_INSTALL" && -f "$EXISTING_INSTALL" ]]; then
    echo ""
    echo "easytree is already installed at: $EXISTING_INSTALL"
    echo ""
    printf "Do you want to update it? [Y/n] "
    read -r REPLY < /dev/tty

    if [[ "$REPLY" =~ ^[Nn]$ ]]; then
        echo "Update cancelled."
        exit 0
    fi

    echo "Updating easytree..."
    download_script "$EXISTING_INSTALL"
    setup_shell_function "$EXISTING_INSTALL"
    echo ""
    echo "easytree updated successfully!"
    exit 0
fi

# Fresh installation - find available paths
echo ""
echo "Finding available installation paths..."
echo ""

collect_paths

if [[ ${#AVAILABLE_PATHS[@]} -eq 0 ]]; then
    echo "No writable directories found in PATH."
    echo ""
    printf "Enter a custom installation path: "
    read -r CUSTOM_PATH < /dev/tty

    if [[ -z "$CUSTOM_PATH" ]]; then
        echo "Error: No path provided"
        exit 1
    fi

    INSTALL_DIR="$CUSTOM_PATH"
else
    echo "Available installation paths:"
    echo ""

    i=0
    for path in "${AVAILABLE_PATHS[@]}"; do
        i=$((i + 1))
        in_path=""
        if [[ ":$PATH:" == *":$path:"* ]]; then
            in_path=" (in PATH)"
        else
            in_path=" (not in PATH)"
        fi

        if [[ ! -d "$path" ]]; then
            in_path="$in_path (will be created)"
        fi

        echo "  $i) $path$in_path"
    done

    echo ""
    echo "  0) Enter custom path"
    echo ""

    while true; do
        printf "Select installation path [1]: "
        read -r choice < /dev/tty
        choice=${choice:-1}

        if [[ "$choice" == "0" ]]; then
            printf "Enter custom path: "
            read -r CUSTOM_PATH < /dev/tty
            if [[ -z "$CUSTOM_PATH" ]]; then
                echo "Error: No path provided"
                continue
            fi
            INSTALL_DIR="$CUSTOM_PATH"
            break
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#AVAILABLE_PATHS[@]} ]]; then
            INSTALL_DIR="${AVAILABLE_PATHS[$((choice - 1))]}"
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
fi

INSTALL_PATH="$INSTALL_DIR/$INSTALL_NAME"

echo ""
echo "Installing easytree to $INSTALL_PATH..."

mkdir -p "$INSTALL_DIR"
download_script "$INSTALL_PATH"

echo "Installed successfully!"

# Check if install dir is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "Note: $INSTALL_DIR is not in your PATH."
    echo "Add the following to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
    echo ""
    echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
fi

setup_shell_function "$INSTALL_PATH"

echo ""
echo "Run 'easytree --help' to get started."
