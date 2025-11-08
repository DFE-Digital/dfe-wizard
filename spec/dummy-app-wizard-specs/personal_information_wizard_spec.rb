require 'spec_helper'

RSpec.describe PersonalInformationWizard do
  subject(:wizard) do
    described_class.new(
      current_step:,
      state_store:,
      step_params:,
    )
  end

  let(:state_store) do
    StateStores::PersonalInformation.new(
      session:,
      key: :personal_information_wizard,
    )
  end
  let(:step_params) { {} }
  let(:session) { {} }

  describe '#path_traversal' do
    context 'when British national' do
      before do
        state_store.write_step(:name_and_date_of_birth,
                               { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' })
        state_store.write_step(:nationality, { nationalities: 'british' })
      end

      context 'at nationality step' do
        let(:current_step) { :nationality }

        it 'returns path from start to nationality' do
          expect(wizard.path_traversal).to eq(%i[name_and_date_of_birth nationality])
        end
      end

      context 'at review step' do
        let(:current_step) { :review }

        it 'returns direct path from start to review via nationality' do
          expect(wizard.path_traversal).to eq(%i[name_and_date_of_birth nationality review])
        end
      end
    end

    context 'when non-UK national with right to work' do
      before do
        state_store.write_step(:name_and_date_of_birth,
                               { first_name: 'Jean', last_name: 'Dupont', date_of_birth: '1995-06-15' })
        state_store.write_step(:nationality, { nationalities: 'french' })
        state_store.write_step(:right_to_work_or_study,
                               { right_to_work_or_study: 'yes', visa_type: 'work', visa_expiry: '2026-12-31' })
        state_store.write_step(:immigration_status, { status: 'settled' })
      end

      context 'at right_to_work_or_study step' do
        let(:current_step) { :right_to_work_or_study }

        it 'returns path from start to right_to_work_or_study' do
          expected_path = %i[name_and_date_of_birth nationality right_to_work_or_study]
          expect(wizard.path_traversal).to eq(expected_path)
        end
      end

      context 'at review step' do
        let(:current_step) { :review }

        it 'returns path from start to review via right_to_work_or_study and immigration_status' do
          expected_path = %i[name_and_date_of_birth nationality right_to_work_or_study immigration_status review]
          expect(wizard.path_traversal).to eq(expected_path)
        end
      end
    end

    context 'when non-UK national without right to work' do
      before do
        state_store.write_step(:name_and_date_of_birth,
                               { first_name: 'Maria', last_name: 'Garcia', date_of_birth: '1992-03-22' })
        state_store.write_step(:nationality, { nationalities: 'spanish' })
        state_store.write_step(:right_to_work_or_study, { right_to_work_or_study: 'no' })
      end

      context 'at right_to_work_or_study step' do
        let(:current_step) { :right_to_work_or_study }

        it 'returns path from start to right_to_work_or_study' do
          expected_path = %i[name_and_date_of_birth nationality right_to_work_or_study]
          expect(wizard.path_traversal).to eq(expected_path)
        end
      end

      context 'at review step' do
        let(:current_step) { :review }

        it 'returns path skipping immigration_status' do
          expected_path = %i[name_and_date_of_birth nationality right_to_work_or_study review]
          expect(wizard.path_traversal).to eq(expected_path)
        end
      end
    end

    context 'with explicit target step' do
      before do
        state_store.write_step(:name_and_date_of_birth,
                               { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' })
        state_store.write_step(:nationality, { nationalities: 'british' })
      end

      let(:current_step) { :name_and_date_of_birth }

      it 'returns path to specified target' do
        expect(wizard.path_traversal(:review)).to eq(%i[name_and_date_of_birth nationality review])
      end
    end

    context 'with explicit data' do
      let(:current_step) { :name_and_date_of_birth }

      let(:non_uk_data) do
        {
          steps: {
            name_and_date_of_birth: { first_name: 'Test', last_name: 'User', date_of_birth: '1990-01-01' },
            nationality: { nationalities: 'french' },
            right_to_work_or_study: { right_to_work_or_study: 'yes' },
          },
        }
      end

      it 'uses explicit data for traversal' do
        expected_path = %i[
          name_and_date_of_birth
          nationality
          right_to_work_or_study
          immigration_status
        ]

        expect(wizard.path_traversal(:immigration_status, non_uk_data)).to eq(expected_path)
      end
    end
  end

  describe '#next_step' do
    context 'from name_and_date_of_birth' do
      let(:current_step) { :name_and_date_of_birth }

      before do
        state_store.write_step(:name_and_date_of_birth,
                               { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' })
      end

      it 'moves to nationality' do
        expect(wizard.next_step).to eq(:nationality)
      end

      it 'returns correct path' do
        expect(wizard.next_step_path).to eq('/personal-information/nationality')
      end
    end

    context 'from nationality' do
      let(:current_step) { :nationality }

      before do
        state_store.write_step(:name_and_date_of_birth,
                               { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' })
        state_store.write_step(:nationality, { nationalities: nationality_value })
      end

      context 'UK national' do
        let(:nationality_value) { 'british' }

        it 'skips to review' do
          expect(wizard.next_step).to eq(:review)
        end

        it 'returns correct path' do
          expect(wizard.next_step_path).to eq('/personal-information/review')
        end
      end

      context 'Irish national' do
        let(:nationality_value) { 'irish' }

        it 'skips to review' do
          expect(wizard.next_step).to eq(:review)
        end
      end

      context 'non-UK national' do
        let(:nationality_value) { 'french' }

        it 'proceeds to right_to_work_or_study' do
          expect(wizard.next_step).to eq(:right_to_work_or_study)
        end

        it 'returns correct path' do
          expect(wizard.next_step_path).to eq('/personal-information/right-to-work-or-study')
        end
      end
    end

    context 'from right_to_work_or_study' do
      let(:current_step) { :right_to_work_or_study }

      before do
        state_store.write_step(:name_and_date_of_birth,
                               { first_name: 'Jean', last_name: 'Dupont', date_of_birth: '1995-06-15' })
        state_store.write_step(:nationality, { nationalities: 'french' })
        state_store.write_step(:right_to_work_or_study,
                               { right_to_work_or_study: has_right_to_work, visa_type: 'work',
                                 visa_expiry: '2026-12-31' })
      end

      context 'with right to work' do
        let(:has_right_to_work) { 'yes' }

        it 'proceeds to immigration_status' do
          expect(wizard.next_step).to eq(:immigration_status)
        end

        it 'returns correct path' do
          expect(wizard.next_step_path).to eq('/personal-information/immigration-status')
        end
      end

      context 'without right to work' do
        let(:has_right_to_work) { 'no' }

        it 'proceeds to review' do
          expect(wizard.next_step).to eq(:review)
        end

        it 'returns correct path' do
          expect(wizard.next_step_path).to eq('/personal-information/review')
        end
      end
    end

    context 'from immigration_status' do
      let(:current_step) { :immigration_status }

      before do
        state_store.write_step(:name_and_date_of_birth,
                               { first_name: 'Test', last_name: 'User', date_of_birth: '1990-01-01' })
        state_store.write_step(:nationality, { nationalities: 'french' })
        state_store.write_step(:right_to_work_or_study,
                               { right_to_work_or_study: 'yes', visa_type: 'work', visa_expiry: '2026-12-31' })
        state_store.write_step(:immigration_status, { status: 'settled' })
      end

      it 'proceeds to review' do
        expect(wizard.next_step).to eq(:review)
      end

      it 'returns correct path' do
        expect(wizard.next_step_path).to eq('/personal-information/review')
      end
    end

    context 'when return_to_review param given' do
      let(:current_step) { :name_and_date_of_birth }

      before do
        state_store.write_step(:name_and_date_of_birth,
                               { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' })
        state_store.write_step(:nationality, { nationalities: 'british' })
        state_store.write(return_to_review: :name_and_date_of_birth)
      end

      context 'with valid path to review' do
        let(:step_params) { { return_to_review: :name_and_date_of_birt } }

        it 'returns review step' do
          expect(wizard.next_step).to eq(:review)
        end
      end

      context 'with invalid step in return_to_review' do
        before do
          state_store.write(return_to_review: :nonexistent_step)
        end

        it 'returns normal next step' do
          expect(wizard.next_step).to eq(:nationality)
        end
      end
    end
  end

  describe '#previous_step' do
    context 'when on immigration_status step' do
      let(:current_step) { :immigration_status }

      before do
        state_store.write_step(:name_and_date_of_birth,
                               { first_name: 'Test', last_name: 'User', date_of_birth: '1990-01-01' })
        state_store.write_step(:nationality, { nationalities: 'french' })
        state_store.write_step(:right_to_work_or_study,
                               { right_to_work_or_study: 'yes', visa_type: 'work', visa_expiry: '2026-12-31' })
      end

      it 'returns to right_to_work_or_study step' do
        expect(wizard.previous_step).to eq(:right_to_work_or_study)
      end

      it 'returns correct path' do
        expect(wizard.previous_step_path).to eq('/personal-information/right-to-work-or-study')
      end
    end

    context 'when on right_to_work_or_study step' do
      let(:current_step) { :right_to_work_or_study }

      before do
        state_store.write_step(:name_and_date_of_birth,
                               { first_name: 'Test', last_name: 'User', date_of_birth: '1990-01-01' })
        state_store.write_step(:nationality, { nationalities: 'french' })
      end

      it 'returns to nationality step' do
        expect(wizard.previous_step).to eq(:nationality)
      end

      it 'returns correct path' do
        expect(wizard.previous_step_path).to eq('/personal-information/nationality')
      end
    end

    context 'when on nationality step' do
      let(:current_step) { :nationality }

      before do
        state_store.write_step(:name_and_date_of_birth,
                               { first_name: 'Test', last_name: 'User', date_of_birth: '1990-01-01' })
      end

      it 'returns to name_and_date_of_birth step' do
        expect(wizard.previous_step).to eq(:name_and_date_of_birth)
      end

      it 'returns correct path' do
        expect(wizard.previous_step_path).to eq('/personal-information/name-and-date-of-birth')
      end
    end

    context 'when on review step with UK nationality' do
      let(:current_step) { :review }

      before do
        state_store.write_step(:name_and_date_of_birth,
                               { first_name: 'Test', last_name: 'User', date_of_birth: '1990-01-01' })
        state_store.write_step(:nationality, { nationalities: 'british' })
      end

      it 'returns to nationality step' do
        expect(wizard.previous_step).to eq(:nationality)
      end

      it 'returns correct path' do
        expect(wizard.previous_step_path).to eq('/personal-information/nationality')
      end
    end

    context 'when on review step with non-UK nationality and right to work' do
      let(:current_step) { :review }

      before do
        state_store.write_step(:name_and_date_of_birth,
                               { first_name: 'Test', last_name: 'User', date_of_birth: '1990-01-01' })
        state_store.write_step(:nationality, { nationalities: 'french' })
        state_store.write_step(:right_to_work_or_study,
                               { right_to_work_or_study: 'yes', visa_type: 'work', visa_expiry: '2026-12-31' })
        state_store.write_step(:immigration_status, { status: 'settled' })
      end

      it 'returns to immigration_status step' do
        expect(wizard.previous_step).to eq(:immigration_status)
      end

      it 'returns correct path' do
        expect(wizard.previous_step_path).to eq('/personal-information/immigration-status')
      end
    end

    context 'when on first step' do
      let(:current_step) { :name_and_date_of_birth }

      it 'returns nil' do
        expect(wizard.previous_step).to be_nil
      end

      it 'returns nil for path' do
        expect(wizard.previous_step_path).to be_nil
      end
    end
  end

  describe '#validated_path_to' do
    context 'when all steps are valid' do
      let(:current_step) { :review }

      before do
        state_store.write_step(:name_and_date_of_birth,
                               { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' })
        state_store.write_step(:nationality, { nationalities: 'british' })
      end

      it 'returns all step identifiers' do
        expect(wizard.validated_path_to).to eq(%i[name_and_date_of_birth nationality review])
      end
    end

    context 'when path is incomplete' do
      let(:current_step) { :nationality }
      let(:state_store) {
        StateStores::PersonalInformation.new(
          session:,
          key: :application_form,
        )
      }

      it 'returns empty' do
        expect(wizard.validated_path_to).to eq([])
      end
    end

    context 'when step has invalid data' do
      let(:current_step) { :nationality }

      before do
        state_store.write_step(:name_and_date_of_birth,
                               { first_name: '', last_name: 'Doe', date_of_birth: '1990-01-01' })
        state_store.write_step(:nationality, { nationalities: 'british' })
      end

      it 'returns empty' do
        expect(wizard.validated_path_to).to eq([])
      end
    end

    context 'with explicit target' do
      let(:current_step) { :name_and_date_of_birth }

      before do
        state_store.write_step(:name_and_date_of_birth,
                               { first_name: 'John', last_name: 'Doe', date_of_birth: '1990-01-01' })
        state_store.write_step(:nationality, { nationalities: 'british' })
      end

      it 'validates path to target' do
        expect(wizard.validated_path_to(:review)).to eq(%i[name_and_date_of_birth nationality review])
      end
    end
  end

  describe '#step' do
    let(:current_step) { :nationality }

    before do
      state_store.write_step(:nationality, { nationalities: 'french' })
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
      state_store.write_step(:nationality, { nationalities: 'british' })
    end

    it 'returns hydrated current step' do
      step = wizard.current_step_object
      expect(step).to be_instance_of(Steps::Nationality)
      expect(step.nationalities).to eq(['british'])
    end
  end

  describe '#to_doc' do
    let(:current_step) { :name_and_date_of_birth }
    let(:application_form) { build(:application_form) }

    it 'returns a valid documentation' do
      expected = File.read('spec/fixtures/personal_information_wizard.dot')
      expect(wizard.to_doc.to_s).to eq(expected)
    end
  end
end
