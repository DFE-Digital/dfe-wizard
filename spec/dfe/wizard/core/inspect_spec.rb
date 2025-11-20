RSpec.describe DfE::Wizard::Core::Inspect do
  let(:state_store) { StateStores::PersonalInformation.new }
  let(:current_step) { :name_and_date_of_birth }

  let(:wizard) do
    PersonalInformationWizard.new(
      current_step:,
      state_store:,
    )
  end

  subject(:output) { DfE::Wizard::Core::Inspect.new(wizard:).inspect }

  describe '#inspect' do
    context 'with empty wizard, no data saved' do
      it 'displays all three layers: flow path has steps, saved and valid are empty' do
        expect(output).to include('Current Step: name_and_date_of_birth')
        expect(output).to include('Flow Path:    [:name_and_date_of_birth]')
        expect(output).to include('Saved Path:   []')
        expect(output).to include('Valid Path:   []')
      end

      it 'shows validation errors for empty wizard' do
        expect(output).to include('✗ Invalid')
      end

      it 'shows validation error messages for failed steps' do
        expect(output).to include('┌─ ERRORS ───────────────────────────────────┐')
        expect(output).to include('name_and_date_of_birth:')
        expect(output).to include("first_name: can't be blank")
        expect(output).to include("last_name: can't be blank")
        expect(output).to include("date_of_birth: can't be blank")
      end

      it 'shows empty state store' do
        expect(output).to include("Filtered:\n│  (empty)")
      end
    end

    context 'with partial progress: first step saved and valid' do
      before do
        state_store.write_step(
          :name_and_date_of_birth,
          { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' },
        )
      end

      it 'saved path and valid path track step completion' do
        expect(output).to include('Saved Path:   [:name_and_date_of_birth]')
        expect(output).to include('Valid Path:   [:name_and_date_of_birth]')
      end

      it 'state store accumulates steps as user fills them in' do
        expect(output).to include('Raw Steps:')
        expect(output).to include('name_and_date_of_birth:')
        expect(output).to include('first_name')
        expect(output).to include('John')
        expect(output).to include('date_of_birth')
        expect(output).to include('1990-01-01')
      end
    end

    context 'with validation error blocking progression' do
      let(:current_step) { :nationality }

      before do
        state_store.write_step(
          :name_and_date_of_birth,
          { first_name: 'Jane', last_name: 'Gi', date_of_birth: '1990-01-01' },
        )
        state_store.write_step(:nationality, { nationalities: '' })
      end

      it 'valid path stops before error step' do
        expect(output).to include('Saved Path:   [:name_and_date_of_birth, :nationality]')
        expect(output).to include('Valid Path:   [:name_and_date_of_birth]')
      end

      it 'shows which steps fail validation for debugging' do
        expect(output).to include('✗ Invalid')
        expect(output).to include(':nationality')
      end

      it 'displays validation error messages for failed steps' do
        expect(output).to include('┌─ ERRORS ───────────────────────────────────┐')
        expect(output).to include('nationality:')
        expect(output).to include("nationalities: can't be blank")
      end
    end

    context 'with multiple steps completed and all valid' do
      let(:current_step) { :nationality }

      before do
        state_store.write_step(
          :name_and_date_of_birth,
          { first_name: 'Alex', last_name: 'Vera', date_of_birth: '1992-05-12' },
        )
        state_store.write_step(:nationality, { nationalities: 'british' })
      end

      it 'flow, saved, and valid paths grow together when no validation errors occur' do
        expect(output).to include('Flow Path:    [:name_and_date_of_birth, :nationality]')
        expect(output).to include('Saved Path:   [:name_and_date_of_birth, :nationality]')
        expect(output).to include('Valid Path:   [:name_and_date_of_birth, :nationality]')
      end

      it 'state store shows all completed steps accumulated' do
        expect(output).to include('Raw Steps:')
        expect(output).to include('name_and_date_of_birth:')
        expect(output).to include('Alex')
        expect(output).to include('Vera')
        expect(output).to include('1992-05-12')
        expect(output).to include('nationality:')
        expect(output).to include('british')
      end

      it 'shows no validation errors when all steps valid' do
        expect(output).to include('✓ All steps valid')
        expect(output).not_to include('ERRORS')
      end
    end

    context 'with unmasked sensitive parameters visible' do
      before do
        wizard.instance_variable_set(
          :@current_step_params,
          { visa_type: 'Skilled Worker', visa_number: 'ABC12345' },
        )
      end

      it 'shows all parameter values unmasked for inspection in dev environment' do
        expect(output).to include('visa_type')
        expect(output).to include('Skilled Worker')
        expect(output).to include('visa_number')
        expect(output).to include('ABC12345')
      end

      it 'truncates extremely long parameter values to maintain readability' do
        wizard.instance_variable_set(:@large_param, 'x' * 100)

        expect(output).to include('...')
        expect(output).not_to include('x' * 100)
      end
    end

    it 'includes object header with class name and memory address for identification' do
      expect(output).to match(/#<PersonalInformationWizard:0x[0-9a-f]+>/)
    end
  end
end
