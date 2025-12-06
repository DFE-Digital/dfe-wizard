RSpec.describe PersonalInformationWizard do
  let(:repository) { DfE::Wizard::Repository::InMemory.new }
  let(:state_store) { StateStores::PersonalInformation.new(repository: repository) }
  let(:current_step_params) { {} }
  let(:url_helpers) { Rails.application.routes.url_helpers }

  subject(:wizard) do
    described_class.new(
      current_step:,
      state_store:,
      current_step_params:,
    )
  end

  describe 'flow path traversal' do
    context 'when British national and not answered' do
      before do
        state_store.write(
          {
            first_name: 'John',
            last_name: 'Doe',
            date_of_birth: '1990-01-01',
          },
        )
      end

      context 'at nationality step' do
        let(:current_step) { :nationality }

        it { is_expected.to be_at_step(:nationality) }

        it 'returns flow path' do
          expect(wizard).to have_flow_path(%i[name_and_date_of_birth nationality])
          expect(wizard).to have_saved_path([:name_and_date_of_birth])
          expect(wizard.valid_path(:review)).to eq([:name_and_date_of_birth])
        end
      end
    end

    context 'when British national' do
      let(:british_national) do
        {
          first_name: 'John',
          last_name: 'Doe',
          date_of_birth: '1990-01-01',
          nationalities: 'british',
        }
      end

      context 'at nationality step' do
        let(:current_step) { :nationality }

        it 'branches directly to review (skip immigration flow)' do
          expect(wizard).to branch_from(:nationality).to(:review).when(british_national)
        end
      end

      context 'at review step' do
        let(:current_step) { :review }

        it { is_expected.to be_at_step(:review) }

        it 'flow path excludes immigration steps' do
          wizard.state_store.write(british_national)
          expect(wizard).to have_flow_path(%i[name_and_date_of_birth nationality review])
        end
      end
    end

    context 'when Irish national' do
      let(:irish_national) do
        {
          first_name: 'Patrick',
          last_name: 'Murphy',
          date_of_birth: '1988-03-17',
          nationalities: 'irish',
        }
      end

      let(:current_step) { :nationality }

      it 'branches directly to review (same as British)' do
        expect(wizard).to branch_from(:nationality).to(:review).when(irish_national)
      end
    end

    context 'when non-UK national with right to work' do
      before do
        state_store.write(
          {
            first_name: 'Jean',
            last_name: 'Dupont',
            date_of_birth: '1995-06-15',
            nationalities: 'french',
            right_to_work_or_study: 'yes',
            visa_type: 'work',
            visa_expiry: '2026-12-31',
            status: 'settled',
          },
        )
      end

      context 'at right_to_work_or_study step' do
        let(:current_step) { :right_to_work_or_study }

        it { is_expected.to be_at_step(:right_to_work_or_study) }

        it 'has correct saved path' do
          expect(wizard).to have_saved_path(
            %i[
              name_and_date_of_birth
              nationality
              right_to_work_or_study
            ],
          )
        end

        it 'branches to immigration_status when right to work' do
          expect(wizard).to branch_from(:right_to_work_or_study).to(:immigration_status)
        end
      end

      context 'at review step' do
        let(:current_step) { :review }

        it { is_expected.to be_at_step(:review) }

        it 'has correct saved path' do
          expect(wizard).to have_saved_path(
            %i[
              name_and_date_of_birth
              nationality
              right_to_work_or_study
              immigration_status
            ],
          )
        end

        it 'has correct flow path' do
          expect(wizard).to have_flow_path(
            %i[
              name_and_date_of_birth
              nationality
              right_to_work_or_study
              immigration_status
              review
            ],
          )
        end

        it 'flow path includes full immigration journey' do
          expect(wizard.flow_path).to eq(
            %i[
              name_and_date_of_birth
              nationality
              right_to_work_or_study
              immigration_status
              review
            ],
          )
        end
      end
    end

    context 'when non-UK national without right to work' do
      before do
        state_store.write({
                            first_name: 'Maria',
                            last_name: 'Garcia',
                            date_of_birth: '1992-03-22',
                            nationalities: 'spanish',
                            right_to_work_or_study: 'no',
                          })
      end

      context 'at right_to_work_or_study step' do
        let(:current_step) { :right_to_work_or_study }

        it { is_expected.to be_at_step(:right_to_work_or_study) }

        it 'branches directly to review (skip immigration_status)' do
          expect(wizard).to branch_from(:right_to_work_or_study).to(:review)
        end
      end

      context 'at review step' do
        let(:current_step) { :review }

        it { is_expected.to be_at_step(:review) }

        it 'has correct saved path' do
          expect(wizard).to have_saved_path(
            %i[
              name_and_date_of_birth
              nationality
              right_to_work_or_study
            ],
          )
        end

        it 'has correct flow path' do
          expect(wizard).to have_flow_path(
            %i[
              name_and_date_of_birth
              nationality
              right_to_work_or_study
              review
            ],
          )
        end

        it 'flow path excludes immigration_status' do
          expect(wizard.flow_path).to eq(
            %i[name_and_date_of_birth nationality right_to_work_or_study review],
          )
        end
      end
    end

    context 'with explicit target step' do
      before do
        state_store.write({
                            first_name: 'John',
                            last_name: 'Doe',
                            date_of_birth: '1990-01-01',
                            nationalities: 'british',
                          })
      end

      let(:current_step) { :name_and_date_of_birth }

      it { is_expected.to be_at_step(:name_and_date_of_birth) }

      it 'returns full path to target' do
        expect(wizard.flow_path(:review)).to eq(%i[name_and_date_of_birth nationality review])
      end
    end
  end

  describe '#next_step' do
    context 'from name_and_date_of_birth' do
      let(:current_step) { :name_and_date_of_birth }

      before do
        state_store.write({
                            first_name: 'John',
                            last_name: 'Doe',
                            date_of_birth: '1990-01-01',
                          })
      end

      it { is_expected.to be_at_step(:name_and_date_of_birth) }

      it 'has saved the current step' do
        expect(wizard).to have_saved_path([:name_and_date_of_birth])
      end

      it 'moves to nationality' do
        expect(wizard).to have_next_step(:nationality)
      end

      it 'returns correct path' do
        expect(wizard).to have_next_step_path(url_helpers.personal_information_nationality_path)
      end
    end

    context 'from nationality' do
      let(:current_step) { :nationality }

      before do
        state_store.write({
                            first_name: 'John',
                            last_name: 'Doe',
                            date_of_birth: '1990-01-01',
                            nationalities: nationality_value,
                          })
      end

      context 'UK national' do
        let(:nationality_value) { 'british' }

        it { is_expected.to be_at_step(:nationality) }

        it 'returns correct path' do
          expect(wizard).to have_next_step_path(url_helpers.personal_information_review_path)
        end

        it 'branches to review from nationality' do
          expect(wizard).to branch_from(:nationality).to(:review)
        end
      end

      context 'Irish national' do
        let(:nationality_value) { 'irish' }

        it 'branches to review from nationality' do
          expect(wizard).to branch_from(:nationality).to(:review)
        end
      end

      context 'non-UK national' do
        let(:nationality_value) { 'french' }

        it 'returns correct path' do
          expect(wizard).to have_next_step_path(
            url_helpers.personal_information_right_to_work_or_study_path,
          )
        end

        it 'branches to immigration flow from nationality' do
          expect(wizard).to branch_from(:nationality).to(:right_to_work_or_study)
        end
      end
    end

    context 'from right_to_work_or_study' do
      let(:current_step) { :right_to_work_or_study }

      before do
        state_store.write({
                            first_name: 'Jean',
                            last_name: 'Dupont',
                            date_of_birth: '1995-06-15',
                            nationalities: 'french',
                            right_to_work_or_study: has_right_to_work,
                            visa_type: 'work',
                            visa_expiry: '2026-12-31',
                          })
      end

      context 'with right to work' do
        let(:has_right_to_work) { 'yes' }

        it { is_expected.to be_at_step(:right_to_work_or_study) }

        it 'returns correct path' do
          expect(wizard).to have_next_step_path(
            url_helpers.personal_information_immigration_status_path,
          )
        end

        it 'branches to immigration_status' do
          expect(wizard).to branch_from(:right_to_work_or_study).to(:immigration_status)
        end
      end

      context 'without right to work' do
        let(:has_right_to_work) { 'no' }

        it 'returns correct path' do
          expect(wizard).to have_next_step_path(url_helpers.personal_information_review_path)
        end

        it 'branches to review' do
          expect(wizard).to branch_from(:right_to_work_or_study).to(:review)
        end
      end
    end

    context 'from immigration_status' do
      let(:current_step) { :immigration_status }

      before do
        state_store.write({
                            first_name: 'Test',
                            last_name: 'User',
                            date_of_birth: '1990-01-01',
                            nationalities: 'french',
                            right_to_work_or_study: 'yes',
                            visa_type: 'work',
                            visa_expiry: '2026-12-31',
                            status: 'settled',
                          })
      end

      it { is_expected.to be_at_step(:immigration_status) }

      it 'has saved right to work step' do
        expect(wizard).to have_saved_path(%i[
                                            name_and_date_of_birth
                                            nationality
                                            right_to_work_or_study
                                            immigration_status
                                          ])
      end

      it 'proceeds to review' do
        expect(wizard).to have_next_step(:review)
      end

      it 'returns correct path' do
        expect(wizard).to have_next_step_path(url_helpers.personal_information_review_path)
      end
    end

    context 'when return_to_review param given' do
      let(:current_step) { :name_and_date_of_birth }

      before do
        state_store.write({
                            first_name: 'John',
                            last_name: 'Doe',
                            date_of_birth: '1990-01-01',
                            nationalities: 'british',
                          })
      end

      context 'with valid path to review' do
        let(:current_step_params) { { return_to_review: 'name_and_date_of_birth' } }

        it 'returns review step' do
          expect(wizard).to have_next_step(:review)
        end
      end
    end
  end

  describe '#previous_step' do
    context 'when on immigration_status step' do
      let(:current_step) { :immigration_status }

      before do
        state_store.write({
                            first_name: 'Test',
                            last_name: 'User',
                            date_of_birth: '1990-01-01',
                            nationalities: 'french',
                            right_to_work_or_study: 'yes',
                            status: 'work',
                          })
      end

      it { is_expected.to be_at_step(:immigration_status) }

      it 'has saved right to work step' do
        expect(wizard).to have_saved_path(%i[
                                            name_and_date_of_birth
                                            nationality
                                            right_to_work_or_study
                                            immigration_status
                                          ])
      end

      it 'returns to right_to_work_or_study step' do
        expect(wizard).to have_previous_step(:right_to_work_or_study)
      end

      it 'returns correct path' do
        expect(wizard).to have_previous_step_path(
          url_helpers.personal_information_right_to_work_or_study_path,
        )
      end
    end

    context 'when on right_to_work_or_study step' do
      let(:current_step) { :right_to_work_or_study }

      before do
        state_store.write({
                            first_name: 'Test',
                            last_name: 'User',
                            date_of_birth: '1990-01-01',
                            nationalities: 'french',
                          })
      end

      it { is_expected.to be_at_step(:right_to_work_or_study) }

      it 'returns to nationality step' do
        expect(wizard).to have_previous_step(:nationality)
      end

      it 'returns correct path' do
        expect(wizard).to have_previous_step_path(url_helpers.personal_information_nationality_path)
      end
    end

    context 'when on nationality step' do
      let(:current_step) { :nationality }

      before do
        state_store.write({
                            first_name: 'Test',
                            last_name: 'User',
                            date_of_birth: '1990-01-01',
                          })
      end

      it { is_expected.to be_at_step(:nationality) }

      it 'returns to name_and_date_of_birth step' do
        expect(wizard).to have_previous_step(:name_and_date_of_birth)
      end

      it 'returns correct path' do
        expect(wizard).to have_previous_step_path(
          url_helpers.personal_information_name_and_date_of_birth_path,
        )
      end
    end

    context 'when on review step with UK nationality' do
      let(:current_step) { :review }

      before do
        state_store.write({
                            first_name: 'Test',
                            last_name: 'User',
                            date_of_birth: '1990-01-01',
                            nationalities: 'british',
                          })
      end

      it { is_expected.to be_at_step(:review) }

      it 'has saved nationality step' do
        expect(wizard).to have_saved_path(%i[
                                            name_and_date_of_birth
                                            nationality
                                          ])
      end

      it 'returns to nationality step' do
        expect(wizard).to have_previous_step(:nationality)
      end

      it 'returns correct path' do
        expect(wizard).to have_previous_step_path(url_helpers.personal_information_nationality_path)
      end
    end

    context 'when on review step with non-UK nationality and right to work' do
      let(:current_step) { :review }

      before do
        state_store.write({
                            first_name: 'Test',
                            last_name: 'User',
                            date_of_birth: '1990-01-01',
                            nationalities: 'french',
                            right_to_work_or_study: 'yes',
                            visa_type: 'work',
                            visa_expiry: '2026-12-31',
                            status: 'settled',
                          })
      end

      it { is_expected.to be_at_step(:review) }

      it 'has saved immigration_status step' do
        expect(wizard).to have_saved_path(%i[
                                            name_and_date_of_birth
                                            nationality
                                            right_to_work_or_study
                                            immigration_status
                                          ])
      end

      it 'has saved right_to_work_or_study step' do
        expect(wizard.saved_path).to include(:right_to_work_or_study)
      end

      it 'returns to immigration_status step' do
        expect(wizard).to have_previous_step(:immigration_status)
      end

      it 'returns correct path' do
        expect(wizard).to have_previous_step_path(
          url_helpers.personal_information_immigration_status_path,
        )
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
        state_store.write({
                            first_name: 'John',
                            last_name: 'Doe',
                            date_of_birth: '1990-01-01',
                            nationalities: 'british',
                          })
      end

      context 'when at origin step' do
        let(:current_step) { :nationality }

        it 'returns to review' do
          expect(wizard).to have_previous_step(:review)
        end
      end

      context 'when not at origin step' do
        let(:current_step) { :review }

        it 'returns previous visited step' do
          expect(wizard).to have_previous_step(:nationality)
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

  describe 'validation and accessibility' do
    context 'when all steps are valid' do
      let(:current_step) { :review }

      before do
        state_store.write({
                            first_name: 'John',
                            last_name: 'Doe',
                            date_of_birth: '1990-01-01',
                            nationalities: 'british',
                          })
      end

      it { is_expected.to be_at_step(:review) }
      it { is_expected.to be_valid_to(:review) }
      it { expect(:review).to be_valid_step.in(wizard) }
      it { expect(:name_and_date_of_birth).to be_valid_step.in(wizard) }
      it { expect(:nationality).to be_valid_step.in(wizard) }

      it 'review is accessible' do
        expect(wizard.valid_path_to?(:review)).to be true
      end

      it 'returns full flow path' do
        expect(wizard).to have_flow_path(%i[name_and_date_of_birth nationality review])
      end
    end

    context 'when path is incomplete' do
      let(:current_step) { :nationality }

      it 'review is not accessible without previous steps' do
        expect(wizard.valid_path_to?(:review)).to be false
      end

      it { expect(wizard).not_to be_valid_to(:review) }
    end

    context 'when step has invalid data' do
      let(:current_step) { :nationality }

      before do
        state_store.write({
                            first_name: '',
                            last_name: 'Doe',
                            date_of_birth: '1990-01-01',
                            nationalities: 'british',
                          })
      end

      it { expect(:name_and_date_of_birth).not_to be_valid_step.in(wizard) }
      it { expect(wizard).not_to be_valid_to(:review) }

      it 'name step is invalid' do
        expect(wizard.valid?(:name_and_date_of_birth)).to be false
      end

      it 'review is not accessible due to invalid previous step' do
        expect(wizard.valid_path_to?(:review)).to be false
      end
    end

    context 'with explicit target' do
      let(:current_step) { :name_and_date_of_birth }

      before do
        state_store.write({
                            first_name: 'John',
                            last_name: 'Doe',
                            date_of_birth: '1990-01-01',
                            nationalities: 'british',
                          })
      end

      it { is_expected.to be_valid_to(:review) }

      it 'review is accessible when all previous steps valid' do
        expect(wizard.valid_path_to?(:review)).to be true
      end
    end

    context 'with multiple invalid steps' do
      let(:current_step) { :review }

      before do
        state_store.write({
                            first_name: '',
                            last_name: '',
                            date_of_birth: '',
                            nationalities: '',
                          })
      end

      it { expect(wizard).not_to be_valid_to(:review) }
      it { expect(:name_and_date_of_birth).not_to be_valid_step.in(wizard) }
      it { expect(:nationality).not_to be_valid_step.in(wizard) }
    end
  end

  describe '#step' do
    let(:current_step) { :nationality }

    before do
      state_store.write({
                          nationalities: 'french',
                        })
    end

    it 'has saved the nationality step' do
      expect(wizard).to have_saved_path([:nationality])
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

  describe '#current_step' do
    let(:current_step) { :nationality }

    before do
      state_store.write({
                          nationalities: 'british',
                        })
    end

    it { is_expected.to be_at_step(:nationality) }

    it 'has saved the nationality step' do
      expect(wizard).to have_saved_path([:nationality])
    end

    it 'returns hydrated current step' do
      step = wizard.current_step
      expect(step).to be_instance_of(Steps::Nationality)
      expect(step.nationalities).to eq(['british'])
    end
  end
end
