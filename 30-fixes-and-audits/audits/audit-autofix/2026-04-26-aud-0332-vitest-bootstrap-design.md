---
status: design-ready-for-implementation
generated: 2026-04-26
authors: claude-orchestrator-via-subagent
audit-id: AUD-0332
tier: T3
unblocks:
  - AUD-0361 Phase 4 (frontend CI gate)
  - ~30 other frontend test/UX audit items
related:
  - AUD-0058 phase-1 (depends on vitest landing first)
  - AUD-0361 (CI/CD — Phase 4 wires `npm test` into ci.yml)
---

# AUD-0332 — Vitest Bootstrap: Design + Phased Plan

> **Documentation only.** This document describes WHAT will ship in each
> phase and WHY. The actual `package.json` change, `vitest.config.ts`, and
> any test-file migrations are deliberately NOT in this commit. Each phase
> below is a separate future commit, pinned for the operator's go-ahead
> before it lands.

## 0. The audit row

```
| AUD-0332 | 12 | Major | Test Gap | Confirmed | frontend/web/ | no vitest/jest
config; no test script | 5 test files exist but no runner configured and no
`"test":` in package.json scripts. | Tests silently rot. | Add vitest +
config + script. | package.json:7-12; no vitest.config.ts. |
```

Bucket — Test Gap, Tier T3 (process / hygiene). Severity Major because every
new frontend audit item that prescribes "add a test" is silently blocked: the
test runner doesn't exist, so any test added today goes into the void. The
existing 5 files prove the failure mode — they were written, committed, and
now sit unused with no signal whether they pass or fail.

## 1. Status quo (verified 2026-04-26 against worktree at `dd77e72b`)

### 1.1 Build system

`frontend/web/` is **Vite-based**: `vite.config.ts` exists at the project
root, the `build` script is `tsc && vite build`, devDependencies include
`vite ^7.2.2` and `@vitejs/plugin-react ^4.2.1`. No Webpack, no
`webpack.config.*`. This makes vitest the natural fit (same Vite resolver,
same plugin chain, same TS handling — no need for a parallel babel/ts-jest
toolchain).

### 1.2 `package.json` scripts and deps

`frontend/web/package.json` (47 lines, current contents):

```json
"scripts": {
  "dev": "vite",
  "build": "tsc && vite build",
  "preview": "vite preview",
  "lint": "eslint . --ext ts,tsx --report-unused-disable-directives --max-warnings 0",
  "screenshot": "node ./scripts/screenshot.js"
}
```

No `"test"` script. Confirmed. Audit row is correct.

devDependencies of note:

| Package | Version | Relevance |
|---|---|---|
| `vite` | ^7.2.2 | Build system — vitest piggybacks on it. |
| `@vitejs/plugin-react` | ^4.2.1 | React JSX/Fast-Refresh — also picked up by vitest. |
| `@playwright/test` | ^1.57.0 | E2E runner; orthogonal to unit tests. |
| `@types/jest` | ^30.0.0 | **Surprise:** jest types installed but jest itself is NOT — see §1.4. |
| `typescript` | ^5.2.2 | TS compiler. |

Production deps (react, axios, zustand, react-router-dom, react-query etc.)
are stable at common versions; nothing exotic.

### 1.3 No test runner config exists

```
$ find frontend/web -maxdepth 3 -type f \( -name "vitest.config*" -o -name "jest.config*" \) -not -path "*/node_modules/*"
(no results)
```

Only `vite.config.ts` (the build config, no `test:` block).

### 1.4 The 5 existing test files (the load-bearing investigation)

```
frontend/web/src/lib/__tests__/vwap-calculator.test.ts
frontend/web/src/lib/__tests__/projection-engine.test.ts
frontend/web/src/lib/__tests__/ideas-url-params.test.ts
frontend/web/src/pages/__tests__/smart-trade.test.ts
frontend/web/src/components/journal/__tests__/waep-snapping.test.ts
```

All co-located with the code they test in `__tests__/` folders. All `.ts`
(no `.tsx` — they test pure logic, not React components). All currently
**excluded from the production tsc build** by `tsconfig.json:24` —

```json
"exclude": ["src/**/__tests__/**", "src/**/*.test.ts", "src/**/*.test.tsx"]
```

— which means today's `npm run build` never type-checks them. That's an
extra silent-rot vector to fix at the same time (see Phase 1).

**Framework shape per file:**

| File | Imports `from 'vitest'`? | Uses globals? | Verdict |
|---|---|---|---|
| `vwap-calculator.test.ts` | yes (line 8) | — | vitest-shaped already |
| `projection-engine.test.ts` | yes (line 1) | — | vitest-shaped already |
| `ideas-url-params.test.ts` | yes (line 5) | — | vitest-shaped already |
| `smart-trade.test.ts` | no | `describe`/`it`/`expect` global (line 114+) | works under vitest globals OR jest globals |
| `waep-snapping.test.ts` | no | `describe`/`it`/`expect` global (line 43+) | works under vitest globals OR jest globals |

**Key finding:** three of five files **already import from `vitest`**, which
strongly suggests vitest was once the intended runner — somebody started the
migration, wrote the tests, and never landed the config. The remaining two
use globals and so are framework-agnostic; they will work under vitest with
`globals: true` set in the config (or under jest with no change).

The presence of `@types/jest` in devDependencies is misleading — it was
likely added to satisfy editor IntelliSense for the global-style tests
(`describe`/`it`/`expect` show as types from `@types/jest`). It's not
load-bearing for actually running anything. Phase 2 should evaluate
removing it once `vitest/globals` types are wired up.

### 1.5 No test utilities for React components

No `@testing-library/react`, no `@testing-library/jest-dom`, no `msw`, no
`jsdom`, no `happy-dom`. The 5 existing tests are all pure-logic and need
none of these — but the moment a test wants to render a component
(`<JournalRow />`, `<SmartTrade />`), one of `jsdom`/`happy-dom` plus
`@testing-library/react` becomes mandatory. Phase 1 installs them so the
first audit-driven component test lands without an extra setup commit.

## 2. Why vitest (not jest, not raw `node --test`)

| Criterion | vitest | jest | node:test |
|---|---|---|---|
| Native Vite integration | yes — same resolver, same plugins, same TS/JSX handling out of the box | no — needs `ts-jest` or babel-jest, separate transform pipeline, separate moduleNameMapper for `@/` alias | no — needs custom TS loader |
| ESM-first | yes (project is `"type": "module"`) | painful — jest is CJS-first; ESM support exists but is gated behind flags and known sharp edges | yes |
| Existing tests' import statements | three already write `import { describe, it, expect } from 'vitest'` — would work unmodified | would require rewriting those imports OR a shim | wouldn't work — `node:test` has different API |
| `@/` path alias | inherited from `vite.config.ts` automatically | needs `moduleNameMapper` in jest config, kept in sync manually | needs custom resolver |
| Speed | esbuild backend, near-instant cold start; watch mode HMR-fast | acceptable but slower; slow cold start | fast but bare-bones |
| React Testing Library compatibility | excellent (drop-in) | excellent (canonical home) | poor — needs custom DOM setup |
| `--watch`, `--ui`, `--coverage` | yes, all built-in (`@vitest/ui`, c8 coverage) | yes (separate `--coverage` flag) | partial |
| Migration path from "no tests" | smallest — only `package.json` + `vitest.config.ts` change | larger — jest config + transform config + alias config | smallest, but ergonomic ceiling is low |

**Decision:** vitest. Rationale chain — Vite-native build means zero
parallel toolchain; existing tests already vitest-shaped means zero rewrite
for 3/5 files; `"type": "module"` means jest's CJS friction would surface;
React Testing Library compatibility is required for any future component
test. No serious counter-argument.

## 3. Phased plan

### Phase 1 — Bootstrap vitest (4-6h, medium risk, reversible)

**Deliverables:**

1. `frontend/web/package.json` — add devDependencies:
   - `vitest` (latest 1.x — pin to a specific minor at install time)
   - `@vitest/ui` (browser test runner UI; optional but useful for dev loop)
   - `@testing-library/react`
   - `@testing-library/jest-dom` (custom matchers — `toBeInTheDocument`,
     `toHaveClass`, etc.; works under vitest via `expect.extend`)
   - `jsdom` (DOM implementation; see §5 for jsdom-vs-happy-dom decision)
   - `@vitest/coverage-v8` (coverage reporter — V8 backend, no Babel
     instrumentation needed)

2. `frontend/web/package.json` — add scripts:
   ```json
   "test": "vitest run",
   "test:watch": "vitest",
   "test:ui": "vitest --ui",
   "test:coverage": "vitest run --coverage"
   ```
   The bare `test` is `vitest run` (single-shot, exits on completion) so it's
   safe to invoke from CI/scripts. `test:watch` is the dev-loop default.

3. `frontend/web/vitest.config.ts` — new file at project root:
   ```ts
   import { defineConfig, mergeConfig } from 'vitest/config'
   import viteConfig from './vite.config'

   export default mergeConfig(viteConfig, defineConfig({
     test: {
       globals: true,                    // describe/it/expect available without import
       environment: 'jsdom',             // DOM globals for component tests
       setupFiles: ['./src/test-setup.ts'],
       include: ['src/**/*.{test,spec}.{ts,tsx}'],
       coverage: {
         provider: 'v8',
         reporter: ['text', 'html'],
         exclude: ['node_modules/', 'src/**/*.test.*', 'src/**/__tests__/**'],
       },
     },
   }))
   ```
   `mergeConfig(viteConfig, ...)` is the canonical way to inherit the `@/`
   alias and the React plugin from `vite.config.ts` without restating them.

4. `frontend/web/src/test-setup.ts` — new file:
   ```ts
   import '@testing-library/jest-dom/vitest'
   ```
   Wires the `@testing-library/jest-dom` matchers into vitest's `expect`.
   Currently a one-liner; will grow if global mocks become useful.

5. `frontend/web/tsconfig.json` — drop the `__tests__` exclusion now that
   they're real source files the runner type-checks. Add `vitest/globals`
   to `compilerOptions.types` so that the global `describe`/`it`/`expect`
   in `smart-trade.test.ts` and `waep-snapping.test.ts` resolve under TS:
   ```json
   "types": ["vitest/globals", "@testing-library/jest-dom"]
   ```
   Removes the silent-rot vector where today's tsc never sees the test
   files at all.

6. **Verify the 5 existing test files RUN.** Expected outcomes per file
   (see §1.4 framework table):
   - `vwap-calculator.test.ts` — runs as-is, vitest-import is idiomatic.
   - `projection-engine.test.ts` — runs as-is.
   - `ideas-url-params.test.ts` — runs as-is.
   - `smart-trade.test.ts` — runs under `globals: true` without modification.
   - `waep-snapping.test.ts` — runs under `globals: true` without modification.

   If any test fails on first run, that's a real bug surfaced by enabling
   the runner — Phase 1 records the failures, Phase 2 (or a follow-up
   audit row) decides whether to fix the test or fix the production code.

**Rollback:** revert the commit. No production code paths touched.

**Risk:** medium. The only realistic risk is the bare-globals tests not
type-checking until `vitest/globals` is in tsconfig types. Confirmed
mitigation above. Secondary risk: `jsdom` vs `happy-dom` mismatch surfacing
in a yet-to-be-written component test — but no component tests exist today,
so this is deferred.

**Effort:** 4-6h, dominated by `npm install`, dependency-version
compatibility checks, running the 5 tests, and reading any failure output.

### Phase 2 — Migrate / clean up the 5 existing tests (1-2h, low risk)

If §1.4 was right and 3/5 already import from `vitest` and 2/5 work under
`globals: true`, **this phase is a no-op for green-field migration** —
which is the most likely outcome.

If Phase 1 surfaces real failures, this phase handles them, with these
rules:

- For each failing test, decide: **bug in test** (e.g. relies on jest-only
  API like `jest.useFakeTimers()`) or **bug in production code** (the test
  was right; somebody broke the underlying function and nobody noticed
  because the runner wasn't wired up).
- For test bugs: replace `jest.fn()` → `vi.fn()`, `jest.mock()` →
  `vi.mock()`, `jest.useFakeTimers()` → `vi.useFakeTimers()`. The vitest
  `vi` namespace is a near-superset of `jest`.
- For production bugs: file as separate audit rows; do NOT bundle the fix
  with the bootstrap commit.
- Remove `@types/jest` from devDependencies once the global-style tests
  type-check via `vitest/globals` instead. Verify in IDE that
  `describe`/`it`/`expect` still resolve to the right types.

**Effort:** 1-2h if anything needs touching, ~0h if not.

### Phase 3 — CI integration (blocked on AUD-0361 Phase 2)

When AUD-0361 Phase 2 lands `.github/workflows/ci.yml` with the existing
backend `lint` / `test-unit` / `test-integration` / `schema-sync` jobs, add
a sibling `test-frontend` job:

```yaml
test-frontend:
  runs-on: ubuntu-latest
  defaults:
    run:
      working-directory: tradelens/frontend/web
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: '20'
        cache: 'npm'
        cache-dependency-path: tradelens/frontend/web/package-lock.json
    - run: npm ci
    - run: npm test
```

The `working-directory` default is required because the Vite project lives
in a subdirectory of the monorepo. `npm ci` (not `npm install`) for
reproducible installs; `npm test` runs `vitest run` from Phase 1's script.

Add `test-frontend` to the required-status-checks list when AUD-0361 Phase
3 (branch protection) lands. Until then, the job runs informationally on
PRs but doesn't block merge.

**Blocked on:** AUD-0361 Phase 2 (the ci.yml file itself doesn't exist
yet). Tracked as AUD-0361 Phase 4 in that doc.

**Effort:** 1h (add the job stanza, verify it runs green on a no-op PR).

### Phase 4 — Coverage threshold (deferred indefinitely)

Once the test population grows past trivial (more than 5 files, ideally
post-AUD-0058 phase-1 which will add a substantial unit-test batch for
`initial_risk_calculator.py` math splits), set a coverage floor in
`vitest.config.ts`:

```ts
coverage: {
  thresholds: {
    lines: 50,         // start lenient — existing baseline is ~5%
    functions: 50,
    branches: 40,
    statements: 50,
  },
},
```

**Do NOT gate PRs on this.** A coverage gate that fails on the first PR
adding test-free code creates pressure to write low-quality tests just to
meet the number. Use it as a tracking metric only (visible in CI output)
until the trajectory is healthy. Revisit gating once coverage stabilises
above 60-70% organically.

**Effort:** 0.5h. Pinned for explicit operator decision.

## 4. Risks

1. **Existing tests' framework assumptions.** Mitigated by §1.4
   investigation: 3/5 already vitest-shaped, 2/5 globals-shaped (work under
   `globals: true`). Worst case a `jest.X` call slips into Phase 1 and
   needs the §3 Phase 2 rewrite — bounded ~1h.

2. **`node_modules` size.** Adding vitest + jsdom + @testing-library/* +
   @vitest/coverage-v8 grows `node_modules` by an estimated **~50-80 MB
   on disk** (vitest itself is small; jsdom is ~30 MB of the increase; the
   rest is small). `package-lock.json` will gain ~200-400 lines. Not
   meaningful on dev machines or CI; flagged for completeness.

3. **Vitest's ESM-by-default may break some CommonJS test imports.** Low
   risk in this project — `package.json:5` is `"type": "module"`, so the
   project is already ESM-native. Production imports use ESM throughout.
   No CJS-only test imports were spotted in §1.4.

4. **`jsdom` vs `happy-dom` mismatch.** Picked jsdom (default) for
   compatibility; happy-dom is faster but has occasional gaps in DOM API
   coverage. If a future component test hits a jsdom-specific bug, swap is
   a one-line config change.

5. **`@types/jest` removal could break IDE type resolution** for the two
   global-style tests during the brief window between adding `vitest`
   types and removing `@types/jest`. Safe ordering: in Phase 1, ADD
   `vitest/globals` to tsconfig types FIRST, run tsc to confirm, THEN
   schedule `@types/jest` removal in Phase 2. Don't combine in one commit.

6. **Coverage provider choice.** v8-based provider (`@vitest/coverage-v8`)
   is fast and accurate for V8 environments but produces slightly
   different numbers than istanbul-based instrumentation. If parity with
   any external coverage report is needed, swap to
   `@vitest/coverage-istanbul`. Default to v8 — no current external
   integration to match.

## 5. Open questions (need operator input before Phase 1 lands)

1. **jsdom vs happy-dom?** jsdom is the default in vitest docs and the
   most-compatible choice; happy-dom is ~2-3× faster startup but has
   occasional gaps (e.g. some `getBoundingClientRect` semantics, some
   CSS pseudo-class handling). **Recommendation: jsdom.** Compatibility
   matters more than speed at this volume.

2. **Are the existing 5 tests actively maintained or vestigial?** Check
   `git log -- src/**/__tests__/**` — if last touched > 6 months ago and
   the underlying production code has since been rewritten, the tests
   may already be silently broken. If vestigial, Phase 1 deletes them
   and starts fresh; if active, Phase 1 keeps them and surfaces any
   failures. **Default: keep them, surface failures, decide per-file.**

3. **`msw` (Mock Service Worker) for HTTP mocking, now or later?** Not
   needed for the existing 5 pure-logic tests. Adding it now means an
   additional ~5 MB devDep and one more setup file; deferring means the
   first HTTP-mocking component test triggers a follow-up commit.
   **Recommendation: defer.** Add when the first test needs it.

4. **Pin vitest to a specific minor or accept `^1.x`?** Caret-ranged for
   parity with the rest of `package.json`. Pinning major+minor (`~1.6.0`)
   is more reproducible but creates manual upgrade work. **Recommendation:
   caret-range, same as everything else in this file.**

5. **Where do the screenshot helper script and Playwright e2e fit?** Out
   of scope for this audit row — `@playwright/test` already in
   devDependencies serves a different purpose (full E2E). vitest is for
   unit/integration; playwright is for E2E. They coexist with no
   conflict. **No change needed.**

6. **Should `npm test` exit non-zero when no tests match?** Vitest default:
   no (passes silently). Recommendation: enable
   `passWithNoTests: false` so CI catches the case where the include
   pattern is wrong and silently runs zero tests. **Recommendation: set
   `passWithNoTests: false` in `vitest.config.ts`.**

7. **Does Phase 1 also re-enable `__tests__/**` in tsconfig.json's
   `include`?** Yes — see Phase 1 deliverable #5. Without this, tsc
   ignores test files and TS errors in tests don't surface during
   `npm run build`. **Confirmed: drop the exclusion.**

## 6. Acceptance criteria

Phase 1 ships when ALL of:

- [ ] `cd tradelens/frontend/web && npm test` exits 0 when all tests pass.
- [ ] `cd tradelens/frontend/web && npm test` exits non-zero when any
      single assertion fails (verified by deliberately introducing a
      `expect(true).toBe(false)` in a scratch test, running, observing
      failure, then removing).
- [ ] All 5 existing test files are reported in the runner output (no
      silent skips). At least 4 of 5 pass; any failure is documented and
      ticketed (Phase 2 or a separate audit row).
- [ ] `npm run build` still passes (tsc no longer skips
      `__tests__/**`, so any TS error in a test now surfaces; tests must
      be valid TS).
- [ ] `npm run lint` still passes (eslint config didn't break).
- [ ] No production code (`src/**/*.{ts,tsx}` outside `__tests__/`)
      changed in the Phase 1 commit.

Phase 2 ships when:

- [ ] `@types/jest` is removed from devDependencies.
- [ ] All 5 existing tests pass.
- [ ] No `jest.X` references remain in test files (sanity grep).

Phase 3 ships when:

- [ ] AUD-0361 Phase 2 has landed (`.github/workflows/ci.yml` exists).
- [ ] `test-frontend` job runs green on a no-op PR.

Phase 4 ships only on explicit operator request.

## 7. Sequencing relative to other audit items

- **Unblocks AUD-0361 Phase 4.** AUD-0361's frontend gate is a no-op
  until vitest exists. Land AUD-0332 Phase 1 first; AUD-0361 Phase 4 is a
  near-trivial follow-up.
- **Unblocks AUD-0058 phase-1.** That audit splits a 1,781-line file into
  `queries.py` / `math.py` / `writeback.py` and adds unit tests for the
  math half. The Python-side tests run under existing pytest, but if any
  of the math is reproduced in TS (e.g. for client-side projection), the
  TS tests need vitest. Land AUD-0332 Phase 1 first to be safe.
- **Unblocks ~30 frontend T2/T3 audit items** that prescribe "add a test
  for X". All of those are silently wedged today.
- **Independent of AUD-0353/0354** (security runbook), AUD-0357 (forward
  migration policy), AUD-0228/0229 (data-shape audits) — different
  surfaces.

---

**Status:** design ready for implementation. Phase 1 commit pending
operator go-ahead. No code changes in this commit.
