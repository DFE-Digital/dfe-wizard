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

  def load_expected_markdown(scenario_name)
    fixture_path = File.join('spec', 'fixtures', 'documentation', 'markdown', "#{scenario_name}.md")
    File.read(File.expand_path(fixture_path))
  rescue Errno::ENOENT
    raise "Expected markdown fixture not found: #{fixture_path}"
  end

  describe 'sub-wizards and change journeys' do
    include JourneySpecHelpers

    let(:result) do
      wizard = journey_request(:start, wizard_class: JourneySpecTwoUnitWizard)
      described_class.new(wizard.metadata, include_raw_metadata: false).render
    end

    it 'lists each sub-wizard' do
      expect(result).to include(
        '| `visa` | `student`, `skilled`, `deadline_required`, `deadline_at` | `start_date` | `funding` |',
      )
    end

    it 'lists each depends_on answer with its step and the units it queues' do
      expect(result).to include('| `funding` | `funding` | `visa`, `start_date` |')
    end
  end
end
