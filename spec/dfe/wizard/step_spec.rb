# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DfE::Wizard::Step do
  describe 'Legacy step using attr_accessor' do
    subject(:step) { LegacyStep.new(first_name: 'Alice', last_name: 'Smith') }

    it 'assigns and exposes values from attr_accessor' do
      expect(step.first_name).to eq 'Alice'
      expect(step.last_name).to eq 'Smith'

      expect(step.serializable_data).to eq({
                                             first_name: 'Alice',
                                             last_name: 'Smith',
                                           })
    end

    it 'supports validation' do
      expect(step).to be_valid

      invalid = LegacyStep.new(last_name: 'Smith')
      expect(invalid).not_to be_valid
      expect(invalid.errors[:first_name]).to include("can't be blank")
    end
  end

  describe 'Modern step using ActiveModel::Attributes' do
    subject(:step) { NameAndAge.new(first_name: 'Bob', age: 30) }

    it 'sets and returns typed attributes' do
      expect(step.first_name).to eq 'Bob'
      expect(step.age).to eq 30
    end

    it 'provides an attributes hash with typed values' do
      expect(step.serializable_data).to eq({
                                             'first_name' => 'Bob',
                                             'age' => 30,
                                           })
    end

    it 'is valid with required attributes' do
      expect(step).to be_valid
    end

    it 'is invalid if required attributes are missing' do
      step.first_name = nil
      expect(step).not_to be_valid
      expect(step.errors[:first_name]).to include("can't be blank")
    end
  end

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
