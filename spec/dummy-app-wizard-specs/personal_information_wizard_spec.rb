RSpec.describe PersonalInformationWizard do
  subject(:wizard) do
    described_class.new(
      current_step:,
      state_store:,
      current_step_params:,
    )
  end

  let(:current_step_params) { {} }
  let(:state_store) do
    StateStores::PersonalInformation.new(repository: DfE::Wizard::Repository::InMemory.new)
  end
  let(:url_helpers) { Rails.application.routes.url_helpers }

  describe '#path_traversal' do
    context 'when British national' do
      before do
        state_store.save_steps(
          name_and_date_of_birth: { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' },
          nationality: { nationalities: 'british' },
        )
      end

      context 'at nationality step' do
        let(:current_step) { :nationality }

        it { is_expected.to be_at_step(:nationality) }
        it { is_expected.to have_visited(:name_and_date_of_birth, :nationality) }
        it { is_expected.to be_able_to_reach(:review) }
      end

      context 'at review step' do
        let(:current_step) { :review }

        it { is_expected.to be_at_step(:review) }
        it { is_expected.to have_visited(:name_and_date_of_birth, :nationality, :review) }
      end
    end

    context 'when non-UK national with right to work' do
      before do
        state_store.save_steps(
          name_and_date_of_birth: { first_name: 'Jean', last_name: 'Dupont', date_of_birth: '1995-06-15' },
          nationality: { nationalities: 'french' },
          right_to_work_or_study: { right_to_work_or_study: 'yes', visa_type: 'work', visa_expiry: '2026-12-31' },
          immigration_status: { status: 'settled' },
        )
      end

      context 'at right_to_work_or_study step' do
        let(:current_step) { :right_to_work_or_study }

        it { is_expected.to be_at_step(:right_to_work_or_study) }
        it { is_expected.to have_visited(:name_and_date_of_birth, :nationality, :right_to_work_or_study) }
        it { expect(:immigration_status).to be_reachable.in(wizard) }
      end

      context 'at review step' do
        let(:current_step) { :review }

        it { is_expected.to be_at_step(:review) }
        it {
          is_expected.to have_visited(
            :name_and_date_of_birth,
            :nationality,
            :right_to_work_or_study,
            :immigration_status,
            :review,
          )
        }
      end
    end

    context 'when non-UK national without right to work' do
      before do
        state_store.save_steps(
          name_and_date_of_birth: { first_name: 'Maria', last_name: 'Garcia', date_of_birth: '1992-03-22' },
          nationality: { nationalities: 'spanish' },
          right_to_work_or_study: { right_to_work_or_study: 'no' },
        )
      end

      context 'at right_to_work_or_study step' do
        let(:current_step) { :right_to_work_or_study }

        it { is_expected.to be_at_step(:right_to_work_or_study) }
        it { is_expected.to have_visited(:name_and_date_of_birth, :nationality, :right_to_work_or_study) }
        it { is_expected.to be_able_to_reach(:review) }
      end

      context 'at review step' do
        let(:current_step) { :review }

        it { is_expected.to be_at_step(:review) }
        it { is_expected.to have_visited(:name_and_date_of_birth, :nationality, :right_to_work_or_study, :review) }
      end
    end

    context 'with explicit target step' do
      before do
        state_store.save_steps(
          name_and_date_of_birth: { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' },
          nationality: { nationalities: 'british' },
        )
      end

      let(:current_step) { :name_and_date_of_birth }

      it { is_expected.to be_at_step(:name_and_date_of_birth) }
      it { is_expected.to be_able_to_reach(:review) }

      it 'returns path to specified target' do
        expect(wizard.path_traversal(:review)).to eq(%i[name_and_date_of_birth nationality review])
      end
    end
  end

  describe '#next_step' do
    context 'from name_and_date_of_birth' do
      let(:current_step) { :name_and_date_of_birth }

      before do
        state_store.save_steps(
          name_and_date_of_birth: { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' },
        )
      end

      it { is_expected.to be_at_step(:name_and_date_of_birth) }
      it { is_expected.to be_able_to_reach(:nationality) }

      it 'moves to nationality' do
        expect(wizard.next_step).to eq(:nationality)
      end

      it 'returns correct path' do
        expect(wizard).to have_next_step_path(url_helpers.personal_information_nationality_path)
      end
    end

    context 'from nationality' do
      let(:current_step) { :nationality }

      before do
        state_store.save_steps(
          name_and_date_of_birth: { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' },
          nationality: { nationalities: nationality_value },
        )
      end

      context 'UK national' do
        let(:nationality_value) { 'british' }

        it { is_expected.to be_at_step(:nationality) }
        it { is_expected.to be_able_to_reach(:review) }

        it 'skips to review' do
          expect(wizard.next_step).to eq(:review)
        end

        it 'returns correct path' do
          expect(wizard).to have_next_step_path(url_helpers.personal_information_review_path)
        end
      end

      context 'Irish national' do
        let(:nationality_value) { 'irish' }

        it { is_expected.to be_able_to_reach(:review) }

        it 'skips to review' do
          expect(wizard.next_step).to eq(:review)
        end
      end

      context 'non-UK national' do
        let(:nationality_value) { 'french' }

        it { is_expected.to be_able_to_reach(:right_to_work_or_study) }
        it { expect(:right_to_work_or_study).to be_reachable.in(wizard) }

        it 'proceeds to right_to_work_or_study' do
          expect(wizard.next_step).to eq(:right_to_work_or_study)
        end

        it 'returns correct path' do
          expect(wizard).to have_next_step_path(url_helpers.personal_information_right_to_work_or_study_path)
        end
      end
    end

    context 'from right_to_work_or_study' do
      let(:current_step) { :right_to_work_or_study }

      before do
        state_store.save_steps(
          name_and_date_of_birth: { first_name: 'Jean', last_name: 'Dupont', date_of_birth: '1995-06-15' },
          nationality: { nationalities: 'french' },
          right_to_work_or_study: { right_to_work_or_study: has_right_to_work, visa_type: 'work', visa_expiry: '2026-12-31' },
        )
      end

      context 'with right to work' do
        let(:has_right_to_work) { 'yes' }

        it { is_expected.to be_at_step(:right_to_work_or_study) }
        it { expect(:immigration_status).to be_reachable.in(wizard) }

        it 'proceeds to immigration_status' do
          expect(wizard.next_step).to eq(:immigration_status)
        end

        it 'returns correct path' do
          expect(wizard).to have_next_step_path(url_helpers.personal_information_immigration_status_path)
        end
      end

      context 'without right to work' do
        let(:has_right_to_work) { 'no' }

        it { is_expected.to be_able_to_reach(:review) }

        it 'proceeds to review' do
          expect(wizard.next_step).to eq(:review)
        end

        it 'returns correct path' do
          expect(wizard).to have_next_step_path(url_helpers.personal_information_review_path)
        end
      end
    end

    context 'from immigration_status' do
      let(:current_step) { :immigration_status }

      before do
        state_store.save_steps(
          name_and_date_of_birth: { first_name: 'Test', last_name: 'User', date_of_birth: '1990-01-01' },
          nationality: { nationalities: 'french' },
          right_to_work_or_study: { right_to_work_or_study: 'yes', visa_type: 'work', visa_expiry: '2026-12-31' },
          immigration_status: { status: 'settled' },
        )
      end

      it { is_expected.to be_at_step(:immigration_status) }
      it { is_expected.to have_visited(:right_to_work_or_study) }
      it { is_expected.to be_able_to_reach(:review) }

      it 'proceeds to review' do
        expect(wizard.next_step).to eq(:review)
      end

      it 'returns correct path' do
        expect(wizard).to have_next_step_path(url_helpers.personal_information_review_path)
      end
    end

    context 'when return_to_review param given' do
      let(:current_step) { :name_and_date_of_birth }

      before do
        state_store.save_steps(
          name_and_date_of_birth: { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' },
          nationality: { nationalities: 'british' },
        )
      end

      context 'with valid path to review' do
        let(:current_step_params) { { return_to_review: 'name_and_date_of_birth' } }

        it 'returns review step' do
          expect(wizard.next_step).to eq(:review)
        end
      end
    end
  end

  describe '#previous_step' do
    context 'when on immigration_status step' do
      let(:current_step) { :immigration_status }

      before do
        state_store.save_steps(
          name_and_date_of_birth: { first_name: 'Test', last_name: 'User', date_of_birth: '1990-01-01' },
          nationality: { nationalities: 'french' },
          right_to_work_or_study: { right_to_work_or_study: 'yes', visa_type: 'work', visa_expiry: '2026-12-31' },
        )
      end

      it { is_expected.to be_at_step(:immigration_status) }
      it { is_expected.to have_visited(:right_to_work_or_study) }

      it 'returns to right_to_work_or_study step' do
        expect(wizard.previous_step).to eq(:right_to_work_or_study)
      end

      it 'returns correct path' do
        expect(wizard).to have_previous_step_path(url_helpers.personal_information_right_to_work_or_study_path)
      end
    end

    context 'when on right_to_work_or_study step' do
      let(:current_step) { :right_to_work_or_study }

      before do
        state_store.save_steps(
          name_and_date_of_birth: { first_name: 'Test', last_name: 'User', date_of_birth: '1990-01-01' },
          nationality: { nationalities: 'french' },
        )
      end

      it { is_expected.to be_at_step(:right_to_work_or_study) }

      it 'returns to nationality step' do
        expect(wizard.previous_step).to eq(:nationality)
      end

      it 'returns correct path' do
        expect(wizard).to have_previous_step_path(url_helpers.personal_information_nationality_path)
      end
    end

    context 'when on nationality step' do
      let(:current_step) { :nationality }

      before do
        state_store.save_steps(
          name_and_date_of_birth: { first_name: 'Test', last_name: 'User', date_of_birth: '1990-01-01' },
        )
      end

      it { is_expected.to be_at_step(:nationality) }

      it 'returns to name_and_date_of_birth step' do
        expect(wizard.previous_step).to eq(:name_and_date_of_birth)
      end

      it 'returns correct path' do
        expect(wizard).to have_previous_step_path(url_helpers.personal_information_name_and_date_of_birth_path)
      end
    end

    context 'when on review step with UK nationality' do
      let(:current_step) { :review }

      before do
        state_store.save_steps(
          name_and_date_of_birth: { first_name: 'Test', last_name: 'User', date_of_birth: '1990-01-01' },
          nationality: { nationalities: 'british' },
        )
      end

      it { is_expected.to be_at_step(:review) }
      it { is_expected.to have_visited(:nationality) }

      it 'returns to nationality step' do
        expect(wizard.previous_step).to eq(:nationality)
      end

      it 'returns correct path' do
        expect(wizard).to have_previous_step_path(url_helpers.personal_information_nationality_path)
      end
    end

    context 'when on review step with non-UK nationality and right to work' do
      let(:current_step) { :review }

      before do
        state_store.save_steps(
          name_and_date_of_birth: { first_name: 'Test', last_name: 'User', date_of_birth: '1990-01-01' },
          nationality: { nationalities: 'french' },
          right_to_work_or_study: { right_to_work_or_study: 'yes', visa_type: 'work', visa_expiry: '2026-12-31' },
          immigration_status: { status: 'settled' },
        )
      end

      it { is_expected.to be_at_step(:review) }
      it { is_expected.to have_visited(:immigration_status, :right_to_work_or_study) }

      it 'returns to immigration_status step' do
        expect(wizard.previous_step).to eq(:immigration_status)
      end

      it 'returns correct path' do
        expect(wizard).to have_previous_step_path(url_helpers.personal_information_immigration_status_path)
      end
    end

    context 'when on first step' do
      let(:current_step) { :name_and_date_of_birth }

      it { is_expected.to be_at_step(:name_and_date_of_birth) }

      it 'returns nil' do
        expect(wizard.previous_step).to be_nil
      end

      it 'returns nil for path' do
        expect(wizard.previous_step_path).to be_nil
      end
    end

    context 'when return to review' do
      let(:origin) { 'nationality' }
      let(:current_step_params) { { return_to_review: origin } }

      before do
        state_store.save_steps(
          name_and_date_of_birth: { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' },
          nationality: { nationalities: 'british' },
        )
      end

      context 'when at origin step' do
        let(:current_step) { :nationality }

        it 'returns to review' do
          expect(wizard.previous_step).to eq(:review)
        end
      end

      context 'when not at origin step' do
        let(:current_step) { :review }

        it 'returns previous visited step' do
          expect(wizard.previous_step).to eq(:nationality)
        end
      end

      context 'when at first step' do
        let(:current_step) { :name_and_date_of_birth }

        it 'returns nil' do
          expect(wizard.previous_step).to be_nil
        end
      end
    end
  end

  describe '#step_accessible?' do
    context 'when all steps are valid' do
      let(:current_step) { :review }

      before do
        state_store.save_steps(
          name_and_date_of_birth: { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' },
          nationality: { nationalities: 'british' },
        )
      end

      it { is_expected.to be_at_step(:review) }
      it { is_expected.to have_valid_path_to(:review) }

      it 'review is accessible' do
        expect(wizard.step_accessible?(:review)).to be true
      end

      it 'returns full path' do
        expect(wizard.path_traversal(:review)).to eq(%i[name_and_date_of_birth nationality review])
      end
    end

    context 'when path is incomplete' do
      let(:current_step) { :nationality }

      it 'review is not accessible without previous steps' do
        expect(wizard.step_accessible?(:review)).to be false
      end
    end

    context 'when step has invalid data' do
      let(:current_step) { :nationality }

      before do
        state_store.save_steps(
          name_and_date_of_birth: { first_name: '', last_name: 'Doe', date_of_birth: '1990-01-01' },
          nationality: { nationalities: 'british' },
        )
      end

      it 'name step is invalid' do
        expect(wizard.step_valid?(:name_and_date_of_birth)).to be false
      end

      it 'review is not accessible due to invalid previous step' do
        expect(wizard.step_accessible?(:review)).to be false
      end
    end

    context 'with explicit target' do
      let(:current_step) { :name_and_date_of_birth }

      before do
        state_store.save_steps(
          name_and_date_of_birth: { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' },
          nationality: { nationalities: 'british' },
        )
      end

      it { is_expected.to have_valid_path_to(:review) }

      it 'review is accessible when all previous steps valid' do
        expect(wizard.step_accessible?(:review)).to be true
      end
    end
  end

  describe '#step' do
    let(:current_step) { :nationality }

    before do
      state_store.save_steps(
        nationality: { nationalities: 'french' },
      )
    end

    it 'returns hydrated step object' do
      step = wizard.step(:nationality)
      expect(step).to be_instance_of(Steps::Nationality)
      expect(step.nationalities).to eq(['french'])
    end

    it 'caches step objects' do
      step1 = wizard.step(:nationality)
      step2 = wizard.step(:nationality)
      expect(step1).to equal(step2)
    end

    context 'when step has no data' do
      it 'returns step with empty data' do
        step = wizard.step(:review)
        expect(step).to be_instance_of(Steps::Review)
        expect(step.attributes).to be_empty
      end
    end
  end

  describe '#current_step_object' do
    let(:current_step) { :nationality }

    before do
      state_store.save_steps(
        nationality: { nationalities: 'british' },
      )
    end

    it { is_expected.to be_at_step(:nationality) }

    it 'returns hydrated current step' do
      step = wizard.current_step_object
      expect(step).to be_instance_of(Steps::Nationality)
      expect(step.nationalities).to eq(['british'])
    end
  end

  describe '#to_doc' do
    let(:current_step) { :name_and_date_of_birth }

    it 'returns a valid documentation' do
      expected = File.read('spec/fixtures/personal_information_wizard.dot')
      expect(wizard.to_doc.to_s).to eq(expected)
    end
  end
end
