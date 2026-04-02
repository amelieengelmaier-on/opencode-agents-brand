---
name: nx-monorepo-verification
description: Run a multi-layer verification pipeline for an Nx monorepo change (lint, types, unit tests, optional a11y spec generation, visual screenshot). Use after modifying code to verify nothing is broken before committing.
---

# Nx Monorepo Verification

Run a structured verification pipeline against a changed project in an Nx monorepo. Catches lint errors, type errors, and test failures before the change leaves your machine.

## When to Use

Invoke this skill after making code changes and before committing. It applies to any Nx-managed monorepo using TypeScript.

## Prerequisites

- The project name must be known (e.g., `on-shop`, `on-ui`).
- The workspace must have Nx installed and configured.

## Workflow

### Step 1: Static Analysis (Lint)

Run the project's lint target:

```bash
nx run <project>:lint
```

This typically covers ESLint (including any framework-specific plugins like `eslint-plugin-vuejs-accessibility`) and Stylelint if configured.

**On failure:** Read the error output, apply a targeted fix, and re-run. Maximum 3 attempts before escalating to the user.

### Step 2: Type Checking

Run the project's type-check command. The exact command depends on the project setup:

```bash
# Common patterns — use whichever is configured:
nx run <project>:check-types
# or, if a workspace-level script exists:
yarn <project> check-types
```

**On failure:** Read the diagnostic, fix the type error, and re-run. Maximum 3 attempts.

### Step 3: Unit Tests

Run the project's test suite:

```bash
nx run <project>:test:once
```

Use the `:once` target (or equivalent single-run flag) to avoid watch mode.

**On failure:** Analyze the failing test.

- **Snapshot mismatch:** If the failure is caused by outdated snapshots (e.g., `toMatchSnapshot` / `toMatchInlineSnapshot` assertion errors), automatically update them by re-running the failing shard with the `--updateSnapshot` flag:
  ```bash
  nx affected --target=test:once --shard=<CURRENT_SHARD> --exclude=on-contentful-fields --updateSnapshot
  ```
  Replace `<CURRENT_SHARD>` with the shard identifier from the failed run (e.g., `1/3`). After updating, re-run the original test command to confirm the snapshot update resolved the failure. If it still fails, treat it as a genuine test failure.
- **Genuine test failure caused by your change:** Fix the code or test and re-run.
- **Pre-existing failure unrelated to your change:** Note it and continue.

### Step 4: Accessibility Spec (Optional)

If the change involves a UI component and no `<Name>.accessibility.spec.ts` file exists alongside the component, **and** the calling agent has indicated that a11y spec generation is desired:

1. Create `<ComponentName>.accessibility.spec.ts` co-located with the component file.
2. Follow the established boilerplate pattern used in the codebase:

```typescript
import { mount, type VueWrapper } from '@vue/test-utils'
import type { AxeMatchers } from 'vitest-axe'
import * as matchers from 'vitest-axe/matchers'
import { axe } from 'vitest-axe'

// Type augmentation for vitest-axe matchers
declare module 'vitest' {
  interface Assertion<T> extends AxeMatchers {}
  interface AsymmetricMatchersContaining extends AxeMatchers {}
}

expect.extend(matchers)

// NOTE: Do NOT import describe, it, expect, vi, beforeEach, afterEach from 'vitest'.
// They are auto-imported via globals: true in the vitest config.

describe('ComponentName accessibility', () => {
  let wrapper: VueWrapper

  afterEach(() => {
    wrapper?.unmount()
  })

  describe('axe-core accessibility audit', () => {
    it('should have no accessibility violations', async () => {
      wrapper = mount(ComponentName, {
        attachTo: document.body,  // REQUIRED for axe to run
        // Stubs must preserve ARIA attributes — avoid generic <div> stubs for <a>/<button>
      })
      const results = await axe(wrapper.element)
      expect(results).toHaveNoViolations()
    })
  })
})
```

**Critical details:**
- `attachTo: document.body` is required or axe will not run.
- Stubs for interactive elements (RouterLink, NuxtLink) must render as accessible HTML (e.g., `<a>` tags), not generic `<div>` stubs.
- Reference existing examples: `apps/on-shop/components/TopNavigation/desktop/DesktopNavigation.accessibility.spec.ts` and `mobile/MobileNavigation.accessibility.spec.ts`.

3. Run the spec to confirm it passes. If it fails due to pre-existing violations unrelated to the current change, note them but do not block.

Skip this step if an accessibility spec already exists, the change is not UI-related, or the calling agent has not requested a11y spec generation.

### Step 5: Visual Verification (Optional)

If a browser-based MCP tool is available (e.g., Chrome DevTools MCP, Playwright MCP):

1. Navigate to a page or Storybook story that renders the changed component.
2. Capture a screenshot and present it to the user for visual confirmation.

Skip this step if no browser MCP is configured or the change has no visual impact.

### Step 6: Report Results

Summarize the verification outcome:

```
Verification results for <project>:
  Lint:      PASS
  Types:     PASS
  Tests:     PASS (42 passed, 0 failed)
  A11y Spec: GENERATED + PASS
  Visual:    Screenshot captured
```

If any step failed after retries, clearly list the unresolved errors so the user or calling agent can decide how to proceed.

## Error Handling

- **Max retries per step:** 3 automatic fix attempts. After that, stop and report.
- **Unrelated failures:** If a test failure is clearly pre-existing (not caused by your change), document it but do not block the pipeline.
- **Missing targets:** If a lint/test/type-check target does not exist for the project, skip that step and note it in the report.

## Notes

- This skill does not commit or push code. It only verifies.
- The step order matters: lint before types before tests, so cheaper checks fail fast.
- Adapt the exact commands to whatever the workspace has configured. The commands above are common patterns, not hard requirements.
