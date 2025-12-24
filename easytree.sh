#!/bin/bash

set -e

SCRIPT_NAME=$(basename "$0")
WORKTREES_BASE="${EASYTREE_PATH:-$HOME/.easytree}"

show_usage() {
    echo "Usage: $SCRIPT_NAME <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  init             Initialize .easytree.json in the current project"
    echo "  create <name>    Create a new worktree with the given name"
    echo "  ls               List all worktrees for the current project"
    echo "  open <name>      Navigate to the given worktree"
    echo "  rm [name]        Remove the specified worktree (or current if inside one)"
    echo "  uninstall        Uninstall easytree from your system"
    echo ""
    echo "Environment Variables:"
    echo "  EASYTREE_PATH    Base directory for worktrees (default: ~/.easytree)"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME init                    # Initialize .easytree.json config"
    echo "  $SCRIPT_NAME create feature-login    # Create and navigate to worktree"
    echo "  $SCRIPT_NAME ls                      # List worktrees"
    echo "  $SCRIPT_NAME open feature-login      # Navigate to existing worktree"
    echo "  $SCRIPT_NAME rm feature-login        # Remove worktree"
    echo "  $SCRIPT_NAME rm                      # Remove current worktree and navigate back"
    echo "  EASYTREE_PATH=/custom/path $SCRIPT_NAME create feature-login"
}

ensure_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: Not inside a git repository"
        exit 1
    fi
}

get_project_info() {
    # Get the common git directory (works for both main repo and worktrees)
    GIT_COMMON_DIR=$(git rev-parse --git-common-dir)

    # If we're in a worktree, git-common-dir points to main repo's .git
    # If we're in main repo, it just returns .git
    if [[ "$GIT_COMMON_DIR" == ".git" ]]; then
        PROJECT_PATH=$(git rev-parse --show-toplevel)
    else
        # Remove the .git suffix to get the project path
        PROJECT_PATH=$(dirname "$GIT_COMMON_DIR")
    fi

    PROJECT_NAME=$(basename "$PROJECT_PATH")
    PROJECT_WORKTREES_DIR="$WORKTREES_BASE/$PROJECT_NAME"
}

cmd_init() {
    CONFIG_FILE="$PROJECT_PATH/.easytree.json"

    if [ -f "$CONFIG_FILE" ]; then
        echo "Error: .easytree.json already exists at $CONFIG_FILE"
        exit 1
    fi

    cat > "$CONFIG_FILE" << 'EOF'
{
  "scripts": [
  ]
}
EOF

    echo "Created .easytree.json at $CONFIG_FILE"
    echo ""
    echo "Add setup scripts to run when creating new worktrees."
    echo "Example:"
    echo '  {"scripts": ["npm install", "cp $PROJECT_PATH/.env .env"]}'
}

cmd_create() {
    if [ -z "$1" ]; then
        echo "Error: Worktree name required" >&2
        echo "Usage: $SCRIPT_NAME create <name>" >&2
        exit 1
    fi

    WORKTREE_NAME="$1"
    WORKTREE_PATH="$PROJECT_WORKTREES_DIR/$WORKTREE_NAME"

    mkdir -p "$PROJECT_WORKTREES_DIR"

    if [ -d "$WORKTREE_PATH" ]; then
        echo "Error: Worktree already exists at $WORKTREE_PATH" >&2
        exit 1
    fi

    echo "Creating worktree '$WORKTREE_NAME' at $WORKTREE_PATH..." >&2

    git worktree add -b "$WORKTREE_NAME" "$WORKTREE_PATH" >&2

    echo "Worktree created successfully!" >&2

    WORKTREE_CONFIG="$PROJECT_PATH/.easytree.json"

    if [ -f "$WORKTREE_CONFIG" ]; then
        echo "Found .easytree.json, running setup scripts..." >&2

        cd "$WORKTREE_PATH"

        export PROJECT_PATH

        SCRIPTS=$(jq -r '.scripts[]' "$WORKTREE_CONFIG" 2>/dev/null)

        if [ $? -ne 0 ]; then
            echo "Error: Failed to parse .worktree.json" >&2
            exit 1
        fi

        while IFS= read -r script; do
            if [ -n "$script" ]; then
                echo "Running: $script" >&2
                eval "$script" >&2
            fi
        done <<< "$SCRIPTS"

        echo "Setup complete!" >&2
    else
        echo "No .easytree.json found, skipping setup scripts." >&2
    fi

    echo "" >&2
    echo "Worktree ready at: $WORKTREE_PATH" >&2

    # Output path to stdout for cd capture
    echo "$WORKTREE_PATH"
}

cmd_ls() {
    if [ ! -d "$PROJECT_WORKTREES_DIR" ]; then
        echo "No worktrees found for project '$PROJECT_NAME'"
        exit 0
    fi

    echo "Worktrees for '$PROJECT_NAME':"
    echo ""

    for dir in "$PROJECT_WORKTREES_DIR"/*/; do
        if [ -d "$dir" ]; then
            name=$(basename "$dir")
            echo "  $name"
        fi
    done
}

cmd_open() {
    if [ -z "$1" ]; then
        echo "Error: Worktree name required"
        echo "Usage: $SCRIPT_NAME open <name>"
        exit 1
    fi

    WORKTREE_NAME="$1"
    WORKTREE_PATH="$PROJECT_WORKTREES_DIR/$WORKTREE_NAME"

    if [ ! -d "$WORKTREE_PATH" ]; then
        echo "Error: Worktree '$WORKTREE_NAME' does not exist"
        exit 1
    fi

    echo "$WORKTREE_PATH"
}

cmd_rm() {
    CURRENT_DIR=$(pwd)
    NAVIGATE_BACK=""

    if [ -z "$1" ]; then
        # Check if current directory is a worktree
        if [[ "$CURRENT_DIR" == "$PROJECT_WORKTREES_DIR/"* ]]; then
            # Extract worktree name from current path
            RELATIVE_PATH="${CURRENT_DIR#$PROJECT_WORKTREES_DIR/}"
            WORKTREE_NAME="${RELATIVE_PATH%%/*}"
            NAVIGATE_BACK="$PROJECT_PATH"
        else
            echo "Error: Worktree name required (or run from within a worktree)" >&2
            echo "Usage: $SCRIPT_NAME rm [name]" >&2
            exit 1
        fi
    else
        WORKTREE_NAME="$1"
    fi

    WORKTREE_PATH="$PROJECT_WORKTREES_DIR/$WORKTREE_NAME"

    if [ ! -d "$WORKTREE_PATH" ]; then
        echo "Error: Worktree '$WORKTREE_NAME' does not exist" >&2
        exit 1
    fi

    # If we're inside the worktree being removed, we need to navigate out first
    if [[ "$CURRENT_DIR" == "$WORKTREE_PATH"* ]]; then
        NAVIGATE_BACK="$PROJECT_PATH"
        cd "$PROJECT_PATH"
    fi

    echo "Removing worktree '$WORKTREE_NAME'..." >&2

    git worktree remove "$WORKTREE_PATH"

    if git show-ref --verify --quiet "refs/heads/$WORKTREE_NAME"; then
        echo "Deleting branch '$WORKTREE_NAME'..." >&2
        git branch -d "$WORKTREE_NAME" 2>/dev/null || git branch -D "$WORKTREE_NAME"
    fi

    echo "Worktree '$WORKTREE_NAME' removed successfully!" >&2

    # Output path for shell wrapper to navigate back
    if [ -n "$NAVIGATE_BACK" ]; then
        echo "$NAVIGATE_BACK"
    fi
}

cmd_uninstall() {
    echo "Uninstalling easytree..."
    echo ""

    SCRIPT_PATH=$(realpath "$0")

    # Detect shell rc file
    SHELL_RC=""
    if [[ -n "$ZSH_VERSION" ]] || [[ "$SHELL" == */zsh ]]; then
        SHELL_RC="$HOME/.zshrc"
    elif [[ -n "$BASH_VERSION" ]] || [[ "$SHELL" == */bash ]]; then
        SHELL_RC="$HOME/.bashrc"
    fi

    # Remove shell function from rc file
    if [[ -n "$SHELL_RC" && -f "$SHELL_RC" ]]; then
        if grep -q "easytree()" "$SHELL_RC" 2>/dev/null; then
            echo "Removing shell function from $SHELL_RC..."
            temp_file=$(mktemp)
            awk '
                /^# easytree - git worktree manager$/ { skip=1; next }
                /^easytree\(\) \{$/ { skip=1; next }
                skip && /^\}$/ { skip=0; next }
                !skip { print }
            ' "$SHELL_RC" > "$temp_file"
            mv "$temp_file" "$SHELL_RC"
            echo "Shell function removed."
        fi
    fi

    # Ask about removing worktree data
    if [[ -d "$WORKTREES_BASE" ]]; then
        echo ""
        echo "Worktree data found at: $WORKTREES_BASE"
        read -p "Do you want to remove all worktree data? [y/N] " -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Removing worktree data..."
            rm -rf "$WORKTREES_BASE"
            echo "Worktree data removed."
        else
            echo "Keeping worktree data."
        fi
    fi

    # Remove the script itself
    echo ""
    echo "Removing easytree script from $SCRIPT_PATH..."
    rm -f "$SCRIPT_PATH"

    echo ""
    echo "easytree has been uninstalled."
    if [[ -n "$SHELL_RC" ]]; then
        echo ""
        echo "Please restart your shell or run: source $SHELL_RC"
    fi
}

# Main
if [ -z "$1" ]; then
    show_usage
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
    init|create|ls|open|rm)
        ensure_git_repo
        get_project_info
        "cmd_$COMMAND" "$@"
        ;;
    uninstall)
        cmd_uninstall
        ;;
    -h|--help|help)
        show_usage
        exit 0
        ;;
    *)
        echo "Error: Unknown command '$COMMAND'"
        echo ""
        show_usage
        exit 1
        ;;
esac
