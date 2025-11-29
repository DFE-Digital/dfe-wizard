RSpec.describe DfE::Wizard::Test::RSpecMatchers do
  let(:repository) { DfE::Wizard::Repository::InMemory.new }
  let(:state_store) { StateStores::PersonalInformation.new(repository:) }
  let(:current_step) { :name_and_date_of_birth }
  let(:steps_data) { {} }

  let(:wizard) do
    PersonalInformationWizard.new(
      current_step:,
      state_store:,
    )
  end

  before do
    repository.write(steps_data) if steps_data.any?
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

  describe 'list-based path matchers: flow, saved, valid' do
    let(:steps_data) do
      {
        first_name: 'John',
        last_name: 'Doe',
        date_of_birth: '1990-01-01',
        nationalities: 'british',
      }
    end
    let(:current_step) { :review }

    it 'matches flow_path exactly' do
      expect(wizard).to have_flow_path(%i[name_and_date_of_birth nationality review])
    end

    it 'matches saved_path exactly' do
      expect(wizard).to have_saved_path(%i[name_and_date_of_birth nationality])
    end

    it 'matches valid_path exactly, even if all steps are valid' do
      expect(wizard).to have_valid_path(%i[name_and_date_of_birth nationality review])
    end

    it 'fails if path does not match' do
      expect {
        expect(wizard).to have_flow_path(%i[name_and_date_of_birth review])
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Expected flow_path/)
      expect {
        expect(wizard).to have_saved_path(%i[name_and_date_of_birth review])
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Expected saved_path/)
      expect {
        expect(wizard).to have_valid_path(%i[name_and_date_of_birth review])
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Expected valid_path/)
    end
  end

  describe 'step object matchers for flow/saved/valid steps' do
    let(:steps_data) do
      {
        first_name: 'John',
        last_name: 'Doe',
        date_of_birth: '1990-01-01',
        nationalities: 'british',
      }
    end
    let(:current_step) { :review }

    let(:expected_steps) do
      [
        Steps::NameAndDateOfBirth.new(
          steps_data.slice(:first_name, :last_name, :date_of_birth).merge(
            step_id: :name_and_date_of_birth,
          ),
        ),
        Steps::Nationality.new(
          steps_data.slice(:nationalities).merge(
            step_id: :nationality,
          ),
        ),
        Steps::Review.new(step_id: :review),
      ]
    end

    it 'matches flow_steps by class and object equality' do
      expect(wizard).to have_flow_steps(expected_steps)
    end

    it 'matches saved_steps by class and object equality' do
      expect(wizard).to have_saved_steps(expected_steps[0..-2])
    end

    it 'matches valid_steps by class and object equality' do
      expect(wizard).to have_valid_steps(expected_steps)
    end

    it 'fails if expected and actual steps differ' do
      actual = wizard.flow_steps.dup
      bad_steps = actual.dup
      bad_steps.pop # remove one, so they are not the same
      expect {
        expect(wizard).to have_flow_steps(bad_steps)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Expected flow_steps/)
    end
  end

  describe '#be_valid_to' do
    let(:steps_data) do
      {
        first_name: '',
        last_name: 'Doe',
        date_of_birth: '1990-01-01',
        nationalities: 'british',
      }
    end
    let(:current_step) { :nationality }

    it 'passes if all steps to the target are valid' do
      repository.write({
                         first_name: 'Jane',
                         last_name: 'Smith',
                         date_of_birth: '1950-01-01',
                       })
      expect(wizard).to be_valid_to(:nationality)
    end

    it 'fails with full error diagnostic if any step invalid' do
      expect {
        expect(wizard).to be_valid_to(:nationality)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /step\(s\) invalid before reaching :nationality/)
    end
  end

  describe '#be_valid (single step)' do
    let(:steps_data) do
      {
        first_name: '',
        last_name: 'Doe',
        date_of_birth: '1990-01-01',
      }
    end
    let(:current_step) { :nationality }

    it 'fails on invalid' do
      expect {
        expect(:name_and_date_of_birth).to be_valid_step.in(wizard)
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /Step invalid: :name_and_date_of_birth/)
    end

    it 'passes on valid' do
      repository.write({
                         first_name: 'Valid',
                         last_name: 'Doe',
                         date_of_birth: '1990-01-01',
                       })
      expect(:name_and_date_of_birth).to be_valid_step.in(wizard)
    end
  end

  describe '#branch_from' do
    let(:steps_data) do
      {
        first_name: 'Alice',
        last_name: 'Smith',
        date_of_birth: '1980-02-22',
        nationalities: nationalities,
      }
    end
    let(:current_step) { :nationality }

    context 'for UK/Irish' do
      let(:nationalities) { 'british' }
      it 'branches to review from nationality' do
        expect(wizard).to branch_from(:nationality).to(:review).when(nationality: 'british')
      end
    end

    context 'for non-UK with right to work' do
      let(:nationalities) { 'french' }
      it 'branches to right_to_work_or_study from nationality' do
        expect(wizard).to branch_from(:nationality).to(:right_to_work_or_study).when(nationality: 'french')
      end
    end

    context 'when actual next step is different' do
      let(:nationalities) { 'french' }
      it 'fails with correct details' do
        expect {
          expect(wizard).to branch_from(:nationality).to(:review).when(nationality: 'french')
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError,
                         /Expected to branch from :nationality to: :review/)
      end
    end
  end

  describe 'attribute presence and value in state_store' do
    it 'matches attributes and values' do
      state_store.write(first_name: 'Graham', last_name: 'Lee')
      expect(state_store).to have_step_attribute(:first_name)
      expect(state_store).to have_step_attribute(:first_name).with_value('Graham')

      expect {
        expect(state_store).to have_step_attribute(:undefined_method).with_value('Graham')
      }.to raise_error(
        RSpec::Expectations::ExpectationNotMetError,
        /Expected :undefined_method to be "Graham", but got: nil/,
      )
    end
  end
end
