# Releasing dfe-wizard

## How this gem is distributed

**Via GitHub tags, not RubyGems.** DfE has no RubyGems account, so consumers
install from git:

```ruby
gem 'dfe-wizard', require: 'dfe/wizard', github: 'DFE-Digital/dfe-wizard', tag: 'v1.0.0'
```

Bundler clones the repo, resolves the tag to a commit SHA, records **both** in
the consuming app's `Gemfile.lock`, evaluates `dfe-wizard.gemspec` from the
checkout, and puts `lib/` on the load path.

Two things follow from that:

- **The annotated tag is the release.** Everything else — the GitHub Release
  page, the built `.gem` — is presentation.
- **Never move a published tag.** Consumers have the SHA locked. Moving a tag
  makes `bundle install` and `bundle update` disagree and produces failures
  nobody can reproduce. A bad release gets a new patch version, never a re-tag.

## Do not run `rake release`

It is disabled in the `Rakefile`. Upstream `bundler/gem_tasks` defines it as
tag + git push + `gem push`, which is wrong for this gem. `rake build` and
`rake install` still work.

`dfe-wizard.gemspec` also sets `allowed_push_host` to an unresolvable host, so
a direct `gem push` fails rather than publishing under whoever is logged in.

## Cutting a release

1. **Bump the version.** It appears in three places and they must move
   together:
   - `lib/dfe/wizard/version.rb` — `Dfe::Wizard::VERSION`
   - `README.md` — the `**Version**:` line near the top
   - `README.md` — the `tag:` in the Installation snippet

2. **Update `CHANGELOG.md`.** Add a `## [X.Y.Z] - YYYY-MM-DD` section at the
   top. The release workflow extracts this section verbatim as the GitHub
   Release notes and **fails if no section matches the version**, so the
   heading has to be exact. Call out breaking changes explicitly.

3. **Open a PR and get CI green.** The matrix in
   `.github/workflows/test.yml` runs the suite across every supported
   Ruby/Rails pair; `rubocop` runs alongside it.

4. **Merge to `main`.**

5. **Tag and push:**

   ```bash
   git checkout main && git pull
   git tag -a v1.0.0 -m 'v1.0.0'
   git push origin v1.0.0
   ```

6. **The release workflow does the rest** — it asserts the tag matches
   `Dfe::Wizard::VERSION`, re-runs the full matrix against the tagged tree,
   builds the `.gem`, and creates the GitHub Release with the CHANGELOG
   section as its body and the `.gem` attached.

7. **Smoke-test the real install path** in a scratch directory:

   ```ruby
   # Gemfile
   source 'https://rubygems.org'
   gem 'dfe-wizard', require: 'dfe/wizard', github: 'DFE-Digital/dfe-wizard', tag: 'v1.0.0'
   ```

   ```bash
   bundle install
   bundle exec ruby -e "require 'dfe/wizard'; puts DfE::Wizard::VERSION"
   grep -A4 '^GIT' Gemfile.lock
   ```

   Expect the version you just tagged, and a `GIT` stanza recording both
   `tag:` and the resolved `revision:`. Note the namespace is `DfE` — the
   lowercase `Dfe::Wizard::VERSION` spelling still resolves, but only after an
   explicit `require 'dfe/wizard/version'`.

## Tag convention

Annotated, `v` + the gem version, matching `v0.1.0`, `v0.1.1`, `v1.0.0.beta`.
Prereleases keep the RubyGems suffix (`v1.1.0.beta`, `v1.1.0.rc1`); the release
workflow detects the letter in the suffix and marks the GitHub Release as a
prerelease automatically.

## Supported Ruby and Rails versions

Three things must agree, or the gem advertises support it does not test:

| Where | What it says |
|---|---|
| `dfe-wizard.gemspec` | `required_ruby_version`, and the `activemodel`/`activesupport` range |
| `.github/workflows/test.yml` | the `include:` matrix of Ruby/Rails pairs |
| `README.md` | the Requirements section |

To add a Rails version: add a row to the matrix `include:` list, widen the
gemspec range if the new version falls outside it, and update the README. The
matrix is an explicit list rather than a cross product because not every pair
is valid — Rails 7.1 has no Ruby 3.4 support, and Rails 8.0 requires Ruby 3.2+.

Locally, `RAILS_VERSION` selects the Rails to develop against. Both the root
`Gemfile` and `spec/rails-dummy/Gemfile` read it, and both bundles must agree:

```bash
export RAILS_VERSION=8.1
bundle install
(cd spec/rails-dummy && bundle install && bundle exec rails db:drop db:create db:schema:load RAILS_ENV=test)
bundle exec rspec
```

Unset it to fall back to the default. The suite needs PostgreSQL; CI provides
it as a service container, and `DATABASE_URL` overrides the connection.

Two dummy-app details exist to make the matrix work, and should stay that way:
`spec/rails-dummy/config/application.rb` calls `load_defaults` with the running
Rails version rather than a hardcoded one, and `spec/rails-dummy/db/schema.rb`
is stamped at the **floor** of the supported range. Newer Rails loads an
older-stamped schema; the reverse fails.
