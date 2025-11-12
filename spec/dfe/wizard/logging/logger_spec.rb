RSpec.describe DfE::Wizard::Logging::Logger do
  let(:log_output) { StringIO.new }
  let(:rails_logger) do
    ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(log_output))
  end
  let(:wizard_logger) { described_class.new(rails_logger) }

  let(:session) { {} }
  let(:state_store) { DfE::Wizard::StateStore::Session.new(session:, key: 'test_wizard') }

  let(:wizard) do
    PersonalInformationWizard.new(
      current_step: :name_and_date_of_birth,
      state_store: state_store,
      step_params: ActionController::Parameters.new({}),
    ).tap do |w|
      allow(w).to receive(:logger).and_return(wizard_logger)
    end
  end

  before do
    Rails.application.config.filter_parameters = %i[password ssn]
  end

  describe 'Navigation logging' do
    describe '#next_step' do
      it 'logs step transition forward' do
        wizard.next_step

        output = log_output.string
        expect(output).to include('[PersonalInformationWizard]')
        expect(output).to include('Step transition')
        expect(output).to include('from=:name_and_date_of_birth')
        expect(output).to include('to=:nationality')
        expect(output).to include('direction=:forward')
      end
    end

    describe '#previous_step' do
      let(:session) do
        {
          'test_wizard' => {
            'steps' => {
              'name_and_date_of_birth' => {
                'first_name' => 'John',
                'last_name' => 'Doe',
                'date_of_birth' => '1990-01-01',
              },
            },
          },
        }
      end

      let(:wizard) do
        PersonalInformationWizard.new(
          current_step: :nationality,
          state_store: state_store,
          step_params: ActionController::Parameters.new({}),
        ).tap do |w|
          allow(w).to receive(:logger).and_return(wizard_logger)
        end
      end

      it 'logs step transition backward' do
        wizard.previous_step

        output = log_output.string
        expect(output).to include('Step transition')
        expect(output).to include('from=:nationality')
        expect(output).to include('to=:name_and_date_of_birth')
        expect(output).to include('direction=:backward')
      end
    end

    describe '#path_traversal' do
      it 'logs path calculation at DEBUG level' do
        rails_logger.level = Logger::DEBUG

        wizard.path_traversal(:nationality)

        output = log_output.string
        expect(output).to include('Path traversal')
        expect(output).to include('target=:nationality')
        expect(output).to include('path=')
      end
    end
  end

  describe 'Validation logging' do
    describe '#valid_step?' do
      context 'with valid step' do
        let(:wizard) do
          PersonalInformationWizard.new(
            current_step: :name_and_date_of_birth,
            state_store: state_store,
            step_params: ActionController::Parameters.new(
              name_and_date_of_birth: {
                first_name: 'Jane',
                last_name: 'Smith',
                date_of_birth: '1990-01-01',
              },
            ),
          ).tap do |w|
            allow(w).to receive(:logger).and_return(wizard_logger)
          end
        end

        it 'logs successful validation' do
          wizard.valid_step?

          output = log_output.string
          expect(output).to include('Validation')
          expect(output).to include('type=:step')
          expect(output).to include('result=true')
          expect(output).to include('step=:name_and_date_of_birth')
        end
      end

      context 'with invalid step' do
        it 'logs failed validation with errors' do
          wizard.valid_step?

          output = log_output.string
          expect(output).to include('Validation')
          expect(output).to include('result=false')
          expect(output).to include('Validation errors')
          expect(output).to include("First name can't be blank")
        end
      end
    end

    describe '#path_complete_to?' do
      it 'logs path completeness check' do
        wizard.path_complete_to?(:review)

        output = log_output.string
        expect(output).to include('Validation')
        expect(output).to include('type=:path_complete')
        expect(output).to include('target=:review')
      end
    end

    describe '#path_valid_to?' do
      it 'logs path validity check' do
        wizard.path_valid_to?(:review)

        output = log_output.string
        expect(output).to include('Validation')
        expect(output).to include('type=:path_valid')
        expect(output).to include('target=:review')
      end
    end
  end

  describe 'State Management logging' do
    describe '#raw_data' do
      let(:session) do
        {
          'test_wizard' => {
            'steps' => {
              'name_and_date_of_birth' => {
                'first_name' => 'John',
                'last_name' => 'Doe',
              },
            },
          },
        }
      end

      it 'logs state read' do
        wizard.raw_data

        output = log_output.string
        expect(output).to include('State read')
        expect(output).to include('steps=[:name_and_date_of_birth]')
      end
    end

    describe '#data' do
      let(:session) do
        {
          'test_wizard' => {
            'steps' => {
              'name_and_date_of_birth' => {
                'first_name' => 'John',
              },
            },
          },
        }
      end

      it 'logs filtered data at DEBUG level' do
        rails_logger.level = Logger::DEBUG

        wizard.data

        output = log_output.string
        expect(output).to include('State read')
        expect(output).to include('Filtered data')
      end
    end

    describe '#save' do
      let(:wizard) do
        PersonalInformationWizard.new(
          current_step: :name_and_date_of_birth,
          state_store: state_store,
          step_params: ActionController::Parameters.new(
            name_and_date_of_birth: {
              first_name: 'Jane',
              last_name: 'Smith',
              date_of_birth: '1990-01-01',
            },
          ),
        ).tap do |w|
          allow(w).to receive(:logger).and_return(wizard_logger)
        end
      end

      it 'logs step save' do
        wizard.save

        output = log_output.string
        expect(output).to include('Step saved')
        expect(output).to include('step=:name_and_date_of_birth')
        expect(output).to include('fields=')
      end
    end

    describe '#write_state' do
      it 'logs state write' do
        wizard.write_state(custom_key: 'value')

        output = log_output.string
        expect(output).to include('State write')
      end
    end

    describe '#clear_state' do
      it 'logs state clear' do
        wizard.clear_state

        output = log_output.string
        expect(output).to include('State cleared')
      end
    end

    describe '#mark_completed' do
      it 'logs wizard completion' do
        wizard.mark_completed

        output = log_output.string
        expect(output).to include('Wizard marked completed')
        expect(output).to include('completed_at=')
      end
    end
  end

  describe 'Step Management logging' do
    describe '#hydrate_step' do
      it 'logs step hydration at INFO level' do
        wizard.step(:name_and_date_of_birth)

        output = log_output.string
        expect(output).to include('Step hydrated')
        expect(output).to include('step=:name_and_date_of_birth')
        expect(output).to include('fields=')
      end

      it 'logs step data at DEBUG level' do
        rails_logger.level = Logger::DEBUG

        wizard.step(:name_and_date_of_birth)

        output = log_output.string
        expect(output).to include('Step data')
      end
    end

    describe '#current_step_params' do
      let(:wizard) do
        PersonalInformationWizard.new(
          current_step: :name_and_date_of_birth,
          state_store: state_store,
          step_params: ActionController::Parameters.new(
            name_and_date_of_birth: {
              first_name: 'Jane',
              last_name: 'Smith',
              date_of_birth: '1990-01-01',
            },
          ),
        ).tap do |w|
          allow(w).to receive(:logger).and_return(wizard_logger)
        end
      end

      it 'logs params received' do
        wizard.send(:current_step_params)

        output = log_output.string
        expect(output).to include('Params received')
        expect(output).to include('step=:name_and_date_of_birth')
      end
    end
  end

  describe 'Full wizard flow with logging' do
    it 'logs complete wizard lifecycle' do
      # Start
      wizard_flow = PersonalInformationWizard.new(
        current_step: :name_and_date_of_birth,
        state_store: DfE::Wizard::StateStore::Session.new(session: {}, key: 'flow_test'),
        step_params: ActionController::Parameters.new(
          name_and_date_of_birth: {
            first_name: 'Alice',
            last_name: 'Johnson',
            date_of_birth: '1988-03-15',
          },
        ),
      ).tap do |w|
        allow(w).to receive(:logger).and_return(wizard_logger)
      end

      # Validate step
      wizard_flow.valid_step?
      expect(log_output.string).to include('Validation')

      log_output.truncate(0)
      log_output.rewind

      # Save step
      wizard_flow.save
      expect(log_output.string).to include('Step saved')

      log_output.truncate(0)
      log_output.rewind

      # Navigate to next step
      wizard_flow.next_step
      expect(log_output.string).to include('Step transition')
    end
  end
end
