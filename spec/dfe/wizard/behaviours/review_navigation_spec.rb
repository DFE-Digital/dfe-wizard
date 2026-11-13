RSpec.describe 'review_navigation?' do
  let(:repository) { DfE::Wizard::Repository::InMemory.new }
  let(:state_store) { CourseChange::StateStore.new(repository:) }

  before { state_store.write(CourseChange::Wizard.complete_answers) }

  # A request to a step: on its own, or during a change from check answers
  def wizard_at(step, params = {}, origin: nil, wizard_class: CourseChange::ReviewWizard)
    current_step_params = { step => params }
    current_step_params[:return_to_review] = origin if origin

    wizard_class.new(state_store:, current_step: step, current_step_params:)
  end

  # Submits a step as the controller does, and returns the wizard
  def submit(step, params, **)
    wizard = wizard_at(step, params, **)
    raise "#{step} did not save: #{wizard.current_step.errors.full_messages}" unless wizard.save_current_step

    wizard
  end

  def review_shown
    wizard_at(:start_date).review_shown
  end

  it 'is off by default' do
    expect(wizard_at(:funding_type, wizard_class: CourseChange::Wizard).review_navigation?).to be(false)
  end

  describe 'the operations of a step' do
    it 'are Validate and Persist when it is off' do
      expect(wizard_at(:funding_type, wizard_class: CourseChange::Wizard).steps_operator.operations_for(:funding_type))
        .to eq([DfE::Wizard::Operations::Validate, DfE::Wizard::Operations::Persist])
    end

    it 'end with ReviewNavigation when it is on' do
      expect(wizard_at(:funding_type).steps_operator.operations_for(:funding_type)).to eq(
        [DfE::Wizard::Operations::Validate, DfE::Wizard::Operations::Persist, DfE::Wizard::Operations::ReviewNavigation],
      )
    end
  end

  describe 'saving a step during a change' do
    it 'records the steps shown, starting afresh on the step whose Change link was followed' do
      submit(:funding_type, { funding_type: 'salary' }, origin: :funding_type)
      submit(:skilled_worker_visa, { can_sponsor_skilled_worker_visa: 'false' }, origin: :funding_type)
      expect(review_shown).to eq(%i[funding_type skilled_worker_visa])

      submit(:funding_type, { funding_type: 'salary' }, origin: :funding_type)
      expect(review_shown).to eq(%i[funding_type])
    end

    it 'clears the answers the change took off the path' do
      submit(:funding_type, { funding_type: 'salary' }, origin: :funding_type)

      expect(repository.read).to include(funding_type: 'salary', can_sponsor_student_visa: nil,
                                         visa_deadline_required: nil, visa_deadline_at: nil)
    end

    it 'clears off-path answers outside a change too, without recording the step' do
      submit(:funding_type, { funding_type: 'salary' })

      expect(repository.read).to include(can_sponsor_student_visa: nil)
      expect(review_shown).to eq([])
    end

    it 'does nothing when the step does not save' do
      wizard = wizard_at(:funding_type, { funding_type: 'part_time' }, origin: :funding_type)

      expect(wizard.save_current_step).to be(false)
      expect(review_shown).to eq([])
    end

    it 'does nothing when the wizard is off' do
      submit(:funding_type, { funding_type: 'salary' }, origin: :funding_type, wizard_class: CourseChange::Wizard)

      expect(review_shown).to eq([])
      expect(repository.read).to include(can_sponsor_student_visa: true)
    end

    it 'records nothing when check answers itself is saved' do
      submit(:check_answers, {}, origin: :funding_type)

      expect(review_shown).to eq([])
    end

    it 'keeps the answer of a step saved from off the path' do
      submit(:skilled_worker_visa, { can_sponsor_skilled_worker_visa: 'true' })

      expect(repository.read).to include(can_sponsor_skilled_worker_visa: true)
    end
  end

  describe 'steps with operations of their own' do
    # Records which review steps were already shown when it ran
    let(:spy_operation) do
      Class.new do
        def initialize(repository:, step:)
          @repository = repository
          @step = step
        end

        def execute
          @repository.write(shown_before_own_operation: @step.wizard.review_shown.map(&:to_s))
          { success: true }
        end
      end
    end

    def wizard_class(**on_step)
      Class.new(CourseChange::ReviewWizard) do
        define_method(:steps_operator) do
          DfE::Wizard::StepsOperator::Builder.draw(wizard: self, callable: state_store) do |builder|
            builder.on_step(:funding_type, **on_step)
          end
        end
      end
    end

    it 'keep the review navigation with add:, which runs after their operations' do
      wizard = submit(:funding_type, { funding_type: 'salary' }, origin: :funding_type,
                                                                 wizard_class: wizard_class(add: [spy_operation]))

      expect(wizard.steps_operator.operations_for(:funding_type).last).to eq(DfE::Wizard::Operations::ReviewNavigation)
      expect(repository.read[:shown_before_own_operation]).to eq([])
      expect(review_shown).to eq(%i[funding_type])
    end

    it 'lose it with use:' do
      own_class = wizard_class(use: [DfE::Wizard::Operations::Validate, DfE::Wizard::Operations::Persist])
      submit(:funding_type, { funding_type: 'salary' }, origin: :funding_type, wizard_class: own_class)

      expect(review_shown).to eq([])
    end

    it 'keep it with use: when they list it' do
      own_class = wizard_class(use: [DfE::Wizard::Operations::Validate, DfE::Wizard::Operations::Persist,
                                     DfE::Wizard::Operations::ReviewNavigation])
      submit(:funding_type, { funding_type: 'salary' }, origin: :funding_type, wizard_class: own_class)

      expect(review_shown).to eq(%i[funding_type])
    end
  end

  describe 'navigation during a change' do
    it 'goes to the next step that needs an answer, then back to check answers' do
      expect(submit(:funding_type, { funding_type: 'salary' }, origin: :funding_type).next_step)
        .to eq(:skilled_worker_visa)
      visa = submit(:skilled_worker_visa, { can_sponsor_skilled_worker_visa: 'false' }, origin: :funding_type)

      expect(visa.next_step).to eq(:check_answers)
    end

    it 'goes back through the steps shown' do
      submit(:funding_type, { funding_type: 'salary' }, origin: :funding_type)

      expect(wizard_at(:skilled_worker_visa, origin: :funding_type).previous_step).to eq(:funding_type)
      expect(wizard_at(:funding_type, origin: :funding_type).previous_step).to eq(:check_answers)
    end

    it 'follows the graph outside a change' do
      expect(submit(:level, { level: 'secondary' }).next_step).to eq(:subject)
    end

    it 'lets the callbacks of the wizard win' do
      wizard_class = Class.new(CourseChange::ReviewWizard) do
        def steps_processor
          DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
            graph.flow :course_flow
            graph.before_next_step { :declaration if return_to_review? }
            graph.before_previous_step { :level if return_to_review? }
          end
        end
      end
      wizard = submit(:funding_type, { funding_type: 'salary' }, origin: :funding_type, wizard_class:)

      expect(wizard.next_step).to eq(:declaration)
      expect(wizard.previous_step).to eq(:level)
    end

    it 'raises when the graph declares no check answers step' do
      wizard_class = Class.new(CourseChange::ReviewWizard) do
        def steps_processor
          DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
            graph.add_node :start_date, CourseChange::Steps::StartDate
            graph.root :start_date
          end
        end
      end

      expect { wizard_at(:start_date, wizard_class:) }
        .to raise_error(ArgumentError, 'review_navigation? needs graph.check_answers')
    end
  end

  describe 'step paths during a change' do
    it 'carry the step whose Change link was followed' do
      wizard = submit(:funding_type, { funding_type: 'salary' }, origin: :funding_type)

      expect(wizard.next_step_path).to eq('/course/skilled_worker_visa?return_to_review=funding_type')
      expect(wizard.current_step_path).to eq('/course/funding_type?return_to_review=funding_type')
    end

    it 'carry it to a step off the path' do
      expect(wizard_at(:funding_type, origin: :funding_type).resolve_step_path(:skilled_worker_visa))
        .to eq('/course/skilled_worker_visa?return_to_review=funding_type')
    end

    it 'do not carry it to check answers, or past it' do
      wizard = submit(:start_date, { start_date: '2027-01' }, origin: :start_date)

      expect(wizard.next_step_path).to eq('/course/check_answers')
      expect(wizard.resolve_step_path(:declaration)).to eq('/course/declaration')
      expect(wizard.resolve_step_path(:courses)).to eq('/course/courses')
      expect(wizard.resolve_step_path('check_answers')).to eq('/course/check_answers')
    end

    it 'do not carry it outside a change, or when the wizard is off' do
      expect(wizard_at(:funding_type).resolve_step_path(:start_date)).to eq('/course/start_date')
      expect(wizard_at(:funding_type, origin: :funding_type, wizard_class: CourseChange::Wizard)
        .resolve_step_path(:start_date)).to eq('/course/start_date')
    end
  end

  describe 'a review tracked by hand' do
    it 'keeps every step recorded with track_review_step' do
      wizard_at(:funding_type, origin: :funding_type, wizard_class: CourseChange::Wizard).track_review_step
      wizard_at(:skilled_worker_visa, origin: :funding_type, wizard_class: CourseChange::Wizard).track_review_step
      wizard_at(:funding_type, origin: :funding_type, wizard_class: CourseChange::Wizard).track_review_step

      expect(review_shown).to eq(%i[funding_type skilled_worker_visa])
    end
  end
end
