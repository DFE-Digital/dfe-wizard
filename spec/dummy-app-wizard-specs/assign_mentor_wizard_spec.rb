RSpec.describe AssignMentorWizard do
  let(:session) { {} }
  let(:repository) { DfE::Wizard::Repository::Session.new(session:, key: 'assign_mentor') }
  let(:state_store) { StateStores::AssignMentor.new(repository: repository) }
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
    context 'when lead provider will provide training (yes branch)' do
      before do
        state_store.write({
                            mentor_id: 1,
                            lp_will_provide: 'yes',
                          })
      end

      context 'at who_will_be_the_mentor step' do
        let(:current_step) { :who_will_be_the_mentor }

        it { is_expected.to be_at_step(:who_will_be_the_mentor) }
        it { is_expected.to have_saved_path([:who_will_be_the_mentor]) }
        it { is_expected.to have_flow_path([:who_will_be_the_mentor]) }
        it { expect(wizard).to branch_from(:who_will_be_the_mentor).to(:can_receive_mentor_training) }
      end

      context 'at can_receive_mentor_training step' do
        let(:current_step) { :can_receive_mentor_training }

        it { is_expected.to be_at_step(:can_receive_mentor_training) }
        it { is_expected.to have_saved_path(%i[who_will_be_the_mentor can_receive_mentor_training]) }
        it { is_expected.to have_flow_path(%i[who_will_be_the_mentor can_receive_mentor_training]) }
        it { expect(wizard).to branch_from(:can_receive_mentor_training).to(:confirmation) }
      end

      context 'at confirmation step' do
        let(:current_step) { :confirmation }

        it { is_expected.to be_at_step(:confirmation) }
        it { is_expected.to have_saved_path(%i[who_will_be_the_mentor can_receive_mentor_training]) }
        it { is_expected.to have_flow_path(%i[who_will_be_the_mentor can_receive_mentor_training confirmation]) }
      end
    end

    context 'when lead provider will not provide training (no branch)' do
      before do
        state_store.write({
                            mentor_id: 1,
                            lp_will_provide: 'no',
                            lead_provider_id: 1,
                          })
      end

      context 'at can_receive_mentor_training step' do
        let(:current_step) { :can_receive_mentor_training }

        it { is_expected.to be_at_step(:can_receive_mentor_training) }
        it { is_expected.to have_saved_path(%i[who_will_be_the_mentor can_receive_mentor_training]) }
        it { expect(wizard).to branch_from(:can_receive_mentor_training).to(:which_lead_provider) }
      end

      context 'at which_lead_provider step' do
        let(:current_step) { :which_lead_provider }

        it { is_expected.to be_at_step(:which_lead_provider) }
        it {
          is_expected.to have_saved_path(
            %i[who_will_be_the_mentor can_receive_mentor_training which_lead_provider],
          )
        }
        it {
          is_expected.to have_flow_path(
            %i[who_will_be_the_mentor can_receive_mentor_training which_lead_provider],
          )
        }
        it { expect(wizard).to branch_from(:which_lead_provider).to(:confirmation) }
      end

      context 'at confirmation step' do
        let(:current_step) { :confirmation }

        it { is_expected.to be_at_step(:confirmation) }
        it {
          is_expected.to have_saved_path(
            %i[who_will_be_the_mentor can_receive_mentor_training which_lead_provider],
          )
        }
        it {
          is_expected.to have_flow_path(
            %i[who_will_be_the_mentor can_receive_mentor_training which_lead_provider confirmation],
          )
        }
      end
    end
  end

  describe 'navigation' do
    context 'from who_will_be_the_mentor' do
      let(:current_step) { :who_will_be_the_mentor }

      before do
        state_store.write({
                            mentor_id: 1,
                          })
      end

      it { is_expected.to be_at_step(:who_will_be_the_mentor) }
      it { expect(wizard).to have_next_step(:can_receive_mentor_training) }
      it { is_expected.to have_next_step_path(url_helpers.assign_mentor_can_receive_mentor_training_path) }
    end

    context 'from can_receive_mentor_training' do
      let(:current_step) { :can_receive_mentor_training }

      before do
        state_store.write({
                            mentor_id: 1,
                            lp_will_provide: lp_answer,
                          })
      end

      context 'when lead provider will provide training' do
        let(:lp_answer) { 'yes' }

        it { is_expected.to be_at_step(:can_receive_mentor_training) }
        it { expect(wizard).to have_next_step(:confirmation) }
        it { is_expected.to have_next_step_path(url_helpers.assign_mentor_confirmation_path) }
        it { expect(wizard).to branch_from(:can_receive_mentor_training).to(:confirmation) }
      end

      context 'when lead provider will not provide training' do
        let(:lp_answer) { 'no' }

        it { expect(wizard).to have_next_step(:which_lead_provider) }
        it { is_expected.to have_next_step_path(url_helpers.assign_mentor_which_lead_provider_path) }
        it { expect(wizard).to branch_from(:can_receive_mentor_training).to(:which_lead_provider) }
      end
    end

    context 'from which_lead_provider' do
      let(:current_step) { :which_lead_provider }

      before do
        state_store.write({
                            mentor_id: 1,
                            lp_will_provide: 'no',
                            lead_provider_id: 1,
                          })
      end

      it { is_expected.to be_at_step(:which_lead_provider) }
      it { expect(wizard).to have_next_step(:confirmation) }
      it { is_expected.to have_next_step_path(url_helpers.assign_mentor_confirmation_path) }
    end

    context 'backwards navigation' do
      context 'from can_receive_mentor_training' do
        let(:current_step) { :can_receive_mentor_training }

        before do
          state_store.write({
                              mentor_id: 1,
                            })
        end

        it { is_expected.to be_at_step(:can_receive_mentor_training) }
        it { expect(wizard).to have_previous_step(:who_will_be_the_mentor) }
        it { is_expected.to have_previous_step_path(url_helpers.assign_mentor_who_will_be_the_mentor_path) }
      end

      context 'from which_lead_provider' do
        let(:current_step) { :which_lead_provider }

        before do
          state_store.write({
                              mentor_id: 1,
                              lp_will_provide: 'no',
                            })
        end

        it { is_expected.to be_at_step(:which_lead_provider) }
        it { expect(wizard).to have_previous_step(:can_receive_mentor_training) }
        it { is_expected.to have_previous_step_path(url_helpers.assign_mentor_can_receive_mentor_training_path) }
      end

      context 'from confirmation with yes branch' do
        let(:current_step) { :confirmation }

        before do
          state_store.write({
                              mentor_id: 1,
                              lp_will_provide: 'yes',
                            })
        end

        it { is_expected.to be_at_step(:confirmation) }
        it { expect(wizard).to have_previous_step(:can_receive_mentor_training) }
        it { is_expected.to have_previous_step_path(url_helpers.assign_mentor_can_receive_mentor_training_path) }
      end

      context 'from confirmation with no branch' do
        let(:current_step) { :confirmation }

        before do
          state_store.write({
                              mentor_id: 1,
                              lp_will_provide: 'no',
                              lead_provider_id: 1,
                            })
        end

        it { is_expected.to be_at_step(:confirmation) }
        it { expect(wizard).to have_previous_step(:which_lead_provider) }
        it { is_expected.to have_previous_step_path(url_helpers.assign_mentor_which_lead_provider_path) }
      end
    end
  end

  describe 'validation' do
    context 'when all steps are valid (yes branch)' do
      let(:current_step) { :confirmation }

      before do
        state_store.write({
                            mentor_id: 1,
                            lp_will_provide: 'yes',
                          })
      end

      it { is_expected.to be_at_step(:confirmation) }
      it { is_expected.to be_valid_to(:confirmation) }
      it { expect(:who_will_be_the_mentor).to be_valid_step.in(wizard) }
    end

    context 'when all steps are valid (no branch)' do
      let(:current_step) { :confirmation }

      before do
        state_store.write({
                            mentor_id: 1,
                            lp_will_provide: 'no',
                            lead_provider_id: 1,
                          })
      end

      it { is_expected.to be_valid_to(:confirmation) }
      it { expect(:who_will_be_the_mentor).to be_valid_step.in(wizard) }
      it { expect(:which_lead_provider).to be_valid_step.in(wizard) }
    end

    context 'when path is incomplete' do
      let(:current_step) { :confirmation }

      it { expect(wizard).not_to be_valid_to(:confirmation) }
    end

    context 'when step has invalid data' do
      let(:current_step) { :which_lead_provider }

      before do
        state_store.write({
                            mentor_id: nil,
                            lp_will_provide: 'no',
                          })
      end

      it { expect(:who_will_be_the_mentor).not_to be_valid_step.in(wizard) }
      it { expect(wizard).not_to be_valid_to(:confirmation) }
    end
  end

  describe 'branch change scenarios' do
    context 'when changing from yes to no branch' do
      before do
        state_store.write({
                            mentor_id: 1,
                            lp_will_provide: 'no',
                          })
      end

      let(:current_step) { :can_receive_mentor_training }

      it { expect(wizard).to branch_from(:can_receive_mentor_training).to(:which_lead_provider) }
      it { expect(wizard).to have_flow_path(%i[who_will_be_the_mentor can_receive_mentor_training]) }
    end

    context 'when user changes answer at confirmation' do
      before do
        state_store.write({
                            mentor_id: 1,
                            lp_will_provide: 'yes',
                          })
      end

      let(:current_step) { :can_receive_mentor_training }
      let(:current_step_params) { { can_receive_mentor_training: { lp_will_provide: 'no' } } }

      it 'changes branch to include which_lead_provider' do
        wizard.save_current_step
        expect(wizard.flow_path(:confirmation)).to eq(%i[
                                                        who_will_be_the_mentor
                                                        can_receive_mentor_training
                                                        which_lead_provider
                                                        confirmation
                                                      ])
      end
    end
  end

  describe 'step hydration' do
    let(:current_step) { :who_will_be_the_mentor }

    before do
      state_store.write({
                          mentor_id: 1,
                        })
    end

    it 'has saved the who_will_be_the_mentor step' do
      expect(wizard).to have_saved_path([:who_will_be_the_mentor])
    end

    it 'returns hydrated step object with correct data' do
      step = wizard.step(:who_will_be_the_mentor)
      expect(step).to be_instance_of(Steps::WhoWillBeTheMentor)
      expect(step.mentor_id).to eq(1)
    end

    it 'caches step objects' do
      step1 = wizard.step(:who_will_be_the_mentor)
      step2 = wizard.step(:who_will_be_the_mentor)
      expect(step1).to equal(step2)
    end
  end

  describe 'flow path calculation' do
    before do
      state_store.write({
                          mentor_id: 1,
                          lp_will_provide: 'yes',
                        })
    end

    let(:current_step) { :confirmation }

    it { is_expected.to be_at_step(:confirmation) }
    it { is_expected.to have_flow_path(%i[who_will_be_the_mentor can_receive_mentor_training confirmation]) }

    it 'returns correct ordered flow path' do
      expect(wizard.flow_path).to eq(%i[who_will_be_the_mentor can_receive_mentor_training confirmation])
    end

    context 'with explicit target' do
      let(:current_step) { :who_will_be_the_mentor }

      it 'returns path to specific target step' do
        expect(wizard.flow_path(:confirmation)).to eq(%i[
                                                        who_will_be_the_mentor
                                                        can_receive_mentor_training
                                                        confirmation
                                                      ])
      end
    end
  end

  describe 'documentation generation' do
    let(:current_step) { :who_will_be_the_mentor }

    it 'generates valid GraphViz documentation' do
      expected = File.read('spec/fixtures/assign_mentor_wizard.dot')
      expect(wizard.to_doc.to_s).to eq(expected)
    end
  end

  describe 'complex branching scenarios' do
    context 'complete no training path' do
      before do
        state_store.write({
                            mentor_id: 1,
                            lp_will_provide: 'no',
                            lead_provider_id: 1,
                          })
      end

      let(:current_step) { :confirmation }

      it { is_expected.to be_at_step(:confirmation) }
      it {
        is_expected.to have_saved_path(
          %i[who_will_be_the_mentor can_receive_mentor_training which_lead_provider],
        )
      }
      it {
        is_expected.to have_flow_path(
          %i[who_will_be_the_mentor can_receive_mentor_training which_lead_provider confirmation],
        )
      }
      it { is_expected.to be_valid_to(:confirmation) }

      it 'includes full no-training path in correct order' do
        expect(wizard.flow_path).to eq(
          %i[
            who_will_be_the_mentor
            can_receive_mentor_training
            which_lead_provider
            confirmation
          ],
        )
      end
    end
  end
end
