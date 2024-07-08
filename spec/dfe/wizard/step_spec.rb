# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DfE::Wizard::Step do
  describe '.model_name' do
    it 'returns the name demodulized' do
      expect(described_class.model_name).to eq('Wizard')
    end

    it 'returns the name with original i18n key' do
      expect(described_class.model_name.i18n_key).to eq(:'dfe/wizard/step')
    end
  end

  describe '.formatted_name' do
    it 'returns the name without the step suffix' do
      expect(described_class.formatted_name).to eq('DfE::Wizard')
    end
  end

  describe '.route_name' do
    it 'returns the name as a route' do
      expect(described_class.route_name).to eq('dfe_wizard')
    end
  end

  describe '#step_name' do
    it 'returns the name of the step' do
      expect(described_class.new.step_name).to eq('Wizard')
    end
  end
end
