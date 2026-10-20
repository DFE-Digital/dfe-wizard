RSpec.describe DfE::Wizard::Test::SubWizardHarness do
  module HarnessSpecSteps
    class Provider
      include DfE::Wizard::Step

      attribute :provider_name, :string

      def provider_from_store
        wizard.state_store.provider
      end

      def provider_from_wizard
        wizard.provider
      end
    end
  end

  # The spec visa class plus a step that reads context. provider_check has
  # no edges: exit_to wires it to the exit, and the spec only hydrates it.
  class HarnessSpecVisa
    extend DfE::Wizard::SubWizard

    uses(*SubWizardSpecVisa.uses, :provider)

    def self.draw(graph)
      SubWizardSpecVisa.draw(graph)
      graph.add_node :provider_check, HarnessSpecSteps::Provider
    end
  end

  describe 'with a real state store' do
    let(:harness) { described_class.new(SubWizardSpecVisa, root: :student, state_store: SubWizardSpecStore.new) }

    it 'follows the edges inside the sub-wizard' do
      expect(harness.wizard).to have_next_step(:deadline_required).from(:student).when(student_visa: true)
    end

    it 'leaves through the exit node' do
      expect(harness.wizard).to have_next_step(:sub_wizard_exit).from(:student).when(student_visa: false)
    end

    it 'walks the whole sub-wizard' do
      harness.wizard.state_store.write(student_visa: true, deadline_required: true)

      expect(harness.wizard.full_path).to eq(%i[student deadline_required deadline_at sub_wizard_exit])
    end
  end

  describe 'with a stub store built from uses' do
    it 'returns a stubbed value' do
      harness = described_class.new(SubWizardSpecVisa, root: :student, stubs: { student_visa?: true })

      expect(harness.wizard.steps_processor.next_step(:student)).to eq(:deadline_required)
    end

    it 'calls a callable stub with the store' do
      harness = described_class.new(
        SubWizardSpecVisa,
        root: :student,
        stubs: { student_visa?: ->(store) { store.read[:student_visa] == 'yes' } },
      )

      expect(harness.wizard).to have_next_step(:deadline_required).from(:student).when(student_visa: 'yes')
    end

    it 'raises when a used method with no stub is called' do
      harness = described_class.new(SubWizardSpecVisa, root: :student)

      expect { harness.wizard.steps_processor.next_step(:student) }
        .to raise_error(NotImplementedError, 'no stub for :student_visa?; pass stubs: { student_visa?: ... }')
    end

    it 'raises for a stub that is not in uses' do
      expect { described_class.new(SubWizardSpecVisa, root: :student, stubs: { provider: 'x' }) }
        .to raise_error(ArgumentError, 'stubs for methods not in uses: :provider')
    end
  end

  describe 'rule 7 for steps' do
    let(:harness) do
      described_class.new(HarnessSpecVisa, root: :student, stubs: { provider: 'Provider A' })
    end

    it 'lets a step read context through the state store' do
      expect(harness.wizard.step(:provider_check).provider_from_store).to eq('Provider A')
    end

    it 'raises NoMethodError for a step that calls an app wizard method' do
      expect { harness.wizard.step(:provider_check).provider_from_wizard }.to raise_error(NoMethodError, /provider/)
    end
  end
end
