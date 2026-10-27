RSpec.describe 'clear_off_path_answers' do
  let(:repository) { DfE::Wizard::Repository::InMemory.new }
  let(:state_store) { CourseChange::StateStore.new(repository:) }

  before { state_store.write(CourseChange::Wizard.complete_answers.merge(declared: true)) }

  def wizard_at(step, params = {}, origin: nil)
    current_step_params = { step => params }
    current_step_params[:return_to_review] = origin if origin

    CourseChange::Wizard.new(state_store:, current_step: step, current_step_params:)
  end

  def answer(step, params, origin: step)
    wizard = wizard_at(step, params, origin:)
    raise "#{step} did not save" unless wizard.save_current_step

    wizard
  end

  it 'clears the answers of steps a change took off the path, and keeps the others' do
    cleared = answer(:funding_type, { funding_type: 'salary' }).clear_off_path_answers

    expect(cleared).to eq(%i[student_visa deadline_required deadline_at])
    expect(repository.read).to include(
      funding_type: 'salary',
      can_sponsor_student_visa: nil,
      visa_deadline_required: nil,
      visa_deadline_at: nil,
      qualification: 'qts',
      start_date: '2026-09',
    )
  end

  it 'asks a question again when a change brings it back' do
    answer(:qualification, { qualification: 'tda' }).clear_off_path_answers

    expect(answer(:qualification, { qualification: 'qts' }).next_step).to eq(:funding_type)
  end

  it 'keeps the answers of steps after check answers' do
    answer(:funding_type, { funding_type: 'salary' }).clear_off_path_answers

    expect(repository.read).to include(declared: true)
  end

  it 'keeps the answers of steps ahead of the current step' do
    expect(wizard_at(:level).clear_off_path_answers).to eq([])
    expect(repository.read).to include(CourseChange::Wizard.complete_answers)
  end

  it 'clears a no answer like any other' do
    state_store.write(can_sponsor_student_visa: false)

    expect(answer(:funding_type, { funding_type: 'salary' }).clear_off_path_answers).to include(:student_visa)
    expect(repository.read[:can_sponsor_student_visa]).to be_nil
  end

  it 'does not clear again what is already clear' do
    wizard = answer(:funding_type, { funding_type: 'salary' })
    wizard.clear_off_path_answers

    expect(wizard.clear_off_path_answers).to eq([])
  end

  context 'with a repository that reads keys back as strings' do
    let(:repository) { DfE::Wizard::Repository::Session.new(session: {}, key: :course) }

    it 'clears the same answers' do
      cleared = answer(:funding_type, { funding_type: 'salary' }).clear_off_path_answers

      expect(cleared).to eq(%i[student_visa deadline_required deadline_at])
      expect(repository.read.symbolize_keys).to include(can_sponsor_student_visa: nil, funding_type: 'salary')
    end
  end

  it 'clears nothing when the path does not reach check answers' do
    wizard = CourseChange::DeadEndWizard.new(state_store:, current_step: :level)

    expect(wizard.clear_off_path_answers).to eq([])
    expect(repository.read).to include(subject: 'history')
  end

  context 'with a step skipped by skip_when' do
    let(:wizard_class) do
      Class.new do
        include DfE::Wizard

        def steps_processor
          DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
            graph.add_node :level, CourseChange::Steps::Level
            graph.add_node :subject, CourseChange::Steps::Subject, skip_when: -> { true }
            graph.check_answers :check_answers, CourseChange::Steps::CheckAnswers
            graph.root :level
            graph.add_edge from: :level, to: :subject
            graph.add_edge from: :subject, to: :check_answers
          end
        end
      end
    end

    it 'keeps the answer the app filled in for it' do
      expect(wizard_class.new(state_store:).clear_off_path_answers).to eq([])
      expect(repository.read).to include(subject: 'history')
    end
  end

  context 'with an attribute shared by a step on the path and one off it' do
    let(:wizard_class) do
      Class.new do
        include DfE::Wizard

        def steps_processor
          DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
            graph.add_node :funding_type, CourseChange::Steps::FundingType
            graph.add_node :fee_start_date, CourseChange::Steps::StartDate
            graph.add_node :salary_start_date, CourseChange::Steps::StartDate
            graph.check_answers :check_answers, CourseChange::Steps::CheckAnswers
            graph.root :funding_type
            graph.add_conditional_edge from: :funding_type, when: :salary?, then: :salary_start_date,
                                       else: :fee_start_date
            graph.add_edge from: :fee_start_date, to: :check_answers
            graph.add_edge from: :salary_start_date, to: :check_answers
          end
        end
      end
    end

    it 'keeps the answer the step on the path owns' do
      state_store.write(funding_type: 'salary')

      expect(wizard_class.new(state_store:).clear_off_path_answers).to eq([])
      expect(repository.read).to include(start_date: '2026-09')
    end
  end

  it 'raises when the graph declares no check answers step' do
    wizard_class = Class.new do
      include DfE::Wizard

      def steps_processor
        DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
          graph.add_node :level, CourseChange::Steps::Level
          graph.root :level
        end
      end
    end

    expect { wizard_class.new(state_store:).clear_off_path_answers }
      .to raise_error(ArgumentError, 'Declare the check answers step with graph.check_answers')
  end
end
