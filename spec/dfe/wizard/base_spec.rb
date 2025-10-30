require 'spec_helper'

RSpec.describe DfE::Wizard::Base do
  let(:base_klass) do
    Class.new(described_class) do
      def steps_processor = @__processor
      def route_strategy = @__router
      def state_store = @__state_store
      def logger = nil
    end
  end

  subject(:wizard) do
    base_klass.new(current_step: :step_one).tap do |wiz|
      wiz.instance_variable_set(:@__processor, processor)
      wiz.instance_variable_set(:@__router, router)
      wiz.instance_variable_set(:@__state_store, state_store)
    end
  end

  let(:graphviz) { instance_double('GraphViz') }

  let(:processor) do
    Class.new do
      def initialize(graphviz)
        @graphviz = graphviz
      end

      def next_step(_, _) = :step_two
      def previous_step(_, _) = :step_zero
      def path_traversal(_, _) = %i[step_one step_two]
      def to_doc = @graphviz

      def find_step(_step_name = nil)
        DummyStep
      end
    end.new(graphviz)
  end

  let(:router) do
    Class.new do
      def resolve(step:, data:, options: {})
        if data.present?
          "/fake/#{step}"
        end
      end
    end.new
  end

  let(:state_store) do
    Class.new do
      attr_reader :written

      def read
        { steps: { step_one: { name: 'Ada' } } }
      end

      def write(data)
        @written = data
      end
    end.new
  end

  describe '#current_step' do
    it 'instantiates the current step from processor and state_store' do
      expect(wizard.current_step).to be_a(DummyStep)
      expect(wizard.current_step.name).to eq('Ada')
    end
  end

  describe '#step_object_class' do
    it 'returns the class of the current step' do
      expect(wizard.step_object_class).to eq(DummyStep)
    end
  end

  describe '#find_step' do
    it 'finds a step class by step name from processor' do
      expect(wizard.find_step(:step_one)).to eq(DummyStep)
    end
  end

  describe '#next_step_path' do
    it 'resolves the next step path via route_strategy' do
      expect(wizard.next_step_path).to eq('/fake/step_two')
    end
  end

  describe '#previous_step_path' do
    it 'resolves previous step via route_strategy' do
      expect(wizard.previous_step_path).to eq('/fake/step_zero')
    end

    context 'when previous step is nil' do
      before { allow(processor).to receive(:previous_step).and_return(nil) }

      it 'returns fallback path' do
        expect(wizard.previous_step_path(fallback: '/fallback')).to eq('/fallback')
      end
    end
  end

  describe '#valid_step?' do
    it 'returns true if current step is valid' do
      expect(wizard.valid_step?).to be(true)
    end
  end

  describe '#invalid_step?' do
    it 'returns false when current step is valid' do
      expect(wizard.invalid_step?).to be(false)
    end
  end

  describe '#data' do
    it 'returns the state store data' do
      expect(wizard.data[:steps][:step_one][:name]).to eq('Ada')
    end
  end

  describe '#save' do
    it 'writes serializable data to the state store' do
      wizard.save
      expect(state_store.written).to eq(
        step_one: { name: 'Ada' },
      )
    end
  end

  describe '#path_traversal' do
    it 'returns the traversal path for a target step' do
      expect(wizard.path_traversal(:step_two)).to eq(%i[step_one step_two])
    end
  end

  describe '#current_step' do
    it 'instantiates the current step from processor and state_store' do
      expect(wizard.current_step).to be_a(DummyStep)
      expect(wizard.current_step.name).to eq('Ada')
      expect(wizard.current_step.step_id).to eq(:step_one)
    end
  end

  describe '#summary_steps' do
    let(:processor) do
      Class.new do
        def next_step(_, _) = :step_two
        def previous_step(_, _) = :step_one

        def path_traversal(_target = nil, _data = nil)
          # Pretend two steps in summary
          %i[step_one step_two]
        end

        def find_step(_step_name = nil)
          DummyStep
        end
      end.new
    end

    let(:state_store) do
      Class.new do
        def read
          { steps: {
            step_one: { name: 'Ada' },
            step_two: { name: 'Bob' },
          } }
        end
      end.new
    end

    it 'returns an array of instantiated steps for the path traversal, setting step_id' do
      steps = wizard.summary_steps

      expect(steps.map(&:class)).to eq [DummyStep, DummyStep]
      expect(steps.map(&:name)).to eq %w[Ada Bob]

      # The step_id should be set (should match step_one/step_two)
      expect(steps.map(&:step_id)).to eq %i[step_one step_two]
    end

    it 'merges state_store data for each step and sets wizard' do
      steps = wizard.summary_steps
      expect(steps.first.wizard).to eq(wizard)
      expect(steps.last.wizard).to eq(wizard)
      expect(steps.first.name).to eq('Ada')
      expect(steps.last.name).to eq('Bob')
    end
  end

  describe '#to_doc' do
    it 'delegates to steps_processor.to_doc' do
      expect(wizard.to_doc).to eq(graphviz)
    end
  end
end
