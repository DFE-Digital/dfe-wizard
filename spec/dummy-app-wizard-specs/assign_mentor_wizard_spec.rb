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
          assign_mentor: {
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

    context 'with explicit branching data supplied directly' do
      let(:current_step) { :who_will_be_the_mentor }

      let(:branching_data) do
        {
          steps: {
            can_receive_mentor_training: { lp_will_provide: 'no' },
          },
        }
      end

      it 'uses the provided data to determine the path' do
        expected_path = %i[
          who_will_be_the_mentor
          can_receive_mentor_training
          which_lead_provider
          confirmation
        ]
        expect(wizard.steps_processor.path_traversal(:confirmation, branching_data)).to eq(expected_path)
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
        let(:session) do
          {
            assign_mentor: {
              'steps' => {
                'can_receive_mentor_training' => { 'lp_will_provide' => 'no' },
              },
            },
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
          assign_mentor: {
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
            assign_mentor: {
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

  describe '#to_doc' do
    let(:current_step) { :who_will_be_the_mentor }

    it 'matches the documented graph' do
      expected = File.read('spec/fixtures/assign_mentor_wizard.dot')
      expect(wizard.to_doc.to_s).to eq(expected)
    end
  end
end
