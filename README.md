# EasyTree

A simple CLI tool for managing git worktrees.

https://github.com/user-attachments/assets/09c7dca6-3f65-467f-bc45-04a1d32aa938

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/saeedvaziry/easytree/main/install.sh | bash
```

The installer sets up a shell function that auto-navigates to worktrees after `create`, `open`, and `rm` commands.

## Usage

```bash
easytree init             # Create .easytree.json config file
easytree create <name>    # Create a new worktree (auto-cd)
easytree ls               # List all worktrees
easytree open <name>      # Navigate to a worktree
easytree rm [name]        # Remove a worktree (name optional if inside one)
easytree uninstall        # Uninstall easytree
```

## Configuration

Run `easytree init` or create `.easytree.json` in your project root to run setup scripts automatically:

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
