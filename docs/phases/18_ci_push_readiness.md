# Phase 18 — Importmap CI executable and push-readiness preflight

## Outcome

Phase 18 corrected the missing Rails Importmap command boundary and validated every command in the checked-in
GitHub Actions workflow. It changed no application behavior and made no QuickBooks request.

## Correction

The workflow and `config/ci.rb` both invoke `bin/importmap audit`, but `bin/importmap` was absent. The installed
`importmap-rails 2.2.3` package supplies a canonical executable that loads the Rails application and Importmap
commands. That exact four-line executable is now present and executable.

The first audit then correctly exposed a second incomplete-installation file: `config/importmap.rb`. This app
loads its own JavaScript through the asset pipeline and has no Importmap-managed npm pins, so the configuration
contains the canonical usage comment and an empty package set. `bin/importmap audit` now reports no vulnerable
packages without inventing an unused application pin.

## Dependency audit correction

The current Bundler Audit database identified patched releases for two transitive HTML sanitization dependencies.
The lockfile was updated narrowly:

| Dependency | Before | Final |
|---|---:|---:|
| `loofah` | 2.25.1 | 2.25.2 |
| `rails-html-sanitizer` | 1.7.0 | 1.7.1 |

No direct dependency, Rails version, or application code changed.

## Final non-test validation

```text
bundle check                       dependencies satisfied
bin/importmap audit                no vulnerable packages found
bin/bundler-audit                  no vulnerabilities found
bin/rubocop -f github              exit 0
bin/brakeman --no-pager            0 errors / 0 security warnings
```

The RuboCop command used the same repository-local cache environment configured by GitHub Actions. The exact
Brakeman wrapper completed its built-in current-version check before scanning.

Automated tests were not created, modified, or run. Production work remains out of scope. `config/master.key`
and `.env*` remain ignored. The source tree is ready for initial review and commit, but Git still has no initial
commit and no remote configured; nothing was staged, committed, or pushed in Phase 18.
