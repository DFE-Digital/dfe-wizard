# frozen_string_literal: true

require 'dfe/wizard'
require File.expand_path('rails-dummy/config/environment', __dir__)

require 'bundler'
Bundler.require

Dir['spec/support/**/*.rb'].each { |f| require File.expand_path(f) }
Dir['spec/factories/**/*.rb'].each { |f| require File.expand_path(f) }

require 'rspec/rails'
require 'capybara/rspec'
require 'capybara/rails'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.infer_spec_type_from_file_location!
end

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym 'DfE'
end
