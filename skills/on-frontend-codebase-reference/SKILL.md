---
name: on-frontend-codebase-reference
description: Reference guide for the on-frontend monorepo — architecture, component conventions, a11y infrastructure, data flow patterns, and key file paths. Load this skill when you need to orient yourself in the OnRunning frontend codebase before making changes.
---

# on-frontend Codebase Reference

Quick-reference for any agent or skill operating inside the OnRunning frontend monorepo.

---

## 1. Monorepo Layout

```
on-frontend/
├── apps/
│   ├── on-shop/              # Nuxt 4 e-commerce app (SSR)
│   └── on-contentful-fields/ # Contentful custom fields app
├── shared/
│   ├── on-ui/    # @onrunning/on-ui  — Shared Vue 3 UI component library (atomic design)
│   ├── on-store/ # @onrunning/on-store — State management, composables, GraphQL fragments
│   ├── on-utils/ # @onrunning/on-utils — General utilities
│   ├── on-locale/ # @onrunning/on-locale — Localization / i18n
│   └── on-cli/   # @onrunning/on-cli — Internal CLI tooling
├── nx.json               # Nx 21 workspace config
├── package.json          # Yarn 1 (classic) workspaces
├── eslint.common.js      # Shared ESLint config (including a11y plugin)
└── .prettierrc
```

**Dependency graph (leaves first):**

```
on-utils (no deps)
  └─> on-locale
        └─> on-store
on-ui (depends on on-utils only)
on-shop (depends on all four shared packages)
```

**Import rules:**
- `apps/on-shop` uses `@/` alias.
- `shared/on-ui` uses `@on-ui` alias and may only import from `@onrunning/utils`.
- NO cross-imports between `on-ui`, `on-store`, or `on-locale`.

---

## 2. Component Conventions

### on-ui (shared library) — Atomic Design

```
shared/on-ui/src/components/
├── atoms/       # 29 components (Button, Input, Checkbox, BaseImage, Logo, ...)
├── molecules/   # 45 components (Accordion, Look, MiniProductCard, ImageWithFallback, ...)
├── organisms/   # 14 components (ProductCard, Footer, Billboard, LookBook, ...)
└── animations/  # Visual animations (Ripples, Spheres, Bubbles, ...)
```

### Typical component folder

```
atoms/Button/
├── Button.vue          # Vue SFC — <script setup lang="ts"> + CSS Modules
├── Button.scss         # Extracted SCSS styles
├── Button.spec.ts      # Co-located unit test (Vitest)
├── Button.stories.ts   # Co-located Storybook story
├── models.ts           # TypeScript types/interfaces/enums (sometimes types.ts)
└── index.ts            # Barrel export
```

### on-shop (app-level) components

```
apps/on-shop/components/ComponentName/
├── ComponentName.vue
├── ComponentName.scss
├── ComponentName.spec.ts
├── ComponentName.stories.ts
├── constants.ts / utils.ts / utils.spec.ts  (optional)
└── SubComponent/                             (optional nested)
```

### File conventions

| Convention | Pattern |
|---|---|
| Vue SFCs | `<script setup lang="ts">`, Composition API |
| Styles | CSS Modules via `<style lang="scss" module>` + `useCssModule()` |
| Naming | PascalCase for components and files |
| Tests | `*.spec.ts` co-located (NEVER `.test.ts`) |
| A11y tests | `*.accessibility.spec.ts` co-located |
| Stories | `*.stories.ts` co-located |
| Exports | Barrel `index.ts` per component |
| Types | `models.ts` or `types.ts` per component |

### Code style

- **Prettier:** single quotes, no semicolons, trailing commas (es5), 100 char width, no parens on single arrow params.
- **TypeScript:** strict mode, `type` for props (not `interface`), no `any`, no postfix `!`.

---

## 3. A11y Infrastructure

### Static analysis

- **`eslint-plugin-vuejs-accessibility`** `flat/recommended` preset applied to ALL Vue files in both `on-shop` and `on-ui` (configured in `eslint.common.js`).
- One override: `vuejs-accessibility/label-has-for` relaxed to accept either nesting OR `for`/`id` (not both).

### Existing ARIA patterns in on-ui

| Pattern | Usage | Example |
|---|---|---|
| `aria-label` | 64+ usages — buttons, links, navs, modals, carousels, inputs | Typically passed as props: `:aria-label="ariaLabel"` |
| `aria-hidden` | 46+ usages — decorative SVGs, icons, spinners, images without alt | `aria-hidden="true"` on SVG icons in buttons |
| `aria-live` | 37+ usages — status updates, errors, loading states | `aria-live="polite"` for cart totals; `aria-live="assertive"` for errors |
| `role` | 59+ usages — dialog, tab/tablist/tabpanel, alert, status, presentation, listbox/option | `role="presentation"` for decorative elements |
| `srOnly` | 18+ usages — visually hidden but accessible content | Global CSS class for screen-reader-only text |
| `inert` | Used in navigation to disable background content when overlays are open | `NavigationA11yBoundary.vue` |

### Key a11y components and composables

| File | Purpose |
|---|---|
| `apps/on-shop/components/TopNavigation/common/NavigationA11yBoundary.vue` | Uses `inert` to disable background content behind nav overlays |
| `apps/on-shop/components/TopNavigation/common/NavigationA11yEscapeHint.vue` | `srOnly` span with Escape key instructions |
| `apps/on-shop/components/TopNavigation/common/useNavigationLinkA11y.ts` | `aria-current="page"` computation + Space key activation for links |
| `apps/on-shop/components/TopNavigation/common/useNavigationTabA11yAttrs.ts` | Provides `role="tab"`, `tabindex`, `aria-controls`, `aria-expanded`, `aria-describedby` |

### Decorative image pattern (BaseImage)

The shared `BaseImage` atom (`shared/on-ui/src/components/atoms/BaseImage/BaseImage.vue`) has built-in decorative handling:

```html
<img :aria-hidden="!alt" :alt="alt || ''" ... />
```

- If `alt` is empty/undefined: image gets `alt=""` + `aria-hidden="true"` (correctly decorative).
- If `alt` has a value: image is exposed to screen readers.
- `ImageWithFallback` wraps `BaseImage` and passes through the same `alt` prop.

### CMS image model

Contentful images come through the `EnrichedAsset` GraphQL fragment (`shared/on-store/src/api/_fragments/contentTypes/EnrichedAsset.gql`), which includes an `altText` field. Components that pass this `altText` to `BaseImage`'s `alt` prop get correct decorative/informative behavior automatically.

---

## 4. Data Flow Patterns

### Contentful -> Component pipeline

```
Contentful CMS
  -> GraphQL fragments (shared/on-store/src/api/_fragments/)
    -> Composables (apps/on-shop/composables/)
      -> Transform functions (e.g., transformProductsData/utils.ts)
        -> Component props
```

**Key insight:** Data available in the GraphQL fragment or transform function may NOT reach the component if the intermediate composable drops it. Always trace the full pipeline when a fix requires data that "should" be available.

### GraphQL fragment locations

```
shared/on-store/src/api/_fragments/
├── contentTypes/   # EnrichedAsset.gql, Look.gql, Product.gql, ...
└── blocks/         # BlockShortStory.gql, BlockCarousel.gql, ...
```

---

## 5. Testing Conventions

### General test setup

- **Runner:** Vitest 4 with `globals: true` (auto-imports `describe`, `it`, `expect`, `vi`, `beforeEach`, `afterEach`). NEVER import these from `'vitest'` — only types like `MockInstance` should be imported.
- **on-shop:** Uses `@nuxt/test-utils/config`, jsdom, forked pool.
- **on-ui:** Uses standard Vite `defineConfig`, jsdom, `@vue/test-utils`.
- **Setup files:** Each package has `vitest-setup.ts` mocking `IntersectionObserver`, `matchMedia`, `scrollTo`, etc.

### A11y test boilerplate (`*.accessibility.spec.ts`)

Only 2 files exist currently (both for TopNavigation). The established pattern:

```typescript
import { mount, type VueWrapper } from '@vue/test-utils'
import type { AxeMatchers } from 'vitest-axe'
import * as matchers from 'vitest-axe/matchers'
import { axe } from 'vitest-axe'

declare module 'vitest' {
  interface Assertion<T> extends AxeMatchers {}
  interface AsymmetricMatchersContaining extends AxeMatchers {}
}

expect.extend(matchers)

// Factory function mounts component with attachTo: document.body
// Stubs must preserve ARIA attributes to avoid false axe violations
// RouterLink/NuxtLink stubbed as accessible <a> elements

describe('ComponentName accessibility', () => {
  describe('axe-core accessibility audit', () => {
    it('should have no accessibility violations', async () => {
      wrapper = factory()
      const results = await axe(wrapper.element)
      expect(results).toHaveNoViolations()
    })
  })

  describe('specific WCAG criteria', () => {
    it('should pass targeted rules', async () => {
      const results = await axe(wrapper.element, {
        runOnly: { type: 'rule', values: ['button-name', 'link-name'] },
      })
      expect(results).toHaveNoViolations()
    })
  })
})
```

**Critical details:**
- `attachTo: document.body` is REQUIRED for axe to run.
- Stubs for visual-only components should still render valid HTML (avoid `<div>` stubs for `<a>` elements).
- Reference files: `apps/on-shop/components/TopNavigation/desktop/DesktopNavigation.accessibility.spec.ts` and `mobile/MobileNavigation.accessibility.spec.ts`.

---

## 6. Git & PR Conventions

| Convention | Pattern |
|---|---|
| Branch naming | `<PROJECT>-<TICKET>-kebab-description` (e.g., `BAD-281-look-duplicate-aria-labels`) |
| Commit messages | Imperative mood, lowercase, no ticket numbers, no period (e.g., `fix: add color to look product aria-labels`) |
| Commit types | `fix`, `feat`, `refactor`, `test`, `docs`, `chore` |
| PR template sections | `Description`, `Review Instructions`, `Notes`, `Additional Information` |
| PR format | Always created as **draft**; author promotes to ready manually |
| Jira linking | Automated via `onrunning/jira-pr-action@v1` — detects ticket IDs in branch names |

---

## 7. Nx Commands Quick Reference

```bash
# Lint a project
nx run <project>:lint

# Type-check
nx run <project>:check-types

# Run tests (single run, no watch)
nx run <project>:test:once

# Update snapshots for a shard
nx affected --target=test:once --shard=<N/TOTAL> --exclude=on-contentful-fields --updateSnapshot

# Build
nx run <project>:build
```

Projects: `on-shop`, `on-ui`, `on-store`, `on-utils`, `on-locale`, `on-cli`, `on-contentful-fields`.
