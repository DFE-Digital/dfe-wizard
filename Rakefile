# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

require 'rubocop/rake_task'

RuboCop::RakeTask.new

task default: %i[spec rubocop]

# `bundler/gem_tasks` defines `release` as tag + git push + `gem push`. This
# gem is distributed via GitHub tags only, so that task would half-run and then
# fail at the RubyGems step with a bare connection error. Replace it with a
# pointer to the real procedure. `rake build` and `rake install` still work.
Rake::Task['release'].clear
desc 'Disabled — see RELEASING.md'
task :release do
  abort <<~MSG
    `rake release` is disabled.

    dfe-wizard is distributed via GitHub tags, not RubyGems — DfE has no
    RubyGems account. Releasing means pushing an annotated tag, which the
    release workflow turns into a GitHub Release.

    See RELEASING.md.
  MSG
end

require 'dfe/wizard'
