ENV['RAILS_ENV'] ||= 'test'
require 'dfe/wizard'

require File.expand_path('rails-dummy/config/environment', __dir__)

Dir['spec/support/**/*.rb'].each { |f| require File.expand_path(f) }
Dir['spec/factories/**/*.rb'].each { |f| require File.expand_path(f) }

require 'rspec/rails'
require 'capybara/rspec'
require 'capybara/rails'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.include DfE::Wizard::Test::RSpecMatchers

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.infer_spec_type_from_file_location!

  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end

ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym 'DfE'
end
