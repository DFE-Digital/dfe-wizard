module DfE
  module Wizard
    class Railtie < Rails::Railtie
      railtie_name :dfe_wizard

      rake_tasks do
        path = File.expand_path(__dir__)

        Dir.glob("#{path}/tasks/**/*.rake").each { |f| load f }
      end
    end
  end
end
