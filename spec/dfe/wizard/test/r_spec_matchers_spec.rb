RSpec.describe DfE::Wizard::Test::RSpecMatchers do
  let(:wizard) do
    PersonalInformationWizard.new(
      current_step:,
      state_store:,
    )
  end

  let(:state_store) do
    StateStores::PersonalInformation.new
  end

  let(:steps_data) { {} }
  let(:current_step) { :name_and_date_of_birth }

  before do
    state_store.save_steps(steps_data) if steps_data.any?
  end

  describe '#be_at_step' do
    let(:current_step) { :nationality }

    it 'passes if at the expected step' do
      expect(wizard).to be_at_step(:nationality)
    end

    it 'fails with a clear message if not' do
      expect {
        expect(wizard).to be_at_step(:review)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Expected current step: :review/)
    end
  end

  describe '#be_saved and #have_saved' do
    let(:steps_data) do
      { name_and_date_of_birth: { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' } }
    end
    let(:current_step) { :nationality }

    it 'passes for single step using #be_saved' do
      expect(:name_and_date_of_birth).to be_saved.in(wizard)
    end

    it 'passes for multiple steps using #have_saved' do
      state_store.write_step(:nationality, { nationalities: 'british' })
      expect(wizard).to have_saved(:name_and_date_of_birth, :nationality)
    end

    it 'fails if a step is missing' do
      expect {
        expect(:review).to be_saved.in(wizard)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Step not saved: :review/)
    end

    it 'fails if multiple required steps are missing' do
      state_store.write_step(:nationality, { nationalities: 'british' })
      expect {
        expect(wizard).to have_saved(:name_and_date_of_birth, :review, :nationality)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Missing: \[:review\]/)
    end
  end

  describe '#be_in_flow and #have_in_flow' do
    let(:steps_data) do
      { name_and_date_of_birth: { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' } }
    end
    let(:current_step) { :nationality }

    it 'passes if the step is in the flow' do
      expect(:nationality).to be_in_flow.in(wizard)
    end

    it 'fails if the step is not in the flow' do
      expect {
        expect(:immigration_status).to be_in_flow.in(wizard)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Step not in flow: :immigration_status/)
    end

    it 'passes for all given steps with #have_in_flow' do
      expect(wizard).to have_in_flow(:name_and_date_of_birth, :nationality)
    end

    it 'fails if any step is missing' do
      expect {
        expect(wizard).to have_in_flow(:name_and_date_of_birth, :review)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Missing: \[:review\]/)
    end
  end

  describe '#be_valid_to' do
    let(:steps_data) do
      {
        name_and_date_of_birth: { first_name: '', last_name: 'Doe', date_of_birth: '1990-01-01' },
        nationality: { nationalities: 'british' },
      }
    end
    let(:current_step) { :nationality }

    it 'passes if all steps to the target are valid' do
      state_store.save_steps(name_and_date_of_birth: { first_name: 'Jane', last_name: 'Smith',
                                                       date_of_birth: '1950-01-01' })
      expect(wizard).to be_valid_to(:nationality)
    end

    it 'fails with full error diagnostic if any step invalid' do
      expect {
        expect(wizard).to be_valid_to(:nationality)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /step\(s\) invalid before reaching :nationality/)
    end

    context '#be_valid_to edge cases' do
      let(:current_step) { :review }

      context 'when target step itself is invalid' do
        let(:steps_data) do
          {
            name_and_date_of_birth: { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' },
            nationality: { nationalities: '' },
          }
        end

        it 'pass if only target step is invalid' do
          expect(wizard).to be_valid_to(:nationality)
        end
      end

      context 'when middle step is invalid' do
        let(:steps_data) do
          {
            name_and_date_of_birth: { first_name: '', last_name: 'Doe', date_of_birth: '1990-01-01' },
            nationality: { nationalities: 'french' },
            right_to_work_or_study: { right_to_work_or_study: 'yes', visa_type: 'work', visa_expiry: '2026-12-31' },
          }
        end

        it 'fails because middle step is invalid' do
          expect {
            expect(wizard).to be_valid_to(:right_to_work_or_study)
          }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /step\(s\) invalid/)
        end
      end

      context 'when all steps up to and including target are valid' do
        let(:steps_data) do
          {
            name_and_date_of_birth: { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' },
            nationality: { nationalities: 'british' },
          }
        end

        it 'passes' do
          expect(wizard).to be_valid_to(:nationality)
        end
      end

      context 'when step not in flow path' do
        let(:steps_data) do
          {
            name_and_date_of_birth: { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' },
            nationality: { nationalities: 'british' },
          }
        end

        it 'fails for unreachable step' do
          expect {
            expect(wizard).to be_valid_to(:immigration_status)
          }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /not in flow path/)
        end
      end

      context 'when checking root step' do
        let(:current_step) { :name_and_date_of_birth }

        it 'passes for root step regardless of data' do
          expect(wizard).to be_valid_to(:name_and_date_of_birth)
        end
      end
    end
  end

  describe '#be_valid (single step)' do
    let(:steps_data) do
      { name_and_date_of_birth: { first_name: '', last_name: 'Doe', date_of_birth: '1990-01-01' } }
    end
    let(:current_step) { :nationality }

    it 'fails on invalid' do
      expect {
        expect(:name_and_date_of_birth).to be_valid_step.in(wizard)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Step invalid: :name_and_date_of_birth/)
    end

    it 'passes on valid' do
      state_store.save_steps(name_and_date_of_birth: { first_name: 'Valid', last_name: 'Doe',
                                                       date_of_birth: '1990-01-01' })
      expect(:name_and_date_of_birth).to be_valid_step.in(wizard)
    end
  end

  describe '#branch_to' do
    let(:steps_data) do
      { name_and_date_of_birth: { first_name: 'Alice', last_name: 'Smith', date_of_birth: '1980-02-22' },
        nationality: { nationalities: nationalities } }
    end

    let(:current_step) { :nationality }

    context 'for UK/Irish' do
      let(:nationalities) { 'british' }

      it 'branches to review from nationality' do
        expect(wizard).to branch_to(:review).from(:nationality)
      end
    end

    context 'for non-UK with right to work' do
      let(:nationalities) { 'french' }

      it 'branches to right_to_work_or_study from nationality' do
        expect(wizard).to branch_to(:right_to_work_or_study).from(:nationality)
      end
    end

    context 'when actual next step is different' do
      let(:nationalities) { 'french' }

      it 'fails with correct details' do
        expect {
          expect(wizard).to branch_to(:review).from(:nationality)
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Expected branch from :nationality to: :review/)
      end
    end
  end

  describe 'integration smoke tests' do
    let(:steps_data) do
      {
        name_and_date_of_birth: { first_name: 'Jean', last_name: 'Dupont', date_of_birth: '2000-01-01' },
        nationality: { nationalities: 'french' },
        right_to_work_or_study: { right_to_work_or_study: 'yes', visa_type: 'work', visa_expiry: '2026-12-31' },
        immigration_status: { status: 'settled' },
        review: {},
      }
    end

    let(:current_step) { :review }

    it 'allows full positive path' do
      expect(wizard).to be_at_step(:review)
      expect(:name_and_date_of_birth).to be_saved.in(wizard)
      expect(wizard).to have_in_flow(:review)
      expect(wizard).to be_valid_to(:review)
      expect(:review).to be_valid_step.in(wizard)
    end
  end
end
