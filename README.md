# EasyTree

A simple CLI tool for managing git worktrees.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/saeeddhqan/easytree/main/install.sh | bash
```

Custom install directory:
```bash
curl -fsSL https://raw.githubusercontent.com/saeeddhqan/easytree/main/install.sh | INSTALL_DIR=/usr/local/bin bash
```

## Usage

```bash
easytree create <name>    # Create a new worktree
easytree ls               # List all worktrees
easytree open <name>      # Print worktree path
easytree rm <name>        # Remove a worktree
```

Navigate to a worktree:
```bash
cd $(easytree create feature-login)
cd $(easytree open feature-login)
```

## Configuration

Create `.easytree.json` in your project root to run setup scripts automatically:

```json
{
  "scripts": [
    "cp $PROJECT_PATH/.env .env",
    "npm install"
  ]
}
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `EASYTREE_PATH` | Base directory for worktrees | `~/.easytree` |

```bash
EASYTREE_PATH=/custom/path easytree create feature-login
```
