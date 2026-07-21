# Phase 19 — Deterministic Ruby formatting

## Outcome

Phase 19 adds one dedicated Ruby formatter, applies it to every supported repository source file, reconciles its
ownership with Rails Omakase, and enforces the result in local and GitHub CI. Application behavior, QuickBooks
data, database schema, and non-Ruby assets are unchanged.

## Tooling boundary

`syntax_tree 6.3.0` is installed only for development. `.streerc` fixes the print width at 100. The executable
`bin/format` supports two commands:

```bash
bin/format write
bin/format check
```

The wrapper covers application/configuration Ruby, migrations, seeds, every Ruby-shebang binstub, `Gemfile`,
`Rakefile`, and `config.ru`. It currently evaluates 146 files. It intentionally excludes generated
`db/schema.rb`, automated tests, credentials, and non-Ruby file formats.

## Formatter and linter ownership

`.rubocop.yml` inherits Syntax Tree's official compatibility configuration and Rails Omakase. Syntax Tree owns
layout and deterministic rewriting. RuboCop retains the remaining Omakase rules, including double-quoted Ruby
strings. The shared RuboCop line limit is 140 because four existing database constraint strings cannot be split
by an AST formatter; all other layout remains governed by the 100-column formatter width.

`bin/format check` now runs before RuboCop in both `.github/workflows/ci.yml` and `config/ci.rb`.

## Applied formatting

The first dry check identified 98 files requiring deterministic formatting: 85 application files, six
migrations, two Ruby binstubs, four configuration files, and `Gemfile`. Syntax Tree rewrote those files and a
second full pass made no changes. The formatter also parsed every already-compliant source in its 146-file
scope.

Four generated-style root routes were expressed with the equivalent modern `to:`/`as:` DSL before the final
pass so the formatter did not leave mixed hash-rocket syntax. Route loading confirmed the public route surface
remained intact.

## Final non-test validation

```text
bundle check                 dependencies satisfied
bin/format check             146 files matched expected format
RuboCop                      135 files / no offenses
Rails Zeitwerk               eager load passed
database                     all 6 migrations up
Rails routes                 loaded successfully; QuickBooks/API routes preserved
Bundler Audit                no vulnerabilities found
Importmap Audit              no vulnerable packages found
Brakeman                     0 errors / 0 security warnings
```

Automated tests were not created, modified, or run. No Rails server was started, no QuickBooks request was made,
and nothing was staged, committed, or pushed.
