RSpec.describe DfE::Wizard::Behaviours::CheckYourAnswers do
  let(:repository) { DfE::Wizard::Repository::InMemory.new }
  let(:state_store) { CourseChange::StateStore.new(repository:) }
  let(:answers) { CourseChange::Wizard.complete_answers }

  before { state_store.write(answers) }

  # A request to a step: on its own, or during a change from check answers
  def wizard_at(step, params = {}, origin: nil)
    current_step_params = { step => params }
    current_step_params[:return_to_review] = origin if origin

    CourseChange::Wizard.new(state_store:, current_step: step, current_step_params:)
  end

  # Submits a step during a change, as the controller does, and returns where it goes next
  def submit_change(step, params, origin: step)
    wizard = wizard_at(step, params, origin:)
    raise "#{step} did not save: #{wizard.current_step.errors.full_messages}" unless wizard.save_current_step

    wizard.track_review_step
    wizard.next_step
  end

  describe '#next_step_in_review' do
    it 'goes straight back to check answers when nothing ahead needs an answer' do
      expect(submit_change(:start_date, { start_date: '2027-01' })).to eq(:check_answers)
    end

    it 'skips valid steps and goes to a step that is new on the path' do
      expect(submit_change(:funding_type, { funding_type: 'salary' })).to eq(:skilled_worker_visa)
    end

    it 'goes on through each step that needs an answer, then back to check answers' do
      answers.merge!(subject: 'history', funding_type: nil)
      state_store.write(answers)

      expect(submit_change(:subject, { subject: 'physics' })).to eq(:physics_specialism)
      expect(submit_change(:physics_specialism, { physics_specialism: 'engineers' }, origin: :subject))
        .to eq(:funding_type)
      expect(submit_change(:funding_type, { funding_type: 'fee' }, origin: :subject)).to eq(:check_answers)
    end

    it 'shows a step ahead whose answer is no longer valid' do
      state_store.write(start_date: '2030-01')

      expect(submit_change(:funding_type, { funding_type: 'fee' })).to eq(:start_date)
    end

    it 'goes back to check answers when a change takes steps off the path' do
      expect(submit_change(:qualification, { qualification: 'tda' })).to eq(:check_answers)
    end

    it 'never shows a step after check answers' do
      expect(wizard_at(:declaration).valid?(:declaration)).to be(false)
      expect(submit_change(:start_date, { start_date: '2026-09' })).to eq(:check_answers)
    end

    it 'finishes on the given step' do
      wizard = wizard_at(:start_date, { start_date: '2027-01' }, origin: :start_date)
      wizard.save_current_step

      expect(wizard.next_step_in_review(finish: :courses)).to eq(:courses)
    end

    it 'shows only the given steps' do
      wizard = wizard_at(:funding_type, { funding_type: 'salary' }, origin: :funding_type)
      wizard.save_current_step

      expect(wizard.next_step_in_review(only: %i[funding_type start_date])).to eq(:check_answers)
      expect(wizard.next_step_in_review(only: %w[skilled_worker_visa])).to eq(:skilled_worker_visa)
    end

    it 'does not change the wizard state' do
      state_store.write(funding_type: 'salary')

      expect { wizard_at(:funding_type, origin: :funding_type).next_step }.not_to(change { repository.read })
    end

    it 'leaves navigation unchanged outside a change' do
      wizard = wizard_at(:level, { level: 'secondary' })
      wizard.save_current_step

      expect(wizard.next_step).to eq(:subject)
    end

    it 'raises when the graph declares no check answers step' do
      wizard_class = Class.new do
        include DfE::Wizard

        def steps_processor
          DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
            graph.add_node :start_date, CourseChange::Steps::StartDate
            graph.root :start_date
          end
        end
      end

      expect { wizard_class.new(state_store:, current_step: :start_date).next_step_in_review }
        .to raise_error(ArgumentError, 'Declare the check answers step with graph.check_answers')
    end
  end

  describe '#previous_step_in_review' do
    it 'goes back to check answers from the step whose Change link was followed' do
      expect(wizard_at(:funding_type, origin: :funding_type).previous_step).to eq(:check_answers)
    end

    it 'retraces the steps shown in the change, skipping the others' do
      answers.merge!(subject: 'history', funding_type: nil)
      state_store.write(answers)
      submit_change(:subject, { subject: 'physics' })
      submit_change(:physics_specialism, { physics_specialism: 'engineers' }, origin: :subject)

      expect(wizard_at(:funding_type, origin: :subject).previous_step).to eq(:physics_specialism)
      expect(wizard_at(:physics_specialism, origin: :subject).previous_step).to eq(:subject)
    end

    it 'goes back to the origin step even when it was not recorded' do
      state_store.write(funding_type: 'salary')

      expect(wizard_at(:skilled_worker_visa, origin: :funding_type).previous_step).to eq(:funding_type)
    end

    it 'goes back to check answers when the step is not on the path from the origin' do
      expect(wizard_at(:skilled_worker_visa, origin: :funding_type).previous_step).to eq(:check_answers)
    end

    it 'falls through to the graph outside a change' do
      expect(wizard_at(:funding_type).previous_step).to eq(:qualification)
    end

    it 'falls through to the graph when the origin param is not a step id' do
      expect(wizard_at(:funding_type, origin: ['funding_type']).previous_step).to eq(:qualification)
    end
  end

  describe 'the shown steps' do
    let(:session) { {} }
    let(:repository) { DfE::Wizard::Repository::Session.new(session:, key: :course) }

    it 'are kept in the wizard state across requests' do
      wizard_at(:funding_type).track_review_step
      wizard_at(:skilled_worker_visa).track_review_step

      expect(wizard_at(:start_date).review_shown).to eq(%i[funding_type skilled_worker_visa])
    end

    it 'are forgotten by clear_review' do
      wizard_at(:funding_type).track_review_step
      wizard_at(:check_answers).clear_review

      expect(wizard_at(:funding_type).review_shown).to eq([])
    end
  end

  describe '#handle_return_to_check_your_answers' do
    it 'defaults to the check answers step' do
      expect(wizard_at(:start_date).handle_return_to_check_your_answers).to eq(:check_answers)
    end
  end
end
