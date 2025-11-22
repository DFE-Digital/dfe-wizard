RSpec.describe DfE::Wizard::Logging::Logger do
  let(:log_output) { StringIO.new }
  let(:rails_logger) do
    ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(log_output))
  end
  let(:logger) { described_class.new(rails_logger) }

  describe '.new' do
    it 'initializes with a Rails logger' do
      expect(logger).to be_a(described_class)
    end

    it 'initializes with empty exclusions' do
      expect(logger.excluded_categories).to be_empty
    end
  end

  describe '#exclude' do
    it 'excludes a single category' do
      logger.exclude(:navigation)
      expect(logger.excluded?(:navigation)).to be true
    end

    it 'excludes multiple categories' do
      logger.exclude(:navigation, :routing)
      expect(logger.excluded?(:navigation)).to be true
      expect(logger.excluded?(:routing)).to be true
    end

    it 'is chainable' do
      result = logger.exclude(:navigation).exclude(:routing)
      expect(result).to be(logger)
      expect(logger.excluded?(:navigation)).to be true
      expect(logger.excluded?(:routing)).to be true
    end

    it 'allows excluding multiple categories at once' do
      logger.exclude(:navigation, :routing, :state)
      expect(logger.excluded_categories).to contain_exactly(:navigation, :routing, :state)
    end

    it 'raises error for unknown category' do
      expect { logger.exclude(:unknown) }.to raise_error(
        ArgumentError,
        /Unknown category: unknown/,
      )
    end

    it 'lists valid categories in error message' do
      expect { logger.exclude(:invalid) }.to raise_error(
        ArgumentError,
        /navigation, routing, state, validation, callbacks/,
      )
    end
  end

  describe '#reset_exclusions' do
    it 'clears all exclusions' do
      logger.exclude(:navigation, :routing)
      logger.reset_exclusions

      expect(logger.excluded?(:navigation)).to be false
      expect(logger.excluded?(:routing)).to be false
      expect(logger.excluded_categories).to be_empty
    end

    it 'is chainable' do
      result = logger.reset_exclusions
      expect(result).to be(logger)
    end
  end

  describe '#excluded?' do
    it 'returns true for excluded category' do
      logger.exclude(:navigation)
      expect(logger.excluded?(:navigation)).to be true
    end

    it 'returns false for non-excluded category' do
      logger.exclude(:navigation)
      expect(logger.excluded?(:state)).to be false
    end

    it 'returns false when no exclusions set' do
      expect(logger.excluded?(:navigation)).to be false
    end
  end

  describe '#excluded_categories' do
    it 'returns empty array when no exclusions' do
      expect(logger.excluded_categories).to eq([])
    end

    it 'returns array of excluded categories' do
      logger.exclude(:navigation, :routing)
      expect(logger.excluded_categories).to contain_exactly(:navigation, :routing)
    end
  end

  describe '#tagged' do
    it 'returns a TaggedLogger instance' do
      tagged = logger.tagged('TestTag')
      expect(tagged).to be_a(DfE::Wizard::Logging::TaggedLogger)
    end

    it 'passes exclusions to TaggedLogger' do
      logger.exclude(:navigation)
      tagged = logger.tagged('TestTag')

      tagged.info('Test', category: :navigation)
      expect(log_output.string).to be_empty
    end
  end

  describe 'TaggedLogger with exclusions' do
    let(:tagged_logger) { logger.tagged('TestWizard') }

    describe '#info' do
      it 'logs when category not excluded' do
        tagged_logger.info('Test message', category: :state, key: 'value')

        output = log_output.string
        expect(output).to include('[TestWizard]')
        expect(output).to include('Test message')
        expect(output).to include('key="value"')
      end

      it 'does not log when category excluded' do
        logger.exclude(:navigation)
        tagged_logger.info('Test message', category: :navigation)

        expect(log_output.string).to be_empty
      end

      it 'logs when no category specified' do
        logger.exclude(:navigation)
        tagged_logger.info('Test message', key: 'value')

        output = log_output.string
        expect(output).to include('Test message')
      end

      it 'formats kwargs correctly' do
        tagged_logger.info('Event', step: :email, result: true)

        output = log_output.string
        expect(output).to include('Event')
        expect(output).to include('step=:email')
        expect(output).to include('result=true')
      end
    end

    describe '#debug' do
      before { rails_logger.level = Logger::DEBUG }

      it 'respects exclusions' do
        logger.exclude(:routing)
        tagged_logger.debug('Debug message', category: :routing)

        expect(log_output.string).to be_empty
      end

      it 'logs when not excluded' do
        tagged_logger.debug('Debug message', category: :state, data: {})

        expect(log_output.string).to include('Debug message')
      end
    end

    describe '#warn' do
      it 'respects exclusions' do
        logger.exclude(:validation)
        tagged_logger.warn('Warning', category: :validation)

        expect(log_output.string).to be_empty
      end

      it 'logs when not excluded' do
        tagged_logger.warn('Warning', category: :state)

        expect(log_output.string).to include('Warning')
      end
    end

    describe '#error' do
      it 'respects exclusions' do
        logger.exclude(:callbacks)
        tagged_logger.error('Error', category: :callbacks)

        expect(log_output.string).to be_empty
      end

      it 'logs when not excluded' do
        tagged_logger.error('Error', category: :state)

        expect(log_output.string).to include('Error')
      end
    end
  end

  describe 'Integration with wizard' do
    let(:session) { {} }
    let(:state_store) do
      StateStores::PersonalInformation.new(
        repository: DfE::Wizard::Repository::InMemory.new,
      )
    end
    let(:wizard_logger) { described_class.new(rails_logger).exclude(:navigation) }
    let(:tagged_logger) { wizard_logger.tagged(PersonalInformationWizard) }

    let(:wizard) do
      PersonalInformationWizard.new(
        current_step: :name_and_date_of_birth,
        state_store:,
      ).tap do |test_wizard|
        allow(test_wizard).to receive(:log).and_return(tagged_logger)
      end
    end

    it 'excludes navigation logs' do
      wizard.next_step

      expect(log_output.string).not_to include('Next step transition')
    end

    it 'allows state logs' do
      wizard.raw_data

      expect(log_output.string).to include('State read')
    end

    it 'excludes multiple categories' do
      wizard_logger.exclude(:routing, :state)

      wizard.raw_data
      expect(log_output.string).not_to include('State read')
    end
  end

  describe 'Exclusion scenarios' do
    let(:tagged_logger) { logger.tagged('Wizard') }

    context 'when excluding navigation' do
      before { logger.exclude(:navigation) }

      it 'blocks next step logs' do
        tagged_logger.info('Next step transition', category: :navigation, from: :a, to: :b)
        expect(log_output.string).to be_empty
      end

      it 'blocks previous step logs' do
        tagged_logger.info('Previous step', category: :navigation, from: :b, to: :a)
        expect(log_output.string).to be_empty
      end

      it 'blocks path traversal logs' do
        tagged_logger.debug('Path traversal', category: :navigation, path: [])
        expect(log_output.string).to be_empty
      end

      it 'allows state logs' do
        tagged_logger.info('State read', category: :state)
        expect(log_output.string).to include('State read')
      end
    end

    context 'when excluding routing' do
      before { logger.exclude(:routing) }

      it 'blocks route resolution logs' do
        tagged_logger.debug('Route resolved', category: :routing, step: :email)
        expect(log_output.string).to be_empty
      end

      it 'allows navigation logs' do
        tagged_logger.info('Next step', category: :navigation)
        expect(log_output.string).to include('Next step')
      end
    end

    context 'when excluding state' do
      before { logger.exclude(:state) }

      it 'blocks state read logs' do
        tagged_logger.info('State read', category: :state)
        expect(log_output.string).to be_empty
      end

      it 'blocks state write logs' do
        tagged_logger.info('State write', category: :state)
        expect(log_output.string).to be_empty
      end

      it 'blocks step save logs' do
        tagged_logger.info('Step saved', category: :state)
        expect(log_output.string).to be_empty
      end

      it 'allows validation logs' do
        tagged_logger.info('Validation', category: :validation)
        expect(log_output.string).to include('Validation')
      end
    end

    context 'when excluding validation' do
      before { logger.exclude(:validation) }

      it 'blocks validation logs' do
        tagged_logger.info('Validation', category: :validation)
        expect(log_output.string).to be_empty
      end

      it 'allows state logs' do
        tagged_logger.info('State read', category: :state)
        expect(log_output.string).to include('State read')
      end
    end

    context 'when excluding callbacks' do
      before { logger.exclude(:callbacks) }

      it 'blocks callback logs' do
        tagged_logger.info('Callback executed', category: :callbacks)
        expect(log_output.string).to be_empty
      end

      it 'allows other logs' do
        tagged_logger.info('Next step', category: :navigation)
        expect(log_output.string).to include('Next step')
      end
    end

    context 'when excluding multiple categories' do
      before { logger.exclude(:navigation, :routing, :state) }

      it 'blocks all excluded categories' do
        tagged_logger.info('Navigation', category: :navigation)
        tagged_logger.info('Routing', category: :routing)
        tagged_logger.info('State', category: :state)

        expect(log_output.string).to be_empty
      end

      it 'allows non-excluded categories' do
        tagged_logger.info('Validation', category: :validation)
        tagged_logger.info('Callback', category: :callbacks)

        output = log_output.string
        expect(output).to include('Validation')
        expect(output).to include('Callback')
      end
    end
  end

  describe 'Complex value formatting' do
    let(:tagged_logger) { logger.tagged('Test') }

    it 'formats arrays correctly' do
      tagged_logger.info('Test', steps: %i[email phone])

      expect(log_output.string).to include('steps=[:email, :phone]')
    end

    it 'formats hashes correctly' do
      tagged_logger.info('Test', data: { key: 'value' })

      expect(log_output.string).to include('data={key: "value"}')
    end

    it 'formats nested structures' do
      tagged_logger.info('Test', config: { steps: %i[a b], meta: { x: 1 } })

      output = log_output.string
      expect(output).to include('config=')
      expect(output).to include('steps')
      expect(output).to include('meta')
    end

    it 'formats symbols correctly' do
      tagged_logger.info('Test', step: :email, next_step: :phone)

      output = log_output.string
      expect(output).to include('step=:email')
      expect(output).to include('next_step=:phone')
    end

    it 'formats strings correctly' do
      tagged_logger.info('Test', message: 'Hello world')

      expect(log_output.string).to include('message="Hello world"')
    end

    it 'formats booleans correctly' do
      tagged_logger.info('Test', valid: true, saved: false)

      output = log_output.string
      expect(output).to include('valid=true')
      expect(output).to include('saved=false')
    end
  end
end
