RSpec.describe DfE::Wizard::Tooling::LogManagement do
  let(:repository) { DfE::Wizard::Repository::InMemory.new }
  let(:state_store) { StateStores::PersonalInformation.new(repository: repository) }

  before do
    @original = Rails.application.config.filter_parameters
    Rails.application.config.filter_parameters = %i[password ssn date_of_birth]

    repository.write({
                       first_name: 'John',
                       last_name: 'Doe',
                       date_of_birth: '1990-01-01',
                       nationalities: ['british'],
                     })
  end

  after do
    Rails.application.config.filter_parameters = @original
  end

  describe 'with logging enabled' do
    let(:log_output) { StringIO.new }
    let(:rails_logger) { ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(log_output)) }
    let(:wizard_logger) { DfE::Wizard::Logging::Logger.new(rails_logger) }
    let(:tagged_logger) { wizard_logger.tagged(PersonalInformationWizard) }

    let(:wizard) do
      PersonalInformationWizard.new(
        current_step: :nationality,
        state_store:,
      ).tap do |test_wizard|
        allow(test_wizard).to receive(:log).and_return(tagged_logger)
      end
    end

    describe '#log_next_step_transition' do
      it 'logs navigation between steps' do
        wizard.log_next_step_transition(from: :name_and_date_of_birth, to: :nationality)

        output = log_output.string
        expect(output).to include('[PersonalInformationWizard]')
        expect(output).to include('Next step transition')
        expect(output).to include('from=:name_and_date_of_birth')
        expect(output).to include('to=:nationality')
      end

      it 'respects navigation exclusion' do
        wizard_logger.exclude(:navigation)
        wizard.log_next_step_transition(from: :name_and_date_of_birth, to: :nationality)

        expect(log_output.string).to be_empty
      end
    end

    describe '#log_previous_step_transition' do
      it 'logs navigation between steps' do
        wizard.log_previous_step_transition(current: :nationality, previous: :name_and_date_of_birth)

        output = log_output.string
        expect(output).to include('[PersonalInformationWizard]')
        expect(output).to include('Previous step')
        expect(output).to include('previous=:name_and_date_of_birth')
        expect(output).to include('current=:nationality')
      end

      it 'respects navigation exclusion' do
        wizard_logger.exclude(:navigation)
        wizard.log_previous_step_transition(current: :nationality, previous: :name_and_date_of_birth)

        expect(log_output.string).to be_empty
      end
    end

    describe '#log_flow_path_resolved' do
      it 'logs path calculation at DEBUG level' do
        rails_logger.level = Logger::DEBUG

        wizard.log_flow_path_resolved(target: :review, path: %i[name_and_date_of_birth nationality review])

        output = log_output.string
        expect(output).to include('Flow Path')
        expect(output).to include('target=:review')
        expect(output).to include('path=[:name_and_date_of_birth, :nationality, :review]')
      end

      it 'does not log at INFO level' do
        rails_logger.level = Logger::INFO

        wizard.log_flow_path_resolved(target: :review, path: [])

        expect(log_output.string).to be_empty
      end

      it 'respects navigation exclusion' do
        rails_logger.level = Logger::DEBUG
        wizard_logger.exclude(:navigation)

        wizard.log_flow_path_resolved(target: :review, path: %i[a b])

        expect(log_output.string).to be_empty
      end
    end

    describe '#log_state_read' do
      it 'logs step names at INFO level' do
        data = { steps: { name_and_date_of_birth: {}, nationality: {} } }

        wizard.log_state_read(data:)

        output = log_output.string
        expect(output).to include('State read')
        expect(output).to include('steps=[:name_and_date_of_birth, :nationality]')
      end

      it 'logs full data at DEBUG level' do
        rails_logger.level = Logger::DEBUG
        data = { steps: { email: { email: 'user@example.com' } } }

        wizard.log_state_read(data:)

        output = log_output.string
        expect(output).to include('State data')
        expect(output).to include('email')
      end

      it 'respects state exclusion' do
        wizard_logger.exclude(:state)
        data = { steps: { email: {} } }

        wizard.log_state_read(data:)

        expect(log_output.string).to be_empty
      end
    end

    describe '#log_step_hydration' do
      it 'logs field names at INFO level' do
        wizard.log_step_hydration(
          step_id: :nationality,
          attributes: { nationalities: ['british'] },
        )

        output = log_output.string
        expect(output).to include('Step hydrated')
        expect(output).to include('step=:nationality')
        expect(output).to include('fields=[:nationalities]')
      end

      it 'logs attribute values at DEBUG level' do
        rails_logger.level = Logger::DEBUG

        wizard.log_step_hydration(
          step_id: :nationality,
          attributes: { nationalities: ['british'] },
        )

        output = log_output.string
        expect(output).to include('Step data')
        expect(output).to include('british')
      end

      it 'respects state exclusion' do
        wizard_logger.exclude(:state)

        wizard.log_step_hydration(
          step_id: :nationality,
          attributes: { nationalities: ['british'] },
        )

        expect(log_output.string).to be_empty
      end
    end

    describe '#log_params_received' do
      let(:raw_params) do
        {
          email: { email: 'user@example.com', confirmed: 'true', extra: 'ignored' },
        }
      end

      let(:permitted_params) do
        {
          email: { email: 'user@example.com', confirmed: 'true' },
        }
      end

      it 'logs param keys at INFO level' do
        wizard.log_params_received(
          step_id: :email,
          raw_params:,
          permitted_params:,
        )

        output = log_output.string
        expect(output).to eq(
          '[PersonalInformationWizard] Params data step=:email ' \
          'raw={email: {email: "user@example.com", confirmed: "true", extra: "ignored"}} ' \
          'permitted={email: {email: "user@example.com", confirmed: "true"}}' \
          "\n",
        )
      end

      it 'logs param values at DEBUG level' do
        rails_logger.level = Logger::DEBUG

        wizard.log_params_received(
          step_id: :email,
          raw_params:,
          permitted_params:,
        )

        output = log_output.string
        expect(output).to include('Params data')
        expect(output).to include('user@example.com')
      end

      it 'respects state exclusion' do
        wizard_logger.exclude(:state)

        wizard.log_params_received(
          step_id: :email,
          raw_params:,
          permitted_params:,
        )

        expect(log_output.string).to be_empty
      end
    end

    describe '#log_validation' do
      it 'logs successful validation' do
        wizard.log_validation(type: :step, result: true, step: :nationality)

        output = log_output.string
        expect(output).to include('Validation')
        expect(output).to include('type=:step')
        expect(output).to include('result=true')
      end

      it 'logs failed validation with errors' do
        errors = ["First name can't be blank", "Last name can't be blank"]

        wizard.log_validation(type: :step, result: false, step: :name_and_date_of_birth, errors: errors)

        output = log_output.string
        expect(output).to include('result=false')
        expect(output).to include('Validation errors')
        expect(output).to include("First name can't be blank")
      end

      it 'respects validation exclusion' do
        wizard_logger.exclude(:validation)

        wizard.log_validation(type: :step, result: true, step: :nationality)

        expect(log_output.string).to be_empty
      end
    end

    describe '#log_conditional' do
      it 'logs conditional branch evaluation' do
        wizard.log_conditional(
          from: :nationality,
          condition: 'needs_visa?',
          result: true,
          chosen: :immigration_status,
        )

        output = log_output.string
        expect(output).to include('Conditional branch')
        expect(output).to include('from=:nationality')
        expect(output).to include('condition="needs_visa?"')
        expect(output).to include('result=true')
        expect(output).to include('chosen=:immigration_status')
      end

      it 'respects navigation exclusion' do
        wizard_logger.exclude(:navigation)

        wizard.log_conditional(
          from: :nationality,
          condition: 'test',
          result: true,
          chosen: :next,
        )

        expect(log_output.string).to be_empty
      end
    end

    describe '#log_step_save' do
      it 'logs saved field names at INFO level' do
        wizard.log_step_save(
          step_id: :nationality,
          data: { nationalities: ['british'] },
        )

        output = log_output.string
        expect(output).to include('Step saved')
        expect(output).to include('step=:nationality')
        expect(output).to include('fields=[:nationalities]')
      end

      it 'logs saved data at DEBUG level' do
        rails_logger.level = Logger::DEBUG

        wizard.log_step_save(
          step_id: :nationality,
          data: { nationalities: ['british'] },
        )

        output = log_output.string
        expect(output).to include('Saved data')
        expect(output).to include('british')
      end

      it 'respects state exclusion' do
        wizard_logger.exclude(:state)

        wizard.log_step_save(
          step_id: :nationality,
          data: { nationalities: ['british'] },
        )

        expect(log_output.string).to be_empty
      end
    end

    describe '#log_route_resolved' do
      it 'logs route resolution at DEBUG level' do
        rails_logger.level = Logger::DEBUG

        wizard.log_route_resolved(step: :email, path: '/wizard/email')

        output = log_output.string
        expect(output).to include('Route resolved')
        expect(output).to include('step=:email')
        expect(output).to include('path="/wizard/email"')
      end

      it 'respects routing exclusion' do
        rails_logger.level = Logger::DEBUG
        wizard_logger.exclude(:routing)

        wizard.log_route_resolved(step: :email, path: '/wizard/email')

        expect(log_output.string).to be_empty
      end
    end

    describe '#log_callback' do
      it 'logs callback execution' do
        wizard.log_callback(name: :before_save, result: true)

        output = log_output.string
        expect(output).to include('Callback executed')
        expect(output).to include('name=:before_save')
        expect(output).to include('returned="TrueClass"')
      end

      it 'respects callbacks exclusion' do
        wizard_logger.exclude(:callbacks)

        wizard.log_callback(name: :before_save, result: true)

        expect(log_output.string).to be_empty
      end
    end

    describe 'Multiple exclusions' do
      it 'excludes multiple categories simultaneously' do
        wizard_logger.exclude(:navigation, :routing, :state)

        wizard.log_next_step_transition(from: :a, to: :b)
        wizard.log_route_resolved(step: :email, path: '/email')
        wizard.log_state_read(data: { steps: {} })

        expect(log_output.string).to be_empty
      end

      it 'allows non-excluded categories through' do
        wizard_logger.exclude(:navigation, :routing)

        wizard.log_validation(type: :step, result: true, step: :email)

        expect(log_output.string).to include('Validation')
      end
    end
  end

  describe 'with logging disabled' do
    let(:wizard) do
      PersonalInformationWizard.new(
        current_step: :nationality,
        state_store: state_store,
      )
    end

    before do
      allow(wizard).to receive(:log).and_return(DfE::Wizard::Logging::NullLogger.new)
    end

    it 'does not raise errors when logging' do
      expect {
        wizard.log_next_step_transition(from: :name, to: :email)
        wizard.log_previous_step_transition(previous: :name, current: :email)
        wizard.log_params_received(step_id: :email, raw_params: {}, permitted_params: {})
        wizard.log_step_save(step_id: :email, data: {})
        wizard.log_validation(type: :step, result: true, step: :email)
        wizard.log_callback(name: :test, result: true)
      }.not_to raise_error
    end

    it 'returns NullLogger' do
      expect(wizard.log).to be_a(DfE::Wizard::Logging::NullLogger)
    end
  end

  describe '#sanitize_data' do
    let(:wizard) do
      PersonalInformationWizard.new(
        current_step: :nationality,
        state_store: state_store,
      )
    end

    before do
      Rails.application.config.filter_parameters += %i[password ssn date_of_birth]
    end

    it 'filters sensitive data using Rails config' do
      data = {
        first_name: 'John',
        last_name: 'Doe',
        date_of_birth: '1990-01-01',
        password: 'secret123',
      }

      result = wizard.sanitize_data(data)

      expect(result[:first_name]).to eq('John')
      expect(result[:last_name]).to eq('Doe')
      expect(result[:date_of_birth]).to eq('[FILTERED]')
      expect(result[:password]).to eq('[FILTERED]')
    end

    it 'filters nested sensitive data' do
      data = {
        user: {
          email: 'user@example.com',
          password: 'secret123',
        },
      }

      result = wizard.sanitize_data(data)

      expect(result[:user][:email]).to eq('user@example.com')
      expect(result[:user][:password]).to eq('[FILTERED]')
    end

    it 'handles arrays with sensitive data' do
      data = {
        users: [
          { name: 'John', ssn: '123-45-6789' },
          { name: 'Jane', ssn: '987-65-4321' },
        ],
      }

      result = wizard.sanitize_data(data)

      expect(result).to eq(
        {
          users: [
            { name: 'John', ssn: '[FILTERED]' },
            { name: 'Jane', ssn: '[FILTERED]' },
          ],
        },
      )
    end
  end
end
