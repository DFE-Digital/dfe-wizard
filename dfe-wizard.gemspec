# frozen_string_literal: true

require_relative 'lib/dfe/wizard/version'

Gem::Specification.new do |spec|
  spec.name = 'dfe-wizard'
  spec.version = Dfe::Wizard::VERSION
  spec.authors = ["Tomas D'Stefano"]
  spec.email = ['tomas_stefano@successoft.com']

  spec.summary = 'Extracted from Apply - A set of design of creating multi step forms'
  spec.description = 'A solution to implement multi step forms in specific design patterns in a simple way.'
  spec.homepage = 'https://github.com/DFE-Digital/dfe-wizard'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.4'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['bug_tracker_uri'] = "#{spec.homepage}/issues"
  spec.metadata['documentation_uri'] = "#{spec.homepage}/blob/main/README.md"
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # This gem is distributed via GitHub tags, not RubyGems — DfE has no RubyGems
  # account. Pointing at an unresolvable host makes an accidental `gem push`
  # (including via `rake release`) fail loudly rather than publish under whoever
  # happens to be logged in. See RELEASING.md.
  spec.metadata['allowed_push_host'] = 'https://rubygems.org.invalid'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile]) ||
        %w[TODO.md .rubocop.yml .rspec .ruby-version].include?(f)
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(/\Aexe\//) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Rails 7.1 and 8.1 are the floor and ceiling actually exercised by the CI
  # matrix in .github/workflows/test.yml. The `< 9` ceiling is deliberately
  # looser so consuming apps can move to a new Rails ahead of this gem; add a
  # matrix row when the next Rails ships rather than widening this blindly.
  spec.add_dependency 'activemodel', '>= 7.1', '< 9'
  spec.add_dependency 'activesupport', '>= 7.1', '< 9'
  spec.add_dependency 'ruby-graphviz', '~> 1.2'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
