RSpec.describe DfE::Wizard::StateStore, '#wizard' do
  class StoreWizardStep
    include DfE::Wizard::Step
  end

  class StoreWizardStore
    include DfE::Wizard::StateStore

    def provider_code_from_wizard
      wizard.provider_code
    end
  end

  let(:wizard_class) do
    Class.new do
      include DfE::Wizard

      attr_accessor :provider_code

      def steps_processor
        DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
          graph.add_node :only, StoreWizardStep
          graph.root :only
        end
      end

      def logger
        nil
      end

      def route_strategy
        nil
      end
    end
  end

  it 'is the wizard the store was given to' do
    store = StoreWizardStore.new
    wizard = wizard_class.new(state_store: store)

    expect(store.wizard).to be(wizard)
  end

  it 'reads context set on the wizard after new' do
    store = StoreWizardStore.new
    wizard = wizard_class.new(state_store: store)
    wizard.provider_code = 'ABC'

    expect(store.provider_code_from_wizard).to eq('ABC')
  end

  it 'is set on a store given through state_store=' do
    wizard = wizard_class.new(state_store: StoreWizardStore.new)
    replacement = StoreWizardStore.new
    wizard.state_store = replacement

    expect(replacement.wizard).to be(wizard)
  end

  it 'accepts a replacement store that has no wizard writer' do
    wizard = wizard_class.new(state_store: StoreWizardStore.new)
    plain_store = Object.new

    expect { wizard.state_store = plain_store }.not_to raise_error
    expect(wizard.state_store).to be(plain_store)
  end

  it 'points a store given to a second wizard at the second wizard' do
    store = StoreWizardStore.new
    wizard_class.new(state_store: store)
    second = wizard_class.new(state_store: store)

    expect(store.wizard).to be(second)
  end
end
