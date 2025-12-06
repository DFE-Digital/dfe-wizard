RSpec.describe DfE::Wizard::Documentation::Formatters::GraphvizFormatter do
  let(:wizards) do
    [
      PersonalInformationWizard.new(state_store: StateStores::PersonalInformation.new),
      AssignMentorWizard.new(state_store: StateStores::AssignMentor.new),
    ]
  end

  it 'renders graphviz dot files' do
    wizards.each do |wizard|
      result = described_class.new(wizard.metadata, generated_at: '2025-12-04T08:04:13Z').render
      expected = load_expected_graphviz(wizard.class.to_s.underscore)

      expect(result.strip).to eq(expected.strip)
    end
  end

  def load_expected_graphviz(scenario_name)
    fixture_path = File.join('spec', 'fixtures', 'documentation', 'graphviz', "#{scenario_name}.dot")
    File.read(File.expand_path(fixture_path))
  rescue Errno::ENOENT
    raise "Expected markdown fixture not found: #{fixture_path}"
  end
end
