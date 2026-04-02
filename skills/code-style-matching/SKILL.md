---
name: code-style-matching
description: Before modifying code, analyze surrounding files to match the project's existing conventions (formatting, patterns, idioms). Use when you need to ensure a code change is stylistically consistent with its neighbors.
---

# Code Style Matching

Ensure any code modification matches the conventions already established in the surrounding codebase. This prevents style drift and reduces review friction.

## When to Use

Invoke this skill before writing or editing code in an unfamiliar area of a project. It is especially useful when:

- Fixing a bug in a component you haven't touched before
- Adding new code next to existing files
- Working in a monorepo where conventions vary between packages

## Workflow

### Step 1: Identify the Target File

Determine the file you are about to modify. Note its package/directory (e.g., `shared/on-ui/src/components/`, `apps/on-shop/pages/`).

### Step 2: Read 3 Neighboring Files

Select 2-3 sibling files in the same directory (or the closest parent directory if there are fewer than 2 siblings). Read them in full.

Look for and record the following conventions:

| Convention | What to Look For |
|---|---|
| Script style | `<script setup lang="ts">` vs `<script lang="ts">` with `defineComponent` |
| Type syntax | `type` aliases vs `interface` declarations |
| Props definition | `defineProps<{}>()` vs `withDefaults(defineProps<>(), {})` |
| Guard clauses | Early returns vs nested conditionals |
| Naming | camelCase vs PascalCase for variables, kebab-case vs PascalCase for file names |
| Imports | Path aliases (`@/`, `@on-ui/`, `~/`) and ordering conventions |
| CSS approach | `<style scoped>`, CSS modules, utility classes, or design tokens |
| Ref patterns | `ref()` vs `shallowRef()`, `computed()` usage |
| Comment style | JSDoc, inline comments, or none |

### Step 3: Summarize Conventions

Produce a short checklist of conventions that your upcoming edit must follow. Example:

```
Conventions for shared/on-ui/src/components/:
- <script setup lang="ts">
- Props via `type` + `defineProps<>()`
- Early-return guard clauses
- Imports: @on-ui alias, no relative parent paths
- <style scoped> with design tokens
```

### Step 4: Apply During Editing

Use this checklist as a constraint when writing or modifying code. If the change would violate a detected convention, adapt the change to match.

## Notes

- If neighboring files are inconsistent with each other, prefer the pattern used by the majority.
- This skill is read-only analysis; it does not modify files itself.
- The conventions checklist should be kept short (5-10 items). Do not catalog every micro-detail.
