RSpec.describe RegisterECTWizard do
  let(:repository) { DfE::Wizard::Repository::InMemory.new }
  let(:state_store) { StateStores::RegisterECTStore.new(repository:) }
  let(:step_params) { {} }

  subject(:wizard) do
    described_class.new(
      current_step:,
      state_store:,
      current_step_params: step_params,
    )
  end

  describe '#next_step' do
    context 'from find_ect' do
      let(:current_step) { :find_ect }

      it { expect(wizard).to have_next_step(:trn_not_found).from(:find_ect).when(trn: '0000000') }
      it { expect(wizard).to have_next_step(:national_insurance_number).from(:find_ect).when(trn: '1111111') }
      it { expect(wizard).to have_next_step(:already_active_at_school).from(:find_ect).when(trn: '2222222') }
      it { expect(wizard).to have_next_step(:induction_completed).from(:find_ect).when(trn: '3333333') }
      it { expect(wizard).to have_next_step(:induction_exempt).from(:find_ect).when(trn: '4444444') }
      it { expect(wizard).to have_next_step(:induction_failed).from(:find_ect).when(trn: '6666666') }
      it { expect(wizard).to have_next_step(:cannot_register_ect).from(:find_ect).when(trn: '5555555') }

      it 'routes eligible users to review_ect_details' do
        expect(wizard).to have_next_step(:review_ect_details).from(:find_ect).when(trn: '9999999')
      end
    end

    context 'from national_insurance_number' do
      let(:current_step) { :national_insurance_number }

      it { expect(wizard).to have_next_step(:not_found).from(:national_insurance_number).when(trn: '0000000') }
      it { expect(wizard).to have_next_step(:induction_completed).from(:national_insurance_number).when(trn: '3333333') }
      it { expect(wizard).to have_next_step(:induction_exempt).from(:national_insurance_number).when(trn: '4444444') }

      it 'returns review_ect_details for eligible users' do
        expect(wizard).to have_next_step(:review_ect_details).from(:national_insurance_number).when(trn: '9999999')
      end
    end

    context 'from email_address' do
      let(:current_step) { :email_address }

      it 'branches to cant_use_email' do
        state_store.write(email: 'taken@example.com')
        expect(wizard).to have_next_step(:cant_use_email)
      end

      it 'moves to start_date when email allowed' do
        state_store.write(email: 'free@example.com')
        expect(wizard).to have_next_step(:start_date)
      end
    end

    context 'from working_pattern' do
      let(:current_step) { :working_pattern }

      it 'branches to independent_school_appropriate_body' do
        state_store.write(school_type: 'independent')
        expect(wizard).to have_next_step(:independent_school_appropriate_body)
      end

      it 'branches to state_school_appropriate_body' do
        state_store.write(school_type: 'state')
        expect(wizard).to have_next_step(:state_school_appropriate_body)
      end
    end

    context 'from programme_type' do
      let(:current_step) { :programme_type }

      it 'branches to lead_provider' do
        state_store.write(training_programme: 'provider_led')
        expect(wizard).to have_next_step(:lead_provider)
      end

      it 'branches to check_answers' do
        state_store.write(training_programme: 'school_led')
        expect(wizard).to have_next_step(:check_answers)
      end
    end

    context 'from exit pages' do
      %i[cannot_register_ect cant_use_email induction_completed
         induction_exempt not_found trn_not_found already_active_at_school].each do |exit_page|
        context exit_page.to_s do
          let(:current_step) { exit_page }

          it 'has no next step' do
            expect(wizard.next_step).to be_nil
          end
        end
      end
    end

    context 'return to review' do
      let(:current_step) { :find_ect }

      it 'short-circuits to check_answers when the path reaches CYA' do
        stub_eligible_path(wizard)
        allow(wizard).to receive(:next_step_override).and_return(:check_answers)
        expect(wizard).to have_next_step(:check_answers)
      end

      it 'follows normal flow when CYA is unreachable' do
        allow(wizard).to receive_messages(in_trs?: true, prohibited_from_teaching?: true)
        expect(wizard).to have_next_step(:cannot_register_ect)
      end
    end
  end

  describe '#flow_path' do
    context 'exit paths from find_ect' do
      let(:current_step) { :trn_not_found }

      before { state_store.write(trn: '0000000') }

      it { expect(wizard).to have_flow_path(%i[find_ect trn_not_found]) }
    end

    context 'cant use email branch' do
      let(:current_step) { :cant_use_email }

      before do
        stub_eligible_path(wizard)
        wizard.state_store.write(
          trn: '9999999',
          date_of_birth: Date.new(2000, 1, 1),
          email: 'taken@example.com',
          cant_use_email: true,
          school_type: 'state',
          training_programme: 'school_led',
        )
      end

      it { expect(wizard.flow_path(:cant_use_email)).to eq(%i[find_ect review_ect_details email_address cant_use_email]) }
    end

    context 'independent school with lead provider' do
      let(:current_step) { :confirmation }

      before do
        wizard.state_store.write(
          trn: '9999999',
          date_of_birth: Date.new(2000, 1, 1),
          email: 'free@example.com',
          school_type: 'independent',
          training_programme: 'provider_led',
        )
      end

      it 'includes independent appropriate body and lead provider' do
        expect(wizard.flow_path).to eq(
          %i[
            find_ect
            review_ect_details
            email_address
            start_date
            working_pattern
            independent_school_appropriate_body
            programme_type
            lead_provider
            check_answers
            confirmation
          ],
        )
      end
    end

    context 'state school without lead provider' do
      let(:current_step) { :confirmation }

      before do
        stub_eligible_path(wizard)
        state_store.write(school_type: 'state', training_programme: 'school_led')
      end

      it 'includes state school appropriate body and skips lead provider' do
        expect(wizard.flow_path).to eq(
          %i[
            find_ect
            review_ect_details
            email_address
            start_date
            working_pattern
            state_school_appropriate_body
            programme_type
            check_answers
            confirmation
          ],
        )
      end
    end

    context 'unreachable target' do
      let(:current_step) { :cannot_register_ect }

      before do
        allow(wizard).to receive_messages(in_trs?: true, prohibited_from_teaching?: true)
      end

      it 'returns empty path when target is blocked' do
        expect(wizard.flow_path(:check_answers)).to eq([])
      end
    end
  end

  describe '#valid_path_to?' do
    let(:current_step) { :confirmation }

    before do
      wizard.state_store.write(
        trn: '9999999',
        date_of_birth: Date.new(2000, 1, 1),
        details_correct: 'yes',
        email: 'free@example.com',
        school_type: 'state',
        training_programme: 'school_led',
      )
    end

    it 'is valid through to confirmation on the happy path' do
      expect(wizard).to be_valid_to(:confirmation)
      expect(wizard.flow_path).to eq(
        %i[
          find_ect
          review_ect_details
          email_address
          start_date
          working_pattern
          state_school_appropriate_body
          programme_type
          check_answers
          confirmation
        ],
      )
    end
  end

  describe '#previous_step' do
    context 'from confirmation' do
      let(:current_step) { :confirmation }

      before { stub_eligible_path(wizard) }

      it { expect(wizard).to have_previous_step(:check_answers) }
    end

    context 'from check_answers' do
      let(:current_step) { :check_answers }

      it 'returns programme_type when not provider led' do
        state_store.write(training_programme: 'school_led')
        expect(wizard).to have_previous_step(:programme_type)
      end

      it 'returns lead_provider when provider led' do
        state_store.write(training_programme: 'provider_led')
        expect(wizard).to have_previous_step(:lead_provider)
      end

      context 'when returning to review' do
        let(:step_params) { { check_answers: { return_to_review: 'review_ect_details' } } }

        before do
          stub_eligible_path(wizard)
        end

        it 'short-circuits back to the requested review step' do
          expect(wizard).to have_previous_step(:review_ect_details)
        end
      end
    end

    context 'from cannot_register_ect' do
      let(:current_step) { :cannot_register_ect }

      before do
        allow(wizard).to receive_messages(in_trs?: true, prohibited_from_teaching?: true)
      end

      it { expect(wizard).to have_previous_step(:find_ect) }
    end

    context 'from not_found' do
      let(:current_step) { :not_found }

      before do
        state_store.write(trn: '1111111')
        allow(wizard).to receive(:find_ect_transitions).and_return(:national_insurance_number)
        allow(wizard).to receive(:national_insurance_number_transitions).and_return(:not_found)
      end

      it { expect(wizard).to have_previous_step(:national_insurance_number) }
    end

    context 'from root' do
      let(:current_step) { :find_ect }

      it { expect(wizard.previous_step).to be_nil }
      it { expect(wizard.previous_step_path).to be_nil }
    end
  end

  def stub_eligible_path(wizard)
    wizard.state_store.write(
      trn: '9999999',
      date_of_birth: Date.new(2000, 1, 1),
      email: 'free@example.com',
      school_type: 'state',
      training_programme: 'school_led',
    )
  end
end
