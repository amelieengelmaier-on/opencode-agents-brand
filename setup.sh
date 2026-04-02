#!/usr/bin/env bash
set -euo pipefail

# ─── opencode-agents-brand setup ─────────────────────────────────────
# Symlinks skills, agents, and global AGENTS.md into the paths that
# OpenCode discovers automatically. Safe to re-run (idempotent).
# ─────────────────────────────────────────────────────────────────────

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

SKILLS_TARGET="$HOME/.agents/skills"
AGENTS_DIR="$HOME/.config/opencode/agents"
AGENTS_MD_TARGET="$HOME/.config/opencode/AGENTS.md"

# Colours (disabled when piped)
if [ -t 1 ]; then
  GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; NC=''
fi

info()  { printf "${GREEN}[ok]${NC}  %s\n" "$1"; }
warn()  { printf "${YELLOW}[!!]${NC}  %s\n" "$1"; }
err()   { printf "${RED}[err]${NC} %s\n" "$1"; }

backup_if_exists() {
  local target="$1"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    local backup="${target}.bak.$(date +%s)"
    warn "Existing non-symlink found at $target — backing up to $backup"
    mv "$target" "$backup"
  fi
}

create_symlink() {
  local src="$1"
  local dest="$2"
  local label="$3"

  # Already correctly linked
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    info "$label already linked"
    return
  fi

  backup_if_exists "$dest"

  # Remove stale symlink
  [ -L "$dest" ] && rm "$dest"

  ln -s "$src" "$dest"
  info "$label -> $dest"
}

# ─── Ensure parent directories exist ────────────────────────────────
mkdir -p "$(dirname "$SKILLS_TARGET")"
mkdir -p "$AGENTS_DIR"

# ─── Skills ──────────────────────────────────────────────────────────
create_symlink "$REPO_DIR/skills" "$SKILLS_TARGET" "skills/"

# ─── Agent: a11y-ticket-solver ───────────────────────────────────────
create_symlink \
  "$REPO_DIR/agents/a11y-ticket-solver.md" \
  "$AGENTS_DIR/a11y-ticket-solver.md" \
  "agents/a11y-ticket-solver.md"

# ─── Global AGENTS.md ────────────────────────────────────────────────
create_symlink \
  "$REPO_DIR/AGENTS.md" \
  "$AGENTS_MD_TARGET" \
  "AGENTS.md"

# ─── Summary ─────────────────────────────────────────────────────────
echo ""
echo "Setup complete. OpenCode will now discover:"
echo "  Skills  at  $SKILLS_TARGET"
echo "  Agent   at  $AGENTS_DIR/a11y-ticket-solver.md"
echo "  Rules   at  $AGENTS_MD_TARGET"
echo ""
echo "To update, just \`git pull\` in this repo — symlinks keep everything in sync."
