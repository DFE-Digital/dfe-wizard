RSpec.describe AssignMentorWizard do
  subject(:wizard) do
    described_class.new(
      current_step: current_step,
      state_store: DfE::Wizard::StateStore::Session.new(session:, key: 'assign_mentor'),
      step_params: ActionController::Parameters.new(step_params),
    )
  end

  let(:session) { {} }
  let(:step_params) { {} }

  describe '#path_traversal' do
    context 'at who_will_be_the_mentor step' do
      let(:current_step) { :who_will_be_the_mentor }

      it 'returns path from start to who_will_be_the_mentor' do
        expect(wizard.path_traversal).to eq(%i[who_will_be_the_mentor])
      end
    end

    context 'when the lead provider will provide training' do
      context 'at can_receive_mentor_training step' do
        let(:current_step) { :can_receive_mentor_training }

        it 'returns path from start to can_receive_mentor_training' do
          expect(wizard.path_traversal).to eq(%i[
                                                who_will_be_the_mentor
                                                can_receive_mentor_training
                                              ])
        end
      end

      context 'at confirmation step' do
        let(:current_step) { :confirmation }

        it 'returns direct path from start to confirmation' do
          expect(wizard.path_traversal).to eq(%i[
                                                who_will_be_the_mentor
                                                can_receive_mentor_training
                                                confirmation
                                              ])
        end
      end
    end

    context 'when lead provider will not be providing training' do
      let(:session) do
        {
          'assign_mentor' => {
            'steps' => {
              'can_receive_mentor_training' => { 'lp_will_provide' => 'no' },
            },
          },
        }
      end

      context 'at can_receive_mentor_training step' do
        let(:current_step) { :can_receive_mentor_training }

        it 'returns path from start to can_receive_mentor_training' do
          expect(wizard.path_traversal).to eq(%i[
                                                who_will_be_the_mentor
                                                can_receive_mentor_training
                                              ])
        end
      end

      context 'at which_lead_provider step' do
        let(:current_step) { :which_lead_provider }

        it 'returns path including which_lead_provider' do
          expect(wizard.path_traversal).to eq(%i[
                                                who_will_be_the_mentor
                                                can_receive_mentor_training
                                                which_lead_provider
                                              ])
        end
      end

      context 'at confirmation step' do
        let(:current_step) { :confirmation }

        it 'returns full path through which_lead_provider to confirmation' do
          expect(wizard.path_traversal).to eq(%i[
                                                who_will_be_the_mentor
                                                can_receive_mentor_training
                                                which_lead_provider
                                                confirmation
                                              ])
        end
      end
    end
  end

  describe '#next_step' do
    context 'from who_will_be_the_mentor' do
      let(:current_step) { :who_will_be_the_mentor }

      it 'advances to can_receive_mentor_training' do
        expect(wizard.next_step).to eq(:can_receive_mentor_training)
        expect(wizard.next_step_path).to eq('/assign-mentor/can-receive-mentor-training')
      end
    end

    context 'from can_receive_mentor_training' do
      context 'when the lead provider can provide training' do
        let(:current_step) { :can_receive_mentor_training }

        it 'moves directly to confirmation' do
          expect(wizard.next_step).to eq(:confirmation)
          expect(wizard.next_step_path).to eq('/assign-mentor/confirmation')
        end
      end

      context 'when the lead provider will not be providing training' do
        let(:current_step) { :can_receive_mentor_training }
        let(:step_params) do
          {
            'can_receive_mentor_training' => { 'lp_will_provide' => 'no' },
          }
        end

        it 'continues to which_lead_provider' do
          expect(wizard.next_step).to eq(:which_lead_provider)
          expect(wizard.next_step_path).to eq('/assign-mentor/which-lead-provider')
        end
      end
    end

    context 'from which_lead_provider' do
      let(:current_step) { :which_lead_provider }
      let(:session) do
        {
          'assign_mentor' => {
            'steps' => {
              'can_receive_mentor_training' => { 'lp_will_provide' => 'no' },
            },
          },
        }
      end

      it 'progresses to confirmation' do
        expect(wizard.next_step).to eq(:confirmation)
        expect(wizard.next_step_path).to eq('/assign-mentor/confirmation')
      end
    end
  end

  describe '#previous_step' do
    context 'when on can_receive_mentor_training step' do
      let(:current_step) { :can_receive_mentor_training }

      it 'returns to who_will_be_the_mentor' do
        expect(wizard.previous_step).to eq(:who_will_be_the_mentor)
        expect(wizard.previous_step_path).to eq('/assign-mentor/who-will-be-the-mentor')
      end
    end

    context 'when on which_lead_provider step' do
      let(:current_step) { :which_lead_provider }
      let(:session) do
        {
          'assign_mentor' => {
            'steps' => {
              'can_receive_mentor_training' => { 'lp_will_provide' => 'no' },
            },
          },
        }
      end

      it 'returns to can_receive_mentor_training' do
        expect(wizard.previous_step).to eq(:can_receive_mentor_training)
        expect(wizard.previous_step_path).to eq('/assign-mentor/can-receive-mentor-training')
      end
    end

    context 'when on confirmation step' do
      context 'and the lead provider can provide mentor training' do
        let(:current_step) { :confirmation }

        it 'goes back to can_receive_mentor_training' do
          expect(wizard.previous_step).to eq(:can_receive_mentor_training)
          expect(wizard.previous_step_path).to eq('/assign-mentor/can-receive-mentor-training')
        end
      end

      context 'and the lead provider cannot provide mentor training' do
        let(:current_step) { :confirmation }
        let(:session) do
          {
            'assign_mentor' => {
              'steps' => {
                'can_receive_mentor_training' => { 'lp_will_provide' => 'no' },
              },
            },
          }
        end

        it 'goes back to which_lead_provider' do
          expect(wizard.previous_step).to eq(:which_lead_provider)
          expect(wizard.previous_step_path).to eq('/assign-mentor/which-lead-provider')
        end
      end
    end

    context 'when on the first step' do
      let(:current_step) { :who_will_be_the_mentor }

      it 'has no previous step' do
        expect(wizard.previous_step).to be_nil
        expect(wizard.previous_step_path).to be_nil
      end
    end
  end

  describe 'full wizard flow - training path (yes branch)' do
    it 'flows: mentor -> training? (yes) -> confirmation' do
      # Step 1: Start
      step1 = described_class.new(
        current_step: :who_will_be_the_mentor,
        state_store: DfE::Wizard::StateStore::Session.new(session: {}, key: 'assign_mentor'),
        step_params: ActionController::Parameters.new({}),
      )
      expect(step1.path_traversal).to eq(%i[who_will_be_the_mentor])
      expect(step1.next_step).to eq(:can_receive_mentor_training)

      # Step 2: Training question (yes)
      session_2 = { 'assign_mentor' => { 'steps' => { 'who_will_be_the_mentor' => { 'type' => 'internal' } } } }
      step2 = described_class.new(
        current_step: :can_receive_mentor_training,
        state_store: DfE::Wizard::StateStore::Session.new(session: session_2, key: 'assign_mentor'),
        step_params: ActionController::Parameters.new({}),
      )
      expect(step2.path_traversal).to eq(%i[who_will_be_the_mentor can_receive_mentor_training])
      expect(step2.next_step).to eq(:confirmation)

      # Step 3: Confirmation
      session_3 = {
        'assign_mentor' => {
          'steps' => {
            'who_will_be_the_mentor' => { 'type' => 'internal' },
            'can_receive_mentor_training' => { 'lp_will_provide' => 'yes' },
          },
        },
      }
      step3 = described_class.new(
        current_step: :confirmation,
        state_store: DfE::Wizard::StateStore::Session.new(session: session_3, key: 'assign_mentor'),
        step_params: ActionController::Parameters.new({}),
      )
      expect(step3.path_traversal).to eq(%i[who_will_be_the_mentor can_receive_mentor_training confirmation])
      expect(step3.previous_step).to eq(:can_receive_mentor_training)
    end
  end

  describe 'full wizard flow - no training path (no branch)' do
    it 'flows: mentor -> training? (no) -> provider -> confirmation' do
      # Step 1: Start
      step1 = described_class.new(
        current_step: :who_will_be_the_mentor,
        state_store: DfE::Wizard::StateStore::Session.new(session: {}, key: 'assign_mentor'),
        step_params: ActionController::Parameters.new({}),
      )
      expect(step1.next_step).to eq(:can_receive_mentor_training)

      # Step 2: Training question (no)
      session_2 = { 'assign_mentor' => { 'steps' => { 'who_will_be_the_mentor' => { 'type' => 'internal' } } } }
      step2 = described_class.new(
        current_step: :can_receive_mentor_training,
        state_store: DfE::Wizard::StateStore::Session.new(session: session_2, key: 'assign_mentor'),
        step_params: ActionController::Parameters.new(can_receive_mentor_training: { lp_will_provide: 'no' }),
      )
      expect(step2.next_step).to eq(:which_lead_provider)

      # Step 3: Provider selection
      session_3 = {
        'assign_mentor' => {
          'steps' => {
            'who_will_be_the_mentor' => { 'type' => 'internal' },
            'can_receive_mentor_training' => { 'lp_will_provide' => 'no' },
          },
        },
      }
      step3 = described_class.new(
        current_step: :which_lead_provider,
        state_store: DfE::Wizard::StateStore::Session.new(session: session_3, key: 'assign_mentor'),
        step_params: ActionController::Parameters.new({}),
      )
      expect(step3.path_traversal).to eq(%i[who_will_be_the_mentor can_receive_mentor_training which_lead_provider])
      expect(step3.next_step).to eq(:confirmation)

      # Step 4: Confirmation
      session_4 = {
        'assign_mentor' => {
          'steps' => {
            'who_will_be_the_mentor' => { 'type' => 'internal' },
            'can_receive_mentor_training' => { 'lp_will_provide' => 'no' },
            'which_lead_provider' => { 'lead_provider_id' => '123' },
          },
        },
      }
      step4 = described_class.new(
        current_step: :confirmation,
        state_store: DfE::Wizard::StateStore::Session.new(session: session_4, key: 'assign_mentor'),
        step_params: ActionController::Parameters.new({}),
      )
      expect(step4.path_traversal).to eq(%i[who_will_be_the_mentor can_receive_mentor_training which_lead_provider
                                            confirmation])
      expect(step4.previous_step).to eq(:which_lead_provider)
    end
  end

  describe 'return to review scenario' do
    it 'user changes answer on confirmation page' do
      # User is on confirmation after yes branch
      session = {
        'assign_mentor' => {
          'steps' => {
            'who_will_be_the_mentor' => { 'type' => 'internal' },
            'can_receive_mentor_training' => { 'lp_will_provide' => 'yes' },
          },
        },
      }

      step_confirmation = described_class.new(
        current_step: :confirmation,
        state_store: DfE::Wizard::StateStore::Session.new(session: session, key: 'assign_mentor'),
        step_params: ActionController::Parameters.new({}),
      )
      expect(step_confirmation.path_traversal).to include(:confirmation)

      # User clicks "Change" on training question, goes back to edit
      step_edit_training = described_class.new(
        current_step: :can_receive_mentor_training,
        state_store: DfE::Wizard::StateStore::Session.new(session: session, key: 'assign_mentor'),
        step_params: ActionController::Parameters.new(can_receive_mentor_training: { lp_will_provide: 'no' }),
      )

      # After editing, should now go to provider instead of confirmation
      expect(step_edit_training.next_step).to eq(:which_lead_provider)

      # Path updates to include provider step
      expect(step_edit_training.path_traversal).to eq(%i[who_will_be_the_mentor can_receive_mentor_training
                                                         which_lead_provider])
    end

    it 'path changes when conditional branch changes' do
      # Initially: training? = yes -> confirmation
      session_initial = {
        'assign_mentor' => {
          'steps' => {
            'can_receive_mentor_training' => { 'lp_will_provide' => 'yes' },
          },
        },
      }

      # User returns and changes to no
      session_updated = {
        'assign_mentor' => {
          'steps' => {
            'can_receive_mentor_training' => { 'lp_will_provide' => 'no' },
          },
        },
      }

      step_initial = described_class.new(
        current_step: :confirmation,
        state_store: DfE::Wizard::StateStore::Session.new(session: session_initial, key: 'assign_mentor'),
        step_params: ActionController::Parameters.new({}),
      )

      step_updated = described_class.new(
        current_step: :confirmation,
        state_store: DfE::Wizard::StateStore::Session.new(session: session_updated, key: 'assign_mentor'),
        step_params: ActionController::Parameters.new({}),
      )

      expect(step_initial.path_traversal).to eq(%i[who_will_be_the_mentor can_receive_mentor_training confirmation])
      expect(step_updated.path_traversal).to eq(%i[who_will_be_the_mentor can_receive_mentor_training
                                                   which_lead_provider confirmation])
    end
  end

  describe 'validation and accessibility' do
    let(:current_step) { :who_will_be_the_mentor }

    it 'current step is accessible at root' do
      expect(wizard.current_step_accessible?).to be(true)
    end

    context 'when at non-root step without completing previous steps' do
      let(:current_step) { :confirmation }

      it 'is not accessible' do
        expect(wizard.current_step_accessible?).to be(false)
      end
    end

    context 'when at non-root step with valid previous steps (yes branch)' do
      let(:current_step) { :confirmation }
      let(:session) do
        {
          'assign_mentor' => {
            'steps' => {
              'who_will_be_the_mentor' => { 'mentor_id' => 'internal' },
              'can_receive_mentor_training' => { 'lp_will_provide' => 'yes' },
            },
          },
        }
      end

      it 'is accessible' do
        expect(wizard.current_step_accessible?).to be(true)
      end
    end

    context 'when at non-root step with valid previous steps (no branch)' do
      let(:current_step) { :confirmation }
      let(:session) do
        {
          'assign_mentor' => {
            'steps' => {
              'who_will_be_the_mentor' => { 'mentor_id' => 'internal' },
              'can_receive_mentor_training' => { 'lp_will_provide' => 'no' },
              'which_lead_provider' => { 'lead_provider_id' => '123' },
            },
          },
        }
      end

      it 'is accessible' do
        expect(wizard.current_step_accessible?).to be(true)
      end
    end

    context 'when at provider step without training decision' do
      let(:current_step) { :which_lead_provider }

      it 'is not accessible' do
        expect(wizard.current_step_accessible?).to be(false)
      end
    end

    context 'when at provider step with training decision' do
      let(:current_step) { :which_lead_provider }
      let(:session) do
        {
          'assign_mentor' => {
            'steps' => {
              'who_will_be_the_mentor' => { 'mentor_id' => 'internal' },
              'can_receive_mentor_training' => { 'lp_will_provide' => 'no' },
            },
          },
        }
      end

      it 'is accessible' do
        expect(wizard.current_step_accessible?).to be(true)
      end
    end
  end

  describe '#to_doc' do
    let(:current_step) { :who_will_be_the_mentor }

    it 'matches the documented graph' do
      expected = File.read('spec/fixtures/assign_mentor_wizard.dot')
      expect(wizard.to_doc.to_s).to eq(expected)
    end
  end
end
