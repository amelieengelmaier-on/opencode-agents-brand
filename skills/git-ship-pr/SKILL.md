---
name: git-ship-pr
description: Commit changes, create a draft GitHub PR, update the PR description using the pull-request-description-updater skill, and optionally transition a Jira ticket. Use when code changes are verified and ready to be shipped as a pull request.
---

# Git Ship PR

Package verified code changes into an atomic commit, open a draft PR, generate a meaningful PR description, and optionally transition the linked Jira ticket.

## When to Use

Invoke this skill after all verification steps have passed and the code is ready for review.

## Prerequisites

- All changes are staged or ready to stage.
- The `gh` CLI is authenticated.
- A feature branch exists (or will be created).
- Verification results are available to feed into the PR description.

## Workflow

### Step 1: Create a Feature Branch (if needed)

If not already on a feature branch, create one:

```bash
git checkout -b <prefix>-<ticket-id>-<kebab-case-summary>
```

Where:
- `<prefix>` is the Jira project key (e.g., `AWR`, `B2C`) or a team prefix.
- `<ticket-id>` is the ticket number.
- `<kebab-case-summary>` is a short description of the change.

If already on a correctly named feature branch, skip this step.

### Step 2: Atomic Commit

Stage and commit all related changes in a single commit:

```bash
git add <files>
git commit -m "<type>: <imperative summary>"
```

Commit message conventions:
- **Type:** `fix`, `feat`, `refactor`, `test`, `docs`, `chore`
- **Style:** imperative mood, lowercase, no period at the end
- **Scope:** keep it to one line; details belong in the PR description

### Step 3: Push and Create Draft PR

```bash
git push -u origin HEAD
gh pr create --title "<TICKET-ID>: <summary>" --draft
```

Capture the PR URL from the `gh pr create` output.

### Step 4: Update PR Description

Invoke the `pull-request-description-updater` skill with:
- The PR URL from Step 3
- Any verification results, test logs, or context gathered by the calling agent

The `pull-request-description-updater` skill handles fetching the diff, analyzing changes, preserving template structure, and updating the PR body via the GitHub API.

### Step 5: Jira Linking (Automatic)

**Do NOT post comments on Jira or transition ticket status.** The `on-frontend` repo has an automated `jira-pr-action` that detects ticket IDs in branch names and adds preview links and Jira references to the PR automatically.

Your only responsibility is to ensure the branch name contains the ticket ID (e.g., `BAD-281-fix-look-aria-labels`), which was already handled in Step 1.

### Step 6: Confirm to User

Report the outcome:

```
Shipped:
  Branch:  BAD-1234-fix-button-accessibility
  Commit:  fix: add aria-label to icon-only button
  PR:      https://github.com/onrunning/on-frontend/pull/5678 (draft)
  Jira:    BAD-1234 linked automatically via branch name
```

## Error Handling

- **Push rejected:** Pull and rebase first (`git pull --rebase origin main`), then retry the push.
- **PR creation fails:** Check if a PR already exists for the branch (`gh pr list --head <branch>`). If so, report the existing PR URL.
- **Jira transition fails:** Log the error but do not block. The PR is the critical deliverable.

## Notes

- This skill always creates **draft** PRs. The author promotes to "Ready for Review" manually.
- The commit should be atomic — one logical change per commit. If multiple files changed, they should all relate to the same fix or feature.
- This skill does not run verification. Invoke `nx-monorepo-verification` (or equivalent) before calling this skill.
