RSpec.describe DfE::Wizard::StepsProcessor::Linear do
  class HmrcSelfAssessmentWizard
    attr_accessor :current_step_name

    def initialize
      @current_step_name = :personal_details
    end
  end

  class DfeTeacherRegistrationWizard
    attr_accessor :current_step_name

    def initialize
      @current_step_name = :teacher_details
    end
  end

  # rubocop:disable Lint/EmptyClass
  class PersonalDetailsStep; end
  class UtrCheckStep; end
  class TradingDetailsStep; end
  class BankDetailsStep; end
  class ConfirmationStep; end

  class TeacherDetailsStep; end
  class QualificationsStep; end
  class TrainingRouteStep; end
  class AvailabilityStep; end
  class ReviewStep; end
  # rubocop:enable Lint/EmptyClass

  describe '#initialize' do
    it 'initializes with wizard and optional context' do
      wizard = HmrcSelfAssessmentWizard.new
      processor = DfE::Wizard::StepsProcessor::Linear.new(wizard)

      expect(processor.wizard).to eq(wizard)
      expect(processor.context).to be_nil
    end

    it 'initializes with context' do
      wizard = HmrcSelfAssessmentWizard.new
      context = { user: 'alice' }
      processor = DfE::Wizard::StepsProcessor::Linear.new(wizard, context:)

      expect(processor.context).to eq(context)
    end
  end

  describe '#root_step' do
    context 'with steps added' do
      it 'returns the first step added by default' do
        wizard = HmrcSelfAssessmentWizard.new
        processor = DfE::Wizard::StepsProcessor::Linear.draw(wizard) do |l|
          l.add_step :personal_details, PersonalDetailsStep
          l.add_step :utr_check, UtrCheckStep
          l.add_step :confirmation, ConfirmationStep
        end

        expect(processor.root_step).to eq(:personal_details)
      end

      it 'allows overriding root step via DSL' do
        wizard = HmrcSelfAssessmentWizard.new
        processor = DfE::Wizard::StepsProcessor::Linear.draw(wizard) do |l|
          l.add_step :personal_details, PersonalDetailsStep
          l.add_step :utr_check, UtrCheckStep
          l.add_step :confirmation, ConfirmationStep
          l.root :utr_check # Override to start from step 2
        end

        expect(processor.root_step).to eq(:utr_check)
      end

      it 'returns same root on multiple calls (fixed, not dynamic)' do
        wizard = HmrcSelfAssessmentWizard.new
        processor = DfE::Wizard::StepsProcessor::Linear.draw(wizard) do |l|
          l.add_step :step1, PersonalDetailsStep
          l.add_step :step2, UtrCheckStep
        end

        expect(processor.root_step).to eq(processor.root_step)
      end
    end

    context 'without steps' do
      it 'raises ArgumentError' do
        wizard = HmrcSelfAssessmentWizard.new
        processor = DfE::Wizard::StepsProcessor::Linear.new(wizard)

        expect { processor.root_step }.to raise_error(ArgumentError, /No steps defined/)
      end
    end
  end

  describe '#next_step' do
    let(:wizard) { HmrcSelfAssessmentWizard.new }
    let(:processor) do
      DfE::Wizard::StepsProcessor::Linear.draw(wizard) do |l|
        l.add_step :personal_details, PersonalDetailsStep
        l.add_step :utr_check, UtrCheckStep
        l.add_step :trading_details, TradingDetailsStep
        l.add_step :bank_details, BankDetailsStep
        l.add_step :confirmation, ConfirmationStep, exit: true
      end
    end

    it 'navigates to next step in sequence' do
      expect(processor.next_step(:personal_details)).to eq(:utr_check)
      expect(processor.next_step(:utr_check)).to eq(:trading_details)
      expect(processor.next_step(:trading_details)).to eq(:bank_details)
    end

    it 'returns nil for exit/terminal steps' do
      expect(processor.next_step(:confirmation)).to be_nil
    end

    it 'returns nil for last non-exit step with no more steps' do
      processor = DfE::Wizard::StepsProcessor::Linear.draw(wizard) do |l|
        l.add_step :step1, PersonalDetailsStep
        l.add_step :step2, UtrCheckStep
      end

      expect(processor.next_step(:step2)).to be_nil
    end

    it 'returns nil for invalid step ID' do
      expect(processor.next_step(:invalid_step)).to be_nil
    end

    it 'uses wizard current_step_name when step parameter is nil' do
      wizard.current_step_name = :utr_check
      expect(processor.next_step).to eq(:trading_details)

      wizard.current_step_name = :bank_details
      expect(processor.next_step).to eq(:confirmation)
    end

    it 'executes before_next callbacks' do
      callback_executed = false
      processor.add_before_next_callback_for_step(:personal_details) do
        callback_executed = true
        nil # Continue normally
      end

      processor.next_step(:personal_details)
      expect(callback_executed).to be true
    end

    it 'allows callbacks to override next step' do
      processor.add_before_next_callback_for_step(:personal_details) do
        :trading_details # Skip to step 3
      end

      expect(processor.next_step(:personal_details)).to eq(:trading_details)
    end

    it 'stops at first callback returning non-nil' do
      call_count = 0
      processor.add_before_next_callback_for_step(:personal_details) do
        call_count += 1
        :override_step
      end

      processor.add_before_next_callback_for_step(:personal_details) do
        call_count += 1
        nil
      end

      processor.next_step(:personal_details)
      expect(call_count).to eq(1) # Only first callback ran
    end
  end

  describe '#previous_step' do
    let(:wizard) { HmrcSelfAssessmentWizard.new }
    let(:processor) do
      DfE::Wizard::StepsProcessor::Linear.draw(wizard) do |l|
        l.add_step :personal_details, PersonalDetailsStep
        l.add_step :utr_check, UtrCheckStep
        l.add_step :trading_details, TradingDetailsStep
        l.add_step :bank_details, BankDetailsStep
        l.add_step :confirmation, ConfirmationStep
      end
    end

    it 'navigates to previous step in sequence' do
      expect(processor.previous_step(:confirmation)).to eq(:bank_details)
      expect(processor.previous_step(:bank_details)).to eq(:trading_details)
      expect(processor.previous_step(:trading_details)).to eq(:utr_check)
    end

    it 'returns nil at root step' do
      expect(processor.previous_step(:personal_details)).to be_nil
    end

    it 'returns nil for invalid step ID' do
      expect(processor.previous_step(:invalid_step)).to be_nil
    end

    it 'uses wizard current_step_name when step parameter is nil' do
      wizard.current_step_name = :trading_details
      expect(processor.previous_step).to eq(:utr_check)

      wizard.current_step_name = :bank_details
      expect(processor.previous_step).to eq(:trading_details)
    end

    it 'executes before_previous callbacks' do
      callback_executed = false
      processor.add_before_previous_callback_for_step(:confirmation) do
        callback_executed = true
        nil # Continue normally
      end

      processor.previous_step(:confirmation)
      expect(callback_executed).to be true
    end

    it 'allows callbacks to override previous step' do
      processor.add_before_previous_callback_for_step(:confirmation) do
        :utr_check # Jump back to step 2
      end

      expect(processor.previous_step(:confirmation)).to eq(:utr_check)
    end

    it 'stops at first callback returning non-nil' do
      call_count = 0
      processor.add_before_previous_callback_for_step(:confirmation) do
        call_count += 1
        :override_step
      end

      processor.add_before_previous_callback_for_step(:confirmation) do
        call_count += 1
        nil
      end

      processor.previous_step(:confirmation)
      expect(call_count).to eq(1)
    end
  end

  describe '#path_traversal' do
    let(:wizard) { DfeTeacherRegistrationWizard.new }
    let(:processor) do
      DfE::Wizard::StepsProcessor::Linear.draw(wizard) do |l|
        l.add_step :teacher_details, TeacherDetailsStep
        l.add_step :qualifications, QualificationsStep
        l.add_step :training_route, TrainingRouteStep
        l.add_step :availability, AvailabilityStep
        l.add_step :review, ReviewStep
      end
    end

    it 'returns path from root to target including both' do
      path = processor.path_traversal(:availability)
      expect(path).to eq(%i[teacher_details qualifications training_route availability])
    end

    it 'returns array with single step when target is root' do
      path = processor.path_traversal(:teacher_details)
      expect(path).to eq([:teacher_details])
    end

    it 'returns array to final step' do
      path = processor.path_traversal(:review)
      expect(path).to eq(%i[teacher_details qualifications training_route availability review])
    end

    it 'returns empty array for invalid target' do
      expect(processor.path_traversal(:invalid_step)).to eq([])
    end

    it 'returns empty array if target not found' do
      expect(processor.path_traversal(:nonexistent)).to eq([])
    end

    it 'is used for visualizations (progress bars, breadcrumbs)' do
      path = processor.path_traversal(:training_route)
      progress_percent = (path.count.to_f / processor.step_definitions.count) * 100

      expect(path.count).to eq(3)
      expect(progress_percent).to be_between(0, 100)
    end
  end

  describe '#find_step' do
    let(:wizard) { HmrcSelfAssessmentWizard.new }
    let(:processor) do
      DfE::Wizard::StepsProcessor::Linear.draw(wizard) do |l|
        l.add_step :personal_details, PersonalDetailsStep
        l.add_step :utr_check, UtrCheckStep
        l.add_step :trading_details, TradingDetailsStep
      end
    end

    it 'returns step class for valid step ID' do
      expect(processor.find_step(:personal_details)).to eq(PersonalDetailsStep)
      expect(processor.find_step(:utr_check)).to eq(UtrCheckStep)
      expect(processor.find_step(:trading_details)).to eq(TradingDetailsStep)
    end

    it 'returns nil for invalid step ID' do
      expect(processor.find_step(:invalid_step)).to be_nil
    end

    it 'can be used to instantiate step objects' do
      step_class = processor.find_step(:personal_details)
      expect(step_class).not_to be_nil

      step_instance = step_class.new
      expect(step_instance).to be_a(PersonalDetailsStep)
    end

    it 'returns nil without raising for missing steps' do
      expect { processor.find_step(:missing_step) }.not_to raise_error
      expect(processor.find_step(:missing_step)).to be_nil
    end
  end

  describe '#step_definitions' do
    let(:wizard) { HmrcSelfAssessmentWizard.new }
    let(:processor) do
      DfE::Wizard::StepsProcessor::Linear.draw(wizard) do |l|
        l.add_step :personal_details, PersonalDetailsStep
        l.add_step :utr_check, UtrCheckStep
        l.add_step :trading_details, TradingDetailsStep
        l.add_step :bank_details, BankDetailsStep
        l.add_step :confirmation, ConfirmationStep
      end
    end

    it 'returns hash of all step definitions' do
      definitions = processor.step_definitions

      expect(definitions).to be_a(Hash)
      expect(definitions.keys).to eq(%i[personal_details utr_check trading_details bank_details confirmation])
    end

    it 'maps step IDs to step classes' do
      definitions = processor.step_definitions

      expect(definitions[:personal_details]).to eq(PersonalDetailsStep)
      expect(definitions[:utr_check]).to eq(UtrCheckStep)
      expect(definitions[:confirmation]).to eq(ConfirmationStep)
    end

    it 'returns defensive copy (modifications do not affect processor)' do
      definitions = processor.step_definitions
      definitions[:new_step] = String

      # Original processor should not be affected
      expect(processor.step_definitions[:new_step]).to be_nil
    end

    it 'is used for validation' do
      definitions = processor.step_definitions

      definitions.each_key do |step_id|
        expect(processor.find_step(step_id)).not_to be_nil
      end
    end

    it 'returns empty hash for processor with no steps' do
      empty_processor = DfE::Wizard::StepsProcessor::Linear.new(wizard)
      expect(empty_processor.step_definitions).to eq({})
    end
  end

  describe '#metadata' do
    let(:wizard) { HmrcSelfAssessmentWizard.new }
    let(:processor) do
      DfE::Wizard::StepsProcessor::Linear.draw(wizard) do |l|
        l.name 'HMRC Self Assessment Registration'
        l.add_step :personal_details, PersonalDetailsStep, label: 'Personal Details'
        l.add_step :utr_check, UtrCheckStep, label: 'UTR Check'
        l.add_step :trading_details, TradingDetailsStep
        l.add_step :bank_details, BankDetailsStep
        l.add_step :confirmation, ConfirmationStep, exit: true
      end
    end

    it 'returns hash with structure_type key' do
      metadata = processor.metadata
      expect(metadata[:structure_type]).to eq(:linear)
    end

    it 'includes wizard name' do
      metadata = processor.metadata
      expect(metadata[:wizard_name]).to eq('HMRC Self Assessment Registration')
    end

    it 'includes root and exit steps' do
      metadata = processor.metadata

      expect(metadata[:root_step]).to eq(:personal_details)
      expect(metadata[:exit_steps]).to include(:confirmation)
    end

    it 'includes all steps with labels' do
      metadata = processor.metadata

      expect(metadata[:steps]).to be_a(Hash)
      expect(metadata[:steps][:personal_details]).to eq('Personal Details')
      expect(metadata[:steps][:utr_check]).to eq('UTR Check')
      expect(metadata[:steps][:trading_details]).to eq('Trading Details') # Humanized
    end

    it 'includes transitions for Mermaid/GraphViz' do
      metadata = processor.metadata

      expect(metadata[:transitions]).to be_an(Array)
      expect(metadata[:transitions].count).to eq(4) # 5 steps = 4 transitions

      first_transition = metadata[:transitions].first
      expect(first_transition[:from]).to eq(:personal_details)
      expect(first_transition[:to]).to eq(:utr_check)
      expect(first_transition[:type]).to eq(:unconditional)
    end

    it 'includes count statistics' do
      metadata = processor.metadata

      expect(metadata[:counts][:steps]).to eq(5)
      expect(metadata[:counts][:transitions]).to eq(4)
      expect(metadata[:counts][:unconditional_transitions]).to eq(4)
      expect(metadata[:counts][:conditional_transitions]).to eq(0)
      expect(metadata[:counts][:exit_points]).to eq(1)
    end

    it 'includes linear-specific metadata' do
      metadata = processor.metadata

      expect(metadata[:linear_metadata][:sequential]).to be true
      expect(metadata[:linear_metadata][:forward_only]).to be true
      expect(metadata[:linear_metadata][:skippable_steps]).to eq([])
    end

    it 'is used to generate Markdown documentation' do
      metadata = processor.metadata

      markdown = "# #{metadata[:wizard_name]}\n\n"
      markdown += "## Steps\n"
      metadata[:steps].each do |id, label|
        markdown += "- #{id}: #{label}\n"
      end

      expect(markdown).to include('HMRC Self Assessment Registration')
      expect(markdown).to include('Personal Details')
    end

    it 'is used to generate Mermaid diagrams' do
      metadata = processor.metadata

      mermaid = "graph TD\n"
      metadata[:steps].each do |id, label|
        mermaid += "  #{id}[\"#{label}\"]\n"
      end
      metadata[:transitions].each do |t|
        mermaid += "  #{t[:from]} --> #{t[:to]}\n"
      end

      expect(mermaid).to include('personal_details')
      expect(mermaid).to include('confirmation')
    end

    it 'validates structure before returning metadata' do
      incomplete_processor = DfE::Wizard::StepsProcessor::Linear.new(wizard)

      expect { incomplete_processor.metadata }.to raise_error(ArgumentError, /No steps defined/)
    end
  end

  describe 'DSL integration' do
    it 'allows fluent chaining of DSL methods' do
      wizard = DfeTeacherRegistrationWizard.new
      processor = DfE::Wizard::StepsProcessor::Linear.draw(wizard) do |l|
        l.name('Teacher Registration')
         .add_step(:teacher_details, TeacherDetailsStep)
         .add_step(:qualifications, QualificationsStep)
         .add_step(:training_route, TrainingRouteStep)
         .label(:teacher_details, 'Your Details')
         .exit(:training_route)
      end

      expect(processor.metadata[:wizard_name]).to eq('Teacher Registration')
      expect(processor.find_step(:teacher_details)).to eq(TeacherDetailsStep)
    end

    it 'supports callbacks for validation flows' do
      wizard = HmrcSelfAssessmentWizard.new
      validation_called = false

      processor = DfE::Wizard::StepsProcessor::Linear.draw(wizard) do |l|
        l.add_step :personal_details, PersonalDetailsStep
        l.add_step :confirmation, ConfirmationStep
        l.before_next(:personal_details) do
          validation_called = true
          nil
        end
      end

      processor.next_step(:personal_details)
      expect(validation_called).to be true
    end
  end

  describe 'real-world scenario: HMRC Self Assessment Registration' do
    it 'models complete self assessment registration flow' do
      wizard = HmrcSelfAssessmentWizard.new
      processor = DfE::Wizard::StepsProcessor::Linear.draw(wizard) do |l|
        l.name 'HMRC Self Assessment Registration'
        l.add_step :personal_details, PersonalDetailsStep, label: 'Personal Information'
        l.add_step :nino_check, UtrCheckStep, label: 'National Insurance Number Check'
        l.add_step :business_details, TradingDetailsStep, label: 'Business Details'
        l.add_step :bank_details, BankDetailsStep, label: 'Bank Account Details'
        l.add_step :review, ConfirmationStep, label: 'Review and Confirm'
        l.add_step :completion, ConfirmationStep, exit: true, label: 'Registration Complete'
      end

      # Verify navigation flow
      expect(processor.root_step).to eq(:personal_details)
      expect(processor.next_step(:personal_details)).to eq(:nino_check)
      expect(processor.path_traversal(:review).count).to eq(5)

      # Verify metadata for documentation
      metadata = processor.metadata
      expect(metadata[:steps].count).to eq(6)
      expect(metadata[:counts][:transitions]).to eq(5)
    end
  end

  describe 'real-world scenario: DfE Teacher Registration' do
    it 'models complete teacher registration flow' do
      wizard = DfeTeacherRegistrationWizard.new
      processor = DfE::Wizard::StepsProcessor::Linear.draw(wizard) do |l|
        l.name 'DfE Teacher Registration'
        l.add_step :teacher_details, TeacherDetailsStep, label: 'Your Details'
        l.add_step :qualifications, QualificationsStep, label: 'Teaching Qualifications'
        l.add_step :training_route, TrainingRouteStep, label: 'Training Route'
        l.add_step :availability, AvailabilityStep, label: 'Availability'
        l.add_step :review, ReviewStep, label: 'Review Application'
        l.add_step :submitted, ReviewStep, exit: true, label: 'Application Submitted'
      end

      # Navigation tests
      current = :teacher_details
      steps_visited = [current]

      until processor.next_step(current).nil?
        current = processor.next_step(current)
        steps_visited << current
      end

      expect(steps_visited).to eq(%i[teacher_details qualifications training_route availability review
                                     submitted])
    end
  end
end
