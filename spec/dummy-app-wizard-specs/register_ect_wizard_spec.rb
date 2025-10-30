# spec/wizards/register_ect_wizard_spec.rb

RSpec.describe RegisterECTWizard do
  let(:session) { {} }
  let(:step_params) { {} }

  subject(:wizard) do
    described_class.new(
      current_step: current_step,
      state_store: StateStores::SessionStore.new(session, 'register_ect'),
      step_params: ActionController::Parameters.new(step_params),
    )
  end

  describe '#path_traversal' do
    context 'exit paths from find_ect' do
      context 'TRN not found' do
        let(:current_step) { :trn_not_found }
        before { allow(wizard).to receive(:in_trs?).and_return(false) }

        it 'returns path ending at trn_not_found' do
          expect(wizard.path_traversal).to eq(%i[find_ect trn_not_found])
        end
      end

      context 'already active at school' do
        let(:current_step) { :already_active_at_school }
        before do
          allow(wizard).to receive(:in_trs?).and_return(true)
          allow(wizard).to receive(:matches_trs_dob?).and_return(true)
          allow(wizard).to receive(:active_at_school?).and_return(true)
        end

        it 'returns path ending at already_active_at_school' do
          expect(wizard.path_traversal).to eq(%i[find_ect already_active_at_school])
        end
      end

      context 'induction completed' do
        let(:current_step) { :induction_completed }

        before do
          allow(wizard).to receive(:in_trs?).and_return(true)
          allow(wizard).to receive(:matches_trs_dob?).and_return(true)
          allow(wizard).to receive(:active_at_school?).and_return(false)
          allow(wizard).to receive(:induction_completed?).and_return(true)
        end

        it 'returns path ending at induction_completed' do
          expect(wizard.path_traversal).to eq(%i[find_ect induction_completed])
        end
      end

      context 'induction exempt' do
        let(:current_step) { :induction_exempt }

        before do
          allow(wizard).to receive(:in_trs?).and_return(true)
          allow(wizard).to receive(:matches_trs_dob?).and_return(true)
          allow(wizard).to receive(:active_at_school?).and_return(false)
          allow(wizard).to receive(:induction_completed?).and_return(false)
          allow(wizard).to receive(:induction_exempt?).and_return(true)
        end

        it 'returns path ending at induction_exempt' do
          expect(wizard.path_traversal).to eq(%i[find_ect induction_exempt])
        end
      end

      context 'cannot register ECT' do
        let(:current_step) { :cannot_register_ect }

        before do
          allow(wizard).to receive(:in_trs?).and_return(true)
          allow(wizard).to receive(:matches_trs_dob?).and_return(true)
          allow(wizard).to receive(:active_at_school?).and_return(false)
          allow(wizard).to receive(:induction_completed?).and_return(false)
          allow(wizard).to receive(:induction_exempt?).and_return(false)
          allow(wizard).to receive(:prohibited_from_teaching?).and_return(true)
        end

        it 'returns path ending at cannot_register_ect' do
          expect(wizard.path_traversal).to eq(%i[find_ect cannot_register_ect])
        end
      end
    end

    context 'paths via national_insurance_number' do
      before do
        allow(wizard).to receive(:in_trs?).and_return(true)
        allow(wizard).to receive(:matches_trs_dob?).and_return(false)
      end

      context 'not found after NI number' do
        let(:current_step) { :not_found }
        before { allow(wizard).to receive(:in_trs?).and_return(false) }

        it 'returns path ending at not_found' do
          expect(wizard.path_traversal).to eq(%i[find_ect national_insurance_number not_found])
        end
      end

      context 'induction completed after NI number' do
        let(:current_step) { :induction_completed }
        before { allow(wizard).to receive(:induction_completed?).and_return(true) }

        it 'returns path ending at induction_completed' do
          expect(wizard.path_traversal).to eq(%i[find_ect national_insurance_number induction_completed])
        end
      end

      context 'induction exempt after NI number' do
        let(:current_step) { :induction_exempt }
        before { allow(wizard).to receive(:induction_exempt?).and_return(true) }

        it 'returns path ending at induction_exempt' do
          expect(wizard.path_traversal).to eq(%i[find_ect national_insurance_number induction_exempt])
        end
      end
    end

    context 'cant use email exit paths' do
      before do
        allow(wizard).to receive(:cant_use_email?).and_return(true)
      end

      context 'via direct path' do
        let(:current_step) { :cant_use_email }
        before { stub_wizard_to_email_address(wizard) }

        it 'returns path ending at cant_use_email' do
          expect(wizard.path_traversal).to eq(%i[find_ect review_ect_details email_address cant_use_email])
        end
      end

      context 'via national insurance number path' do
        let(:current_step) { :cant_use_email }
        before do
          stub_wizard_to_email_address_via_ni(wizard)
          allow(wizard).to receive(:cant_use_email?).and_return(true)
        end

        it 'returns path ending at cant_use_email via NI number' do
          expect(wizard.path_traversal).to eq(
            %i[
              find_ect national_insurance_number
              review_ect_details
              email_address
              cant_use_email
            ],
          )
        end
      end
    end

    context 'completion paths' do
      context 'independent school with lead provider' do
        let(:current_step) { :confirmation }
        before do
          stub_wizard_to_completion(wizard)
          allow(wizard).to receive(:school_independent?).and_return(true)
          allow(wizard).to receive(:provider_led?).and_return(true)
        end

        it 'returns full path via independent school and lead provider' do
          expected_path = %i[find_ect review_ect_details email_address start_date
                             working_pattern independent_school_appropriate_body
                             programme_type lead_provider check_answers confirmation]
          expect(wizard.path_traversal).to eq(expected_path)
        end
      end

      context 'independent school without lead provider' do
        let(:current_step) { :confirmation }
        before do
          stub_wizard_to_completion(wizard)
          allow(wizard).to receive(:school_independent?).and_return(true)
          allow(wizard).to receive(:provider_led?).and_return(false)
        end

        it 'returns full path via independent school without lead provider' do
          expected_path = %i[find_ect review_ect_details email_address start_date
                             working_pattern independent_school_appropriate_body
                             programme_type check_answers confirmation]
          expect(wizard.path_traversal).to eq(expected_path)
        end
      end

      context 'state school with lead provider' do
        let(:current_step) { :confirmation }
        before do
          stub_wizard_to_completion(wizard)
          allow(wizard).to receive(:school_independent?).and_return(false)
          allow(wizard).to receive(:provider_led?).and_return(true)
        end

        it 'returns full path via state school with lead provider' do
          expected_path = %i[find_ect review_ect_details email_address start_date
                             working_pattern state_school_appropriate_body
                             programme_type lead_provider check_answers confirmation]
          expect(wizard.path_traversal).to eq(expected_path)
        end
      end

      context 'state school without lead provider' do
        let(:current_step) { :confirmation }
        before do
          stub_wizard_to_completion(wizard)
          allow(wizard).to receive(:school_independent?).and_return(false)
          allow(wizard).to receive(:provider_led?).and_return(false)
        end

        it 'returns full path via state school without lead provider' do
          expected_path = %i[find_ect review_ect_details email_address start_date
                             working_pattern state_school_appropriate_body
                             programme_type check_answers confirmation]
          expect(wizard.path_traversal).to eq(expected_path)
        end
      end
    end

    context 'with explicit target step' do
      let(:current_step) { :find_ect }
      before { stub_wizard_to_completion(wizard) }

      it 'returns path to specified target' do
        expect(wizard.path_traversal(:check_answers)).to include(:find_ect, :check_answers)
      end
    end

    context 'unreachable target due to exit' do
      let(:current_step) { :cannot_register_ect }
      before do
        allow(wizard).to receive(:prohibited_from_teaching?).and_return(true)
      end

      it 'returns empty array for unreachable paths' do
        expect(wizard.path_traversal(:check_answers)).to eq([])
      end
    end
  end

  describe '#next_step' do
    context 'from find_ect' do
      let(:current_step) { :find_ect }

      context 'TRN not found' do
        before { allow(wizard).to receive(:in_trs?).and_return(false) }
        it 'returns trn_not_found' do
          expect(wizard.next_step).to eq(:trn_not_found)
        end
      end

      context 'DOB does not match' do
        before do
          allow(wizard).to receive(:in_trs?).and_return(true)
          allow(wizard).to receive(:matches_trs_dob?).and_return(false)
        end
        it 'returns national_insurance_number' do
          expect(wizard.next_step).to eq(:national_insurance_number)
        end
      end

      context 'already active at school' do
        before do
          allow(wizard).to receive(:in_trs?).and_return(true)
          allow(wizard).to receive(:matches_trs_dob?).and_return(true)
          allow(wizard).to receive(:active_at_school?).and_return(true)
        end
        it 'returns already_active_at_school' do
          expect(wizard.next_step).to eq(:already_active_at_school)
        end
      end

      context 'induction completed' do
        before do
          allow(wizard).to receive(:in_trs?).and_return(true)
          allow(wizard).to receive(:matches_trs_dob?).and_return(true)
          allow(wizard).to receive(:active_at_school?).and_return(false)
          allow(wizard).to receive(:induction_completed?).and_return(true)
        end
        it 'returns induction_completed' do
          expect(wizard.next_step).to eq(:induction_completed)
        end
      end

      context 'induction exempt' do
        before do
          allow(wizard).to receive(:in_trs?).and_return(true)
          allow(wizard).to receive(:matches_trs_dob?).and_return(true)
          allow(wizard).to receive(:active_at_school?).and_return(false)
          allow(wizard).to receive(:induction_completed?).and_return(false)
          allow(wizard).to receive(:induction_exempt?).and_return(true)
        end
        it 'returns induction_exempt' do
          expect(wizard.next_step).to eq(:induction_exempt)
        end
      end

      context 'prohibited from teaching' do
        before do
          allow(wizard).to receive(:in_trs?).and_return(true)
          allow(wizard).to receive(:matches_trs_dob?).and_return(true)
          allow(wizard).to receive(:active_at_school?).and_return(false)
          allow(wizard).to receive(:induction_completed?).and_return(false)
          allow(wizard).to receive(:induction_exempt?).and_return(false)
          allow(wizard).to receive(:prohibited_from_teaching?).and_return(true)
        end
        it 'returns cannot_register_ect' do
          expect(wizard.next_step).to eq(:cannot_register_ect)
        end
      end

      context 'eligible user' do
        before { stub_wizard_to_completion(wizard) }
        it 'returns review_ect_details' do
          expect(wizard.next_step).to eq(:review_ect_details)
        end
      end
    end

    context 'from national_insurance_number' do
      let(:current_step) { :national_insurance_number }

      context 'not found in TRS' do
        before { allow(wizard).to receive(:in_trs?).and_return(false) }
        it 'returns not_found' do
          expect(wizard.next_step).to eq(:not_found)
        end
      end

      context 'induction completed' do
        before do
          allow(wizard).to receive(:in_trs?).and_return(true)
          allow(wizard).to receive(:induction_completed?).and_return(true)
        end
        it 'returns induction_completed' do
          expect(wizard.next_step).to eq(:induction_completed)
        end
      end

      context 'induction exempt' do
        before do
          allow(wizard).to receive(:in_trs?).and_return(true)
          allow(wizard).to receive(:induction_completed?).and_return(false)
          allow(wizard).to receive(:induction_exempt?).and_return(true)
        end
        it 'returns induction_exempt' do
          expect(wizard.next_step).to eq(:induction_exempt)
        end
      end

      context 'eligible user' do
        before do
          allow(wizard).to receive(:in_trs?).and_return(true)
          allow(wizard).to receive(:induction_completed?).and_return(false)
          allow(wizard).to receive(:induction_exempt?).and_return(false)
        end
        it 'returns review_ect_details' do
          expect(wizard.next_step).to eq(:review_ect_details)
        end
      end
    end

    context 'from email_address' do
      let(:current_step) { :email_address }

      context 'cannot use email' do
        before { allow(wizard).to receive(:cant_use_email?).and_return(true) }
        it 'returns cant_use_email' do
          expect(wizard.next_step).to eq(:cant_use_email)
        end
      end

      context 'can use email' do
        before { allow(wizard).to receive(:cant_use_email?).and_return(false) }
        it 'returns start_date' do
          expect(wizard.next_step).to eq(:start_date)
        end
      end
    end

    context 'from working_pattern' do
      let(:current_step) { :working_pattern }

      context 'independent school' do
        before { allow(wizard).to receive(:school_independent?).and_return(true) }
        it 'returns independent_school_appropriate_body' do
          expect(wizard.next_step).to eq(:independent_school_appropriate_body)
        end
      end

      context 'state school' do
        before { allow(wizard).to receive(:school_independent?).and_return(false) }
        it 'returns state_school_appropriate_body' do
          expect(wizard.next_step).to eq(:state_school_appropriate_body)
        end
      end
    end

    context 'from programme_type' do
      let(:current_step) { :programme_type }

      context 'provider led' do
        before { allow(wizard).to receive(:provider_led?).and_return(true) }
        it 'returns lead_provider' do
          expect(wizard.next_step).to eq(:lead_provider)
        end
      end

      context 'not provider led' do
        before { allow(wizard).to receive(:provider_led?).and_return(false) }
        it 'returns check_answers' do
          expect(wizard.next_step).to eq(:check_answers)
        end
      end
    end

    context 'from exit pages' do
      exit_pages = %i[cannot_register_ect cant_use_email induction_completed
                      induction_exempt not_found trn_not_found already_active_at_school]

      exit_pages.each do |exit_page|
        context "from #{exit_page}" do
          let(:current_step) { exit_page }
          it 'returns nil (no next step)' do
            expect(wizard.next_step).to be_nil
          end
        end
      end
    end

    context 'return to review functionality' do
      let(:current_step) { :find_ect }
      let(:step_params) { { return_to_review: 'check_answers' } }

      context 'when wizard is complete to check_answers' do
        before { stub_wizard_to_completion(wizard) }

        it 'returns check_answers if user_up_to_check_answers?' do
          expect(wizard.next_step).to eq(:check_answers)
        end
      end

      context 'when wizard is not complete to check_answers' do
        before do
          allow(wizard).to receive(:prohibited_from_teaching?).and_return(true)
        end

        it 'follows normal flow if not user_up_to_check_answers?' do
          expect(wizard.next_step).to eq(:cannot_register_ect)
        end
      end
    end
  end

  describe '#previous_step' do
    context 'from confirmation' do
      let(:current_step) { :confirmation }
      it 'returns check_answers' do
        expect(wizard.previous_step).to eq(:check_answers)
      end
    end

    context 'from check_answers' do
      let(:current_step) { :check_answers }
      # Previous step depends on the path taken
      it 'returns the appropriate previous step based on path' do
        # This would be either :programme_type or :lead_provider depending on provider_led?
        expect(%i[programme_type lead_provider]).to include(wizard.previous_step)
      end
    end

    context 'from exit pages' do
      context 'from cannot_register_ect' do
        let(:current_step) { :cannot_register_ect }
        it 'returns find_ect' do
          expect(wizard.previous_step).to eq(:find_ect)
        end
      end

      context 'from not_found' do
        let(:current_step) { :not_found }
        it 'returns national_insurance_number' do
          expect(wizard.previous_step).to eq(:national_insurance_number)
        end
      end
    end

    context 'from root step' do
      let(:current_step) { :find_ect }
      it 'returns nil' do
        expect(wizard.previous_step).to be_nil
      end
    end
  end

  describe '#summary_steps' do
    let(:current_step) { :check_answers }
    before { stub_wizard_to_completion(wizard) }

    it 'returns steps in order with step_id assigned' do
      steps = wizard.summary_steps
      expect(steps.map(&:step_id)).to include(:find_ect, :review_ect_details, :check_answers)
      expect(steps.first.wizard).to eq(wizard)
    end
  end

  describe '#to_doc' do
    let(:current_step) { :find_ect }
    it 'generates a graphviz document' do
      expect(wizard.to_doc.to_s).to include('digraph')
    end
  end

  # Helper methods for stubbing wizard state
  def stub_wizard_to_completion(wizard)
    allow(wizard).to receive(:in_trs?).and_return(true)
    allow(wizard).to receive(:matches_trs_dob?).and_return(true)
    allow(wizard).to receive(:active_at_school?).and_return(false)
    allow(wizard).to receive(:induction_completed?).and_return(false)
    allow(wizard).to receive(:induction_exempt?).and_return(false)
    allow(wizard).to receive(:prohibited_from_teaching?).and_return(false)
    allow(wizard).to receive(:cant_use_email?).and_return(false)
    # Default school and provider settings can be overridden in specific contexts
    allow(wizard).to receive(:school_independent?).and_return(false)
    allow(wizard).to receive(:provider_led?).and_return(false)
  end

  def stub_wizard_to_email_address(wizard)
    allow(wizard).to receive(:in_trs?).and_return(true)
    allow(wizard).to receive(:matches_trs_dob?).and_return(true)
    allow(wizard).to receive(:active_at_school?).and_return(false)
    allow(wizard).to receive(:induction_completed?).and_return(false)
    allow(wizard).to receive(:induction_exempt?).and_return(false)
    allow(wizard).to receive(:prohibited_from_teaching?).and_return(false)
  end

  def stub_wizard_to_email_address_via_ni(wizard)
    allow(wizard).to receive(:in_trs?).and_return(true)
    allow(wizard).to receive(:matches_trs_dob?).and_return(false)
    allow(wizard).to receive(:induction_completed?).and_return(false)
    allow(wizard).to receive(:induction_exempt?).and_return(false)
  end
end
