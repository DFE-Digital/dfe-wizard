# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in dfe-wizard.gemspec
gemspec

# Which Rails to develop and test against. CI sets this per matrix entry; see
# RELEASING.md. spec/rails-dummy/Gemfile reads the same variable, so both
# bundles resolve to the same Rails.
rails_version = ENV.fetch('RAILS_VERSION', '7.2')

gem 'actionpack', "~> #{rails_version}.0"
gem 'better_errors'
gem 'binding_of_caller'
gem 'capybara'
gem 'database_cleaner'
gem 'factory_bot'
gem 'faker'
gem 'govuk-components'
gem 'govuk_design_system_formbuilder'
gem 'mock_redis'
gem 'pg'
gem 'pry'
gem 'rails', "~> #{rails_version}.0"
gem 'rake', '~> 13.0'
gem 'rspec', '~> 3.0'
gem 'rspec-rails'
# Pinned to a minor series: `NewCops: enable` means a RuboCop release can add
# cops that fail CI on unchanged code. Bump deliberately, not by resolution.
gem 'rubocop', '~> 1.89.0'
gem 'sqlite3'
