RSpec.describe DfE::Wizard::Documentation::Formatters::MermaidFormatter do
  let(:wizards) do
    [
      PersonalInformationWizard.new(state_store: StateStores::PersonalInformation.new),
      AssignMentorWizard.new(state_store: StateStores::AssignMentor.new),
      AddCourseWizard.new(state_store: StateStores::AddCourse.new(provider: double, repository: double)),
    ]
  end

  it 'generates mermaid files' do
    wizards.each do |wizard|
      result = described_class.new(wizard.metadata).render

      expect(result).to match_mermaid_documentation.in(wizard)
    end
  end

  RSpec::Matchers.define :match_mermaid_documentation do |_expected|
    diffable

    match do |actual|
      wizard_name = @wizard.class.to_s.underscore

      @fixture_path = File.expand_path(
        File.join('spec', 'fixtures', 'documentation', 'mermaid', "#{wizard_name}.mmd"),
      )
      @expected = File.read(@fixture_path)

      @actual = actual.strip

      @actual == @expected.strip
    end

    chain :in do |wizard|
      @wizard = wizard
    end

    failure_message do |actual|
      <<~MSG
        Expected mermaid content:
        #{@expected.inspect}

        Got:
        #{actual.inspect}
      MSG
    end
  end
end
