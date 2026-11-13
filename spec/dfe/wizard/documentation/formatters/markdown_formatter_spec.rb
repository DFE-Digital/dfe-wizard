RSpec.describe DfE::Wizard::Documentation::Formatters::MarkdownFormatter do
  let(:wizards) do
    [
      PersonalInformationWizard.new(state_store: StateStores::PersonalInformation.new),
      AssignMentorWizard.new(state_store: StateStores::AssignMentor.new),
    ]
  end

  it 'matches minimal_metadata.md fixture' do
    wizards.each do |wizard|
      result = described_class.new(wizard.metadata, generated_at: '2025-12-04T08:04:13Z').render
      expected = load_expected_markdown(wizard.class.to_s.underscore)

      expect(result).to eq(expected)
    end
  end

  it 'documents the check answers step' do
    wizard = CourseChange::Wizard.new(state_store: CourseChange::StateStore.new)

    result = described_class.new(wizard.metadata, generated_at: '2025-12-04T08:04:13Z').render

    expect(result).to include("## Check Answers\n\n**Check Answers Step:** `check_answers`")
  end

  def load_expected_markdown(scenario_name)
    fixture_path = File.join('spec', 'fixtures', 'documentation', 'markdown', "#{scenario_name}.md")
    File.read(File.expand_path(fixture_path))
  rescue Errno::ENOENT
    raise "Expected markdown fixture not found: #{fixture_path}"
  end
end
