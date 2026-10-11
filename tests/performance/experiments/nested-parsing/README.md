# Nested parsing diagnosis

Baseline: 5856424. Mac16,10, macOS arm64, Node 22.23.2, jsdom, one worker.
The inactive base-markdown-no-nesting route uses markdownLanguage directly,
with the configured Markdown support extensions. Those extensions do not install
a language parser. Only the LanguageSupport language supplies that parser.
The route removes nested code/HTML parsing, including nested syntax trees and
language services. It is not a feature-equivalent replacement for the app.

Order: direct first, base first, base repeat, direct repeat. Each route has
twenty growing Z / 中 edits. All source and complete-decoration comparisons
use that route's fresh builder outside the clock. No sample is removed.
Each run accepts 115 indexed edits and 125 full edits. Parser setup is outside
the clock. First edits and fallback construction remain inside it. No project
tests or builds run during timing. Other apps remain open. Oracle work can
affect later garbage collection. No claim covers DOM or native frames.

The cross-configuration check covers complete Markdown block trees and preview
decorations, including the exact large growth fixtures. It does not claim equal
nested syntax trees or language data. The first large cross-check used the
default five-second test timeout and failed. The retained failure log explains
that limit. The corrected check uses one complete-decoration assertion per pair
and a 120-second limit. No production parser budget is increased.

```sh
MARKBEND_GROWTH_BENCH=1 MARKBEND_DIRECT_MARKDOWN=1 node node_modules/vitest/vitest.mjs run tests/performance/preview-growth.test.ts --pool=threads --maxWorkers=1
MARKBEND_GROWTH_BENCH=1 MARKBEND_BASE_MARKDOWN=1 node node_modules/vitest/vitest.mjs run tests/performance/preview-growth.test.ts --pool=threads --maxWorkers=1
MARKBEND_WRAPPER_CHECK=1 node node_modules/vitest/vitest.mjs run tests/performance/parser-wrapper.test.ts --pool=threads --maxWorkers=1
```

Run processes one at a time. App parsing remains unchanged. A future candidate
must preserve nested parsing for every code and HTML node before it can be used.

guarded.ts is a separate inactive candidate. It weak-caches structural target
presence in Tree and TreeBuffer objects. It omits the package nested pass only
for complete, unstopped, full-input parses with no code or HTML target node.
All other parses use the upstream parseCode wrapper with the original input,
fragments, and ranges. The existing YAML wrapper remains. The candidate uses
only public parser APIs and the configured Markdown language-data facet. The
HTML package is currently a locked transitive dependency; production adoption
would require a direct dependency declaration.

The guard checks cover first-resource insertion/removal, loaded JavaScript,
unknown code, lazy Python loading and a subsequent edit, nested language data,
all five target types in synthetic buffers, structural weak-cache reuse, stopped/partial
parses, and resumed mounted trees. They do not prove every completion service,
native input route, or memory bound. Timing uses the real YAML wrapper. Two
pairs show lower plain 1 MiB medians but mixed p95 and adverse note cases.
Keep this candidate inactive until resource-bearing performance and guard cost
are measured. BENCHMARKS.md retains every route, including adverse results.

```sh
MARKBEND_GUARD_CHECK=1 node node_modules/vitest/vitest.mjs run tests/performance/guarded-nesting.test.ts --pool=threads --maxWorkers=1
MARKBEND_GROWTH_BENCH=1 MARKBEND_GUARDED_NESTING=1 node node_modules/vitest/vitest.mjs run tests/performance/preview-growth.test.ts --pool=threads --maxWorkers=1
```
