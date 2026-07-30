# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Boot: Rails", 'bin/rails runner "puts \"Rails boot: ready\""'
  step "Boot: Zeitwerk", "bin/rails zeitwerk:check"
  step "Test: Rails", "bin/rails test"

  step "Style: Ruby formatting", "bin/format check"
  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Brakeman code analysis",
       "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
end
