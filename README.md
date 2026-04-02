# opencode-agents-brand

Shared [OpenCode](https://opencode.ai) agents and skills for the On brand frontend team.

## What's included

| Type | Name | Purpose |
|---|---|---|
| **Agent** | `a11y-ticket-solver` | Senior A11y Engineer that reads Jira tickets, fixes WCAG violations, verifies, and ships PRs |
| **Skill** | `on-frontend-codebase-reference` | Monorepo map — architecture, conventions, a11y infra, data flow |
| **Skill** | `code-style-matching` | Reads neighboring files to match project style before editing |
| **Skill** | `nx-monorepo-verification` | Lint, type-check, unit test, optional a11y spec, optional screenshot |
| **Skill** | `git-ship-pr` | Commit + push + draft PR + invoke PR description updater |
| **Skill** | `pull-request-description-updater` | Generates structured PR descriptions from diff + Jira context |
| **Rules** | `AGENTS.md` | Global guardrails (Jira write-protection, communication style) |

## Prerequisites

- [OpenCode](https://opencode.ai) installed
- MCP servers configured in your `~/.config/opencode/opencode.jsonc` (Atlassian, GitHub, etc.)

## Setup

```bash
git clone git@github.com:amelieengelmaier-on/opencode-agents-brand.git ~/opencode-agents-brand
cd ~/opencode-agents-brand
./setup.sh
```

The script creates symlinks so OpenCode discovers everything automatically:

| Source (in this repo) | Symlinked to |
|---|---|
| `skills/` | `~/.agents/skills` |
| `agents/a11y-ticket-solver.md` | `~/.config/opencode/agents/a11y-ticket-solver.md` |
| `AGENTS.md` | `~/.config/opencode/AGENTS.md` |

If any of those paths already contain non-symlink files, `setup.sh` backs them up with a `.bak.<timestamp>` suffix before linking.

## Updating

```bash
cd ~/opencode-agents-brand
git pull
```

Symlinks mean changes are immediate — no re-run of `setup.sh` needed.

## Re-running setup

`setup.sh` is idempotent. If you add new agents or skills to the repo, re-run it:

```bash
./setup.sh
```

## Adding a new skill

1. Create `skills/<skill-name>/SKILL.md` with YAML frontmatter (`name`, `description`) and markdown body.
2. Commit and push.
3. Teammates run `git pull` — the symlink covers the entire `skills/` directory, so new skills appear automatically.

## Adding a new agent

1. Create `agents/<agent-name>.md` with YAML frontmatter (`description`, `mode`).
2. Add a `create_symlink` line in `setup.sh` for the new agent file.
3. Commit and push.
4. Teammates run `git pull && ./setup.sh`.

## Notes

- **Prompts** (ticket-specific `BAD-*.md` files) are intentionally not shared — they're personal/ephemeral.
- **`opencode.jsonc`** (MCP servers, model config) is not shared — each person configures their own providers.
- Three of the five skills contain `on-frontend`-specific references (PR templates, component paths). They work as-is for `on-frontend` work but would need parameterization for other repos.
