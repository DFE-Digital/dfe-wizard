RSpec.describe 'flow_path from:' do
  subject(:wizard) { CourseChange::Wizard.new(state_store:) }

  let(:state_store) { CourseChange::StateStore.new }

  before { state_store.write(CourseChange::Wizard.complete_answers) }

  context 'with a graph' do
    it 'gives the path ahead of a step, the step included' do
      expect(wizard.flow_path(:check_answers, from: :funding_type)).to eq(
        %i[funding_type student_visa deadline_required deadline_at start_date check_answers],
      )
    end

    it 'follows the current answers' do
      state_store.write(funding_type: 'salary')

      expect(wizard.flow_path(:check_answers, from: :funding_type)).to eq(
        %i[funding_type skilled_worker_visa start_date check_answers],
      )
    end

    it 'gives only the step when it is the target' do
      expect(wizard.flow_path(:start_date, from: :start_date)).to eq(%i[start_date])
    end

    it 'is empty when the target is behind the step' do
      expect(wizard.flow_path(:subject, from: :funding_type)).to eq([])
    end

    it 'is empty when the target is on another branch' do
      expect(wizard.flow_path(:skilled_worker_visa, from: :funding_type)).to eq([])
    end

    it 'is empty when the step is not a node' do
      expect(wizard.flow_path(:check_answers, from: :unknown)).to eq([])
    end
  end

  context 'with a linear processor' do
    let(:linear) do
      DfE::Wizard::StepsProcessor::Linear.draw(wizard) do |l|
        l.add_step :level, CourseChange::Steps::Level
        l.add_step :subject, CourseChange::Steps::Subject
        l.add_step :start_date, CourseChange::Steps::StartDate
      end
    end

    it 'gives the steps from the step to the target' do
      expect(linear.path_traversal(:start_date, from: :subject)).to eq(%i[subject start_date])
    end

    it 'gives only the step when it is the target' do
      expect(linear.path_traversal(:subject, from: :subject)).to eq(%i[subject])
    end

    it 'is empty when the target is before the step' do
      expect(linear.path_traversal(:level, from: :subject)).to eq([])
    end

    it 'is empty when the step is not a step' do
      expect(linear.path_traversal(:start_date, from: :unknown)).to eq([])
    end
  end

  context 'with a processor that does not take from:' do
    let(:wizard_class) do
      processor_class = Class.new(DfE::Wizard::StepsProcessor::Base) do
        def initialize(wizard, context: nil)
          @wizard = wizard
          @context = context
        end

        def root_step = :level
        def step_definitions = { level: CourseChange::Steps::Level, subject: CourseChange::Steps::Subject }
        def path_traversal(target_step) = [:level, target_step]
      end

      Class.new do
        include DfE::Wizard

        define_method(:steps_processor) { processor_class.new(self) }
      end
    end

    it 'keeps flow_path working without from:' do
      expect(wizard_class.new(state_store:).flow_path(:subject)).to eq(%i[level subject])
    end
  end
end
