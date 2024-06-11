require 'spec_helper'

RSpec.describe DfE::Wizard::Store do
  subject(:store) { described_class.new(wizard) }

  describe '#wizard' do
    let(:wizard) { described_class.new(current_step: :foo) }

    it 'returns wizard' do
      expect(store.wizard).to eq(wizard)
    end
  end
end
