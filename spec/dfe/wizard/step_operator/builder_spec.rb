RSpec.describe DfE::Wizard::StepsOperator::Builder do
  class TestWizard
    attr_reader :current_step

    def initialize(step = :personal_details)
      @current_step = step
    end
  end

  class TestStateStore
    attr_reader :data

    def initialize
      @data = {}
    end
  end

  # rubocop:disable Lint/EmptyClass
  class ValidateOp; end
  class PersistOp; end
  class CreateALevelOp; end
  class SendEmailOp; end
  class LogEventOp; end
  # rubocop:enable Lint/EmptyClass

  describe '.draw' do
    it 'creates builder and yields for DSL' do
      wizard = TestWizard.new
      store = TestStateStore.new
      builder = nil

      described_class.draw(wizard:, callable: store) do |b|
        builder = b
      end

      expect(builder).to be_a(described_class)
    end

    it 'returns the configured builder' do
      wizard = TestWizard.new
      store = TestStateStore.new

      builder = described_class.draw(wizard:, callable: store) do |b|
        b.on_step(:test_step, use: [CreateALevelOp])
      end

      expect(builder.operations_for(:test_step)).to eq([CreateALevelOp])
    end
  end

  describe '#on_step with use:' do
    let(:wizard) { TestWizard.new }
    let(:store) { TestStateStore.new }
    let(:builder) { described_class.new(wizard:, callable: store) }

    it 'sets operations exactly as provided' do
      builder.on_step(:what_a_level_is_required, use: [CreateALevelOp])

      expect(builder.operations_for(:what_a_level_is_required)).to eq([CreateALevelOp])
    end

    it 'allows explicit full list with Validate' do
      builder.on_step(:what_a_level_is_required, use: [ValidateOp, CreateALevelOp])

      expect(builder.operations_for(:what_a_level_is_required))
        .to eq([ValidateOp, CreateALevelOp])
    end

    it 'allows empty array (no operations)' do
      builder.on_step(:review, use: [])

      expect(builder.operations_for(:review)).to eq([])
    end

    it 'freezes the operations array' do
      builder.on_step(:what_a_level_is_required, use: [CreateALevelOp])

      ops = builder.operations_for(:what_a_level_is_required)
      expect(ops.frozen?).to be true
    end
  end

  describe '#on_step with add:' do
    let(:wizard) { TestWizard.new }
    let(:store) { TestStateStore.new }
    let(:builder) { described_class.new(wizard:, callable: store) }

    it 'appends to default operations' do
      builder.on_step(:personal_details, add: [SendEmailOp, LogEventOp])

      ops = builder.operations_for(:personal_details)
      # Should have Validate, Persist, SendEmail, LogEvent
      expect(ops.size).to eq(4)
      expect(ops).to include(SendEmailOp, LogEventOp)
    end

    it 'preserves order: defaults first, then added' do
      builder.on_step(:personal_details, add: [SendEmailOp])

      ops = builder.operations_for(:personal_details)
      expect(ops[-1]).to eq(SendEmailOp) # Added ops at end
    end
  end

  describe '#on_step error handling' do
    let(:wizard) { TestWizard.new }
    let(:store) { TestStateStore.new }
    let(:builder) { described_class.new(wizard:, callable: store) }

    it 'raises error if neither use nor add provided' do
      expect {
        builder.on_step(:step_name)
      }.to raise_error(ArgumentError, /requires either 'use:' or 'add:'/)
    end

    it 'raises error if both use and add provided' do
      expect {
        builder.on_step(:step_name, use: [CreateALevelOp], add: [SendEmailOp])
      }.to raise_error(ArgumentError, /cannot accept both/)
    end
  end

  describe '#operations_for' do
    let(:wizard) { TestWizard.new }
    let(:store) { TestStateStore.new }
    let(:builder) { described_class.new(wizard:, callable: store) }

    it 'returns configured operations for a step' do
      builder.on_step(:what_a_level_is_required, use: [CreateALevelOp])

      expect(builder.operations_for(:what_a_level_is_required)).to eq([CreateALevelOp])
    end

    it 'returns default operations for unconfigured step' do
      # Do NOT configure this step
      ops = builder.operations_for(:unconfigured_step)

      expect(ops).to include(DfE::Wizard::StepsOperator::Builder::DEFAULT_OPERATIONS[0])
      expect(ops).to include(DfE::Wizard::StepsOperator::Builder::DEFAULT_OPERATIONS[1])
    end

    it 'returns a copy of default operations' do
      ops1 = builder.operations_for(:step_one)
      ops2 = builder.operations_for(:step_two)

      expect(ops1).to eq(ops2)
      expect(ops1.object_id).not_to eq(ops2.object_id) # Different copies
    end
  end

  describe '#all_operations' do
    let(:wizard) { TestWizard.new }
    let(:store) { TestStateStore.new }
    let(:builder) { described_class.new(wizard:, callable: store) }

    it 'returns hash of all configured operations' do
      builder.on_step(:step_one, use: [CreateALevelOp])
      builder.on_step(:step_two, use: [SendEmailOp])

      all_ops = builder.all_operations
      expect(all_ops.keys).to include(:step_one, :step_two)
      expect(all_ops[:step_one]).to eq([CreateALevelOp])
      expect(all_ops[:step_two]).to eq([SendEmailOp])
    end

    it 'returns only explicitly configured steps' do
      builder.on_step(:configured_step, use: [CreateALevelOp])

      all_ops = builder.all_operations
      expect(all_ops.size).to eq(1)
      expect(all_ops).not_to include(:unconfigured_step)
    end
  end

  describe 'DSL usage pattern' do
    let(:wizard) { TestWizard.new }
    let(:store) { TestStateStore.new }

    it 'allows chained configuration' do
      builder = described_class.draw(wizard:, callable: store) do |b|
        b.on_step(:step_one, use: [CreateALevelOp])
        b.on_step(:step_two, add: [SendEmailOp])
        b.on_step(:step_three, use: [])
      end

      expect(builder.operations_for(:step_one)).to eq([CreateALevelOp])
      expect(builder.operations_for(:step_two)).to include(SendEmailOp)
      expect(builder.operations_for(:step_three)).to eq([])
    end
  end
end
