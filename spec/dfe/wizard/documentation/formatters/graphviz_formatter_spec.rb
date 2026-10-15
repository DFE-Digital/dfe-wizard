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

  describe 'sub-wizards and change journeys' do
    include JourneySpecHelpers

    let(:result) do
      described_class.new(journey_request(:start, wizard_class: JourneySpecTwoUnitWizard).metadata.to_h).render
    end

    it 'turns on compound edges' do
      expect(result).to include("  compound=true;\n")
    end

    it 'draws each sub-wizard as a cluster that holds its steps' do
      expect(result).to include(<<~DOT.indent(2))
        subgraph cluster_visa {
          label="Visa";
          style=dashed;
          student [label="Student"];
          skilled [label="Skilled"];
          deadline_required [label="Deadline Required"];
          deadline_at [label="Deadline At"];
        }
      DOT
    end

    it 'ends a depends_on edge to a sub-wizard at its cluster' do
      expect(result).to include('  funding -> student [label="funding", style=dashed, color=gray, lhead=cluster_visa];')
    end

    it 'ends a depends_on edge to a single-step unit at the step' do
      expect(result).to include('  funding -> start_date [label="funding", style=dashed, color=gray];')
    end
  end
end
