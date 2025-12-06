namespace :wizard do
  namespace :docs do
    # Generate documentation for all wizards
    #
    # Generates GraphViz documentation for all wizard classes found in app/wizards
    # in all three themes (minimal, detailed, semantic).
    #
    # @example Generate all wizard documentation
    #   rake wizard:docs:generate
    #
    # @example Generate specific wizard
    #   WIZARD=PersonalInformationWizard rake wizard:docs:generate
    desc 'Generate documentation for all wizards'
    task generate: :environment do
      Dir['app/wizards/**/*.rb'].each { |f| require File.expand_path(f) }
      output_dir = 'docs/wizards'

      [
        PersonalInformationWizard,
        AssignMentorWizard,
        ALevelsRequirementsWizard,
      ].each do |wizard_class|
        wizard = wizard_class.new(state_store: OpenStruct.new)

        wizard.documentation.generate_all(output_dir)

        puts "Generated docs for #{wizard_class.name}"
      end

      puts "All wizard docs written to #{File.expand_path(output_dir)}/"
    end
  end
end
