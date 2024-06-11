# frozen_string_literal: true

require_relative "lib/dfe/wizard/version"

Gem::Specification.new do |spec|
  spec.name = "dfe-wizard"
  spec.version = Dfe::Wizard::VERSION
  spec.authors = ["Tomas D'Stefano"]
  spec.email = ["tomas_stefano@successoft.com"]

  spec.summary = 'Extracted from Apply - A set of design of creating multi step forms'
  spec.description = "A solution to implement multi step forms in specific design patterns in a simple way."
  spec.homepage = 'https://github.com/DFE-Digital/dfe-wizard'
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = 'https://github.com/DFE-Digital/dfe-wizard/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'activesupport'
  spec.add_dependency 'activemodel'
end
