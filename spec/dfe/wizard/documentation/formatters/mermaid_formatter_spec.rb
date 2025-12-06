RSpec.describe DfE::Wizard::Documentation::Formatters::MermaidFormatter do
  let(:wizards) do
    [
      PersonalInformationWizard.new(state_store: StateStores::PersonalInformation.new),
      AssignMentorWizard.new(state_store: StateStores::AssignMentor.new),
    ]
  end

  it 'generates mermaid files' do
    wizards.each do |wizard|
      result = described_class.new(wizard.metadata).render
      expected = load_expected_mermaid(wizard.class.to_s.underscore)

      expect(result).to eq(expected)
    end
  end

  def load_expected_mermaid(scenario_name)
    fixture_path = File.join('spec', 'fixtures', 'documentation', 'mermaid', "#{scenario_name}.mmd")
    File.read(File.expand_path(fixture_path))
  rescue Errno::ENOENT
    raise "Expected markdown fixture not found: #{fixture_path}"
  end
end
