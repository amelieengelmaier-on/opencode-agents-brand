---
name: pull-request-description-updater
description: Update a GitHub pull request description with meaningful content reflecting the actual changes. Use when the user wants to "update PR description", "fill in PR description", "improve PR description", or provides a PR URL asking to update it. Analyzes the PR diff and commits to generate a comprehensive description while preserving the existing template structure.
---

# Pull Request Description Updater

Automatically update a GitHub pull request description with meaningful content based on the actual code changes, while preserving the template structure (preview links, ticket links, section headers).

## Core Principles

These rules override all other guidance in this skill:

1. **Brevity is mandatory.** Output length must scale with diff size. A 1-line CSS fix gets 1-2 bullets. A 20-file feature gets a short paragraph + 3-4 bullets. Never produce a wall of text.
2. **Review steps are actions, not explanations.** Each step starts with a verb (Navigate, Verify, Tab, Check, Open). Never explain implementation details in review steps.
3. **Links go where they're useful.** The generic Preview/Jira links stay at the top. Page-specific preview + staging URLs are embedded inline in Review Instructions.
4. **Visuals are required for UI changes.** If the diff touches visual output, ask the user for screenshots before finishing.
5. **Omit empty sections.** If Notes has nothing non-obvious to say, omit it entirely. Never generate filler.

## Prerequisites

- GitHub MCP server must be running
- Atlassian MCP server must be running (for fetching Jira ticket context)
- User must have write access to the repository

## Workflow

### Step 1: Check GitHub MCP Availability

Use `tool_search_tool_regex` with pattern `mcp_github` to check if GitHub MCP tools are available.

**If tools are NOT available:**

1. First, try to check if the GitHub MCP server can be started. Look for common MCP server configurations.
2. If auto-start is not possible, inform the user:

   ```
   The GitHub MCP server is not running. Please start it by:
   1. Opening VS Code settings
   2. Ensuring the GitHub MCP extension is installed and enabled
   3. Restarting VS Code if needed

   Alternatively, run: `gh copilot mcp start github`
   ```

3. Use `ask_questions` to let the user confirm when they've started it, then retry.

### Step 2: Get PR URL

If a PR URL was provided in the initial prompt, parse it. Otherwise, use `ask_questions` to prompt the user:

```json
{
  "questions": [
    {
      "header": "PR URL",
      "question": "Please provide the GitHub PR URL you want to update (e.g., https://github.com/owner/repo/pull/123)",
      "options": []
    }
  ]
}
```

Parse the URL to extract:
- `owner`: Repository owner (e.g., "onrunning")
- `repo`: Repository name (e.g., "on-frontend")
- `pullNumber`: PR number (e.g., 8465)

**URL Pattern**: `https://github.com/{owner}/{repo}/pull/{pullNumber}`

### Step 3: Fetch Current PR Details

Use `mcp_github_github_pull_request_read` with method `get` to fetch:
- Current PR title
- Current PR body (description)
- Base and head branches
- PR state

```json
{
  "method": "get",
  "owner": "{owner}",
  "repo": "{repo}",
  "pullNumber": {pullNumber}
}
```

### Step 4: Analyze PR Template Structure

Parse the current PR description to identify and **preserve**:

1. **Preview/Deploy Links**: URLs to preview environments — these are **never deleted or modified**
2. **Ticket Links**: JIRA links — these are **never deleted or modified**
3. **Section Headers**: Preserve all `##` and `###` headers from the template
4. **Checkboxes**: Preserve any checklist items
5. **Existing screenshots/images**: Preserve as-is

**Known repo templates:**

For `onrunning/on-frontend`, the PR template uses these exact headers:
```markdown
### 💡 **Description**
### 🎓 **Review Instructions**
### 🗒️ **Notes**
### ➕ **Additional Information**
```

Always use these headers for `on-frontend` PRs. The top of the PR body always starts with the pre-generated links — preserve them exactly:
```markdown
**[Preview](https://on-shop-{PR_NUMBER}.on-running.com)**
**[Jira ticket](https://onrunning.atlassian.net/browse/{TICKET_ID})**
```

If the original PR body already has these links (or any variant), keep them verbatim. **Never delete, rewrite, or reorder them.**

### Step 5: Fetch PR Changes

Use multiple API calls in parallel to gather change information:

#### 5a. Get the PR diff

```json
{
  "method": "get_diff",
  "owner": "{owner}",
  "repo": "{repo}",
  "pullNumber": {pullNumber}
}
```

#### 5b. Get changed files list

```json
{
  "method": "get_files",
  "owner": "{owner}",
  "repo": "{repo}",
  "pullNumber": {pullNumber},
  "perPage": 100
}
```

#### 5c. Get commit history for the PR

Use `mcp_github_github_list_commits` to get commits on the PR branch.

#### 5d. Fetch Jira ticket for testing context

Parse the Jira ticket key from the PR title or body (e.g., `BAD-281` from title "BAD-281: fix duplicate aria-labels"). Then fetch the ticket using the Atlassian MCP:

```json
{
  "cloudId": "onrunning.atlassian.net",
  "issueIdOrKey": "{TICKET_KEY}",
  "responseContentFormat": "markdown"
}
```

**Extract from the Jira ticket:**
1. **Page URL** — look for a "Page URL:" field, a URL in the description, or a URL in "Steps to Reproduce". Deque accessibility audit tickets consistently include a page URL.
2. **Steps to Reproduce** — useful for writing Review Instructions (what to test and how).
3. **Acceptance Criteria** — useful for knowing what the reviewer should verify.

**Use the extracted page URL(s) to build both preview and staging links** for the Review Instructions section:
- Preview: `https://on-shop-{PR_NUMBER}.on-running.com/{locale}/{path}`
- Staging: `https://www-staging.on.com/{locale}/{path}`

Where `{locale}` defaults to `en-ch` for `onrunning/on-frontend`.

**Fallback:** If no page URL is found in the Jira ticket, **ask the user** which page(s) the change should be tested on. Do not generate Review Instructions without specific page URLs — generic "navigate to preview" instructions are not acceptable.

### Step 6: Classify PR Scope & Detect UI Changes

Before generating content, classify the PR into one of three tiers. This determines output density.

#### 6a. Scope Classification

| Tier | Signal | Description Budget | Review Budget |
|---|---|---|---|
| **Minimal** | ≤ 3 files changed, type-only, config-only, or generated code | 1 bullet | "No visual changes" or 1-2 steps |
| **Focused** | Single component/feature, < 10 files | 2-4 bullets | 3-5 numbered steps with inline links |
| **Broad** | Multi-component feature, > 10 files | 1 short paragraph + 3-5 bullets | Numbered steps + Preview/Staging table |

#### 6b. UI Change Detection

Scan the changed files list for visual impact. A PR has **UI changes** if the diff modifies any of:
- `.scss`, `.css`, `.module.css`, `.less` files
- `.vue` template sections containing class or style attribute changes
- Component files that render visible markup (not just logic/utility files)
- Image assets, SVG files, or icon files

If UI changes are detected, set a flag for Step 7b (Visual Gating).

### Step 7: Generate Description Content

> **Critical:** Use the section headers from the repo's own PR template (detected in Step 4). Do NOT invent new section headers.

#### Description Section (`### 💡 **Description**`)

- **Minimal tier**: 1 bullet summarizing the change.
- **Focused tier**: 2-4 bullets. Each bullet is 1 sentence max.
- **Broad tier**: 1 short paragraph (2-3 sentences) summarizing the purpose, followed by a bullet list of key changes.

**Rules:**
- Focus on *what* changed and *why*, not *how*.
- No root-cause analysis or spec references — link to the Jira ticket for deep context.
- No inline code blocks longer than a single identifier or config key.
- If generated code is included (e.g., `yarn generate-types`), mention it in a PS note, not in the main bullets.

#### Review Instructions Section (`### 🎓 **Review Instructions**`)

Write as a **numbered checklist of actions**. Each step starts with a verb.

**Rules:**
- Each step = 1 action a reviewer can perform.
- **Always include page-specific preview and staging URLs** — source these from the Jira ticket (Step 5d) or ask the user. Never write generic "navigate to preview" without a concrete path.
- Embed page-specific preview and staging URLs directly in the step or below it.
- For PRs with no visual changes (type-only, config-only), write: `No visual changes`
- For single-page testing, list preview and staging URLs inline:
  ```
  - Preview: https://on-shop-{PR}.on-running.com/{locale}/{path}
  - Staging: https://www-staging.on.com/{locale}/{path}
  ```
- For multi-page testing (3+ pages), use a **table**:

```markdown
| Page | Preview | Staging |
|---|---|---|
| Page Name | [Preview](https://on-shop-{PR}.on-running.com/{path}) | [Staging](https://www-staging.on.com/{path}) |
```

**URL patterns for `onrunning/on-frontend`:**
- Preview: `https://on-shop-{PR_NUMBER}.on-running.com/{locale}/{path}`
- Staging: `https://www-staging.on.com/{locale}/{path}`

**Example good review steps:**
```
1. Navigate to [Preview](https://on-shop-8706.on-running.com/en-ch/collection/cloudmonster-real-energy)
2. Verify the background blends seamlessly with surrounding content
3. Check spacing on the comparison table on both mobile and desktop
```

**Example bad review steps (avoid):**
```
1. Verify the new `setRecurlyIframeTitles()` function and its call site in `onMounted` — it queries each Recurly container div for the injected `<iframe>` and sets a `title` attribute derived from...
```

#### Notes Section (`### 🗒️ **Notes**`) — OPTIONAL

**Include only if** there is genuinely non-obvious information:
- Browser compatibility notes (e.g., "`overflow: clip` is supported in Chrome 90+, Firefox 81+, Safari 16+")
- Scoping decisions (e.g., "Only Standard Video is enabled in this PR; other components tracked in BAD-XXX")
- Known limitations or caveats

**Formatting:** Always use bullet lists. Never use tables in the Notes section.

**Omit this section entirely** if there is nothing surprising or non-obvious. Never generate filler.

#### Additional Information Section (`### ➕ **Additional Information**`)

Always include. Always the same:
```markdown
- Refer to our [confluence page](https://onrunning.atlassian.net/wiki/spaces/OT/pages/2509865083/Additional+Information+For+Pull+Requests) for more information relating to pull requests.
```

### Step 7b: Visual Gating (UI Change Checkpoint)

**This step is mandatory if UI changes were detected in Step 6b.**

Before composing the final PR description, **stop and ask the user**:

> "I see UI changes in `[ComponentName/file]`. Could you provide a screenshot of `[specific page/view from the review steps]`? I'll embed it inline in the Review Instructions section."

**Behavior:**
- Name the specific component(s) and the specific preview page URL where the change is visible.
- If the user provides a screenshot, embed it inline in the Review Instructions section, directly after the review step it illustrates (matching the pattern from gold-standard PRs #8706 and #8897).
- If the user provides multiple screenshots (e.g., before/after), embed both with labels.
- If the user declines or says "skip", proceed without screenshots but add an HTML comment: `<!-- No screenshot provided for UI changes -->`
- **Do NOT finish generating the PR description until this checkpoint is resolved.**

### Step 8: Compose Updated Description

Merge the generated content with the preserved template structure:

1. **Never delete or modify** the pre-generated Preview and Jira ticket links at the top of the body
2. Keep all section headers from the original template
3. Replace placeholder text with generated content
4. Preserve existing screenshots/images
5. Embed new screenshots (from Step 7b) inline in Review Instructions
6. If Notes section is omitted, remove the header too — don't leave an empty section

**Placeholder Detection Patterns:**
- Empty or whitespace-only sections
- Generic text like: "Please describe", "Add description here", "TODO", "TBD", "..."
- Single word like: "Description", "Changes", "Testing"

### Step 9: Update the PR

Use `mcp_github_github_update_pull_request` to update the description:

```json
{
  "owner": "{owner}",
  "repo": "{repo}",
  "pullNumber": {pullNumber},
  "body": "{newDescription}"
}
```

### Step 10: Confirm Success

Report to the user:
- Confirm the PR was updated successfully
- Show a summary of what sections were updated
- Provide the PR URL for easy access

## Reference Examples

These are condensed templates based on real gold-standard PRs from `onrunning/on-frontend`. Use them to calibrate your output.

### Example A: Type-Only / Non-Visual PR (modeled on #8868)

```markdown
**[Preview](https://on-shop-8868.on-running.com)**
**[Jira ticket](https://onrunning.atlassian.net/browse/BAD-1120)**

### 💡 **Description**

- Added Grid block and Color block as possible types for topBlock field in page PLP type

PS: contains other unrelated type changes generated using `yarn on-store generate-types`

### 🎓 **Review Instructions**

No visual changes

### ➕ **Additional Information**

- Refer to our [confluence page](https://onrunning.atlassian.net/wiki/spaces/OT/pages/2509865083/Additional+Information+For+Pull+Requests) for more information relating to pull requests.
```

### Example B: Single-Component UI Fix (modeled on #8706)

```markdown
**[Preview](https://on-shop-8706.on-running.com)**
**[Jira ticket](https://onrunning.atlassian.net/browse/BAD-1084)**

### 💡 **Description**

- Fix `ImageMotionTrail` background rendering by adding `mix-blend-mode: multiply` to the container
- Adjust `ComparisonItemContent` CTA wrapper padding

### 🎓 **Review Instructions**

Preview: https://on-shop-8706.on-running.com/en-ch/collection/cloudmonster-real-energy

<img width="377" alt="image" src="screenshot-url"/>

1. Navigate to a page using the `ImageMotionTrail` component
2. Verify the background blends seamlessly with surrounding content
3. Verify spacing on the comparison table on mobile and desktop:
   - [cloudmonster](https://on-shop-8706.on-running.com/en-ch/collection/cloudmonster)
   - [real energy](https://on-shop-8706.on-running.com/en-ch/collection/cloudmonster-real-energy)
   - [tights guide](https://on-shop-8706.on-running.com/en-ch/collection/leggings-and-tights-guide)

### 🗒️ **Notes**

- `mix-blend-mode: multiply` removes white from rendered output, ideal for overlaying on colored backgrounds

### ➕ **Additional Information**

- Refer to our [confluence page](https://onrunning.atlassian.net/wiki/spaces/OT/pages/2509865083/Additional+Information+For+Pull+Requests) for more information relating to pull requests.
```

### Example C: Multi-Page Feature / Accessibility Fix (modeled on #8862)

```markdown
**[Preview](https://on-shop-8862.on-running.com)** | **[Jira ticket](https://onrunning.atlassian.net/browse/BAD-290)**

### 💡 **Description**

- Fix `AtmosphericVideo` play/pause button shrinking video to half size on keyboard focus or VoiceOver activation
- Replace `overflow: hidden` with `overflow: clip` on `.atmosphericVideo` in `AtmosphericVideo.scss`
- Root cause: `overflow: hidden` creates a scroll container; browser scrolls clipped container when focus reaches the button
- Single-line CSS fix, no JS or markup changes

### 🎓 **Review Instructions**

1. Tab through the page until you reach the video play/pause button
2. Verify the video does **not** shrink or get cut in half on focus
3. Activate VoiceOver and navigate to the video controls — confirm full dimensions maintained
4. Verify no visual regressions on pages with the previous shadow/ghosting artifacts

| Page | Preview | Staging |
|---|---|---|
| Zendaya | [Preview](https://on-shop-8862.on-running.com/en-ch/collection/zendaya) | [Staging](https://www-staging.on.com/en-ch/collection/zendaya) |
| Cloudmonster Real Energy | [Preview](https://on-shop-8862.on-running.com/en-ch/collection/cloudmonster-real-energy) | [Staging](https://www-staging.on.com/en-ch/collection/cloudmonster-real-energy) |
| Demo Stories | [Preview](https://on-shop-8862.on-running.com/en-ch/stories/demo-stories-page-for-ssr) | [Staging](https://www-staging.on.com/en-ch/stories/demo-stories-page-for-ssr) |

### 🗒️ **Notes**

- Bug affects **all** AtmosphericVideo instances — Reels, Grid, and Billboard contexts
- `overflow: clip` supported in Chrome 90+, Firefox 81+, Safari 16+
- Other a11y issues from BAD-290 tracked separately in BAD-1151 and BAD-1152

### ➕ **Additional Information**

- Refer to our [confluence page](https://onrunning.atlassian.net/wiki/spaces/OT/pages/2509865083/Additional+Information+For+Pull+Requests) for more information relating to pull requests.
```

## Error Handling

### GitHub MCP Not Available
```
The GitHub MCP server is not available. Please ensure:
1. The GitHub Copilot extension is installed
2. You're signed in to GitHub
3. The MCP server is running

Try restarting VS Code or running: gh copilot mcp start github
```

### Invalid PR URL
```
Could not parse the PR URL. Please provide a valid GitHub PR URL in the format:
https://github.com/{owner}/{repo}/pull/{number}
```

### PR Not Found
```
Could not find PR #{number} in {owner}/{repo}. Please verify:
- The PR exists and is not deleted
- You have access to the repository
- The URL is correct
```

### No Write Access
```
Unable to update the PR. You may not have write access to {owner}/{repo}.
Please ensure you have collaborator access or are a maintainer.
```

## Trigger Phrases

- "update pr description"
- "fill in pr description"
- "improve pr description"
- "update this pr" (with URL in context)
- "write pr description"
- "generate pr description"
- "help me with pr description"
- Direct PR URL with context about updating

## Notes

- This skill reads the actual code changes to generate accurate descriptions
- It preserves all existing links (Preview, Jira) and template structure — never deletes pre-generated links
- It never modifies checklist item states
- Screenshots and images are preserved as-is; new ones are embedded inline in Review Instructions
- The skill respects the repository's PR template conventions
- Output density is calibrated to PR scope: small PRs get minimal descriptions, large PRs get structured ones
