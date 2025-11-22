RSpec.describe DfE::Wizard::Core::StepManagement do
  # ============================================================================
  # WIZARD GRAPH STRUCTURE: English Foreign Language Wizard
  # ============================================================================
  #
  # EFL Qualification Wizard Flow:
  #
  #   [start]
  #      ↓
  #   has_qualification? (yes/no)
  #      ├─ yes → qualification_type (ielts/toefl/other)
  #      │          ├─ ielts → ielts_details
  #      │          ├─ toefl → toefl_details
  #      │          └─ other → other_details
  #      │              ↓ (all converge)
  #      │           review
  #      │
  #      └─ no → review
  #
  # ============================================================================

  let(:wizard_class) do
    Class.new do
      include DfE::Wizard

      def steps_processor
        DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
          graph.add_node :start, Steps::EflStart
          graph.add_node :qualification_type, Steps::QualificationType
          graph.add_node :ielts_details, Steps::IeltsDetails
          graph.add_node :toefl_details, Steps::ToeflDetails
          graph.add_node :other_details, Steps::OtherDetails
          graph.add_node :review, Steps::Review

          graph.root :start

          graph.add_edge from: :start, to: :qualification_type

          graph.add_conditional_edge(
            from: :qualification_type,
            when: :has_qualification?,
            then: :ielts_details,
            else: :review,
            label: 'Has Qualification',
          )

          graph.add_multiple_conditional_edges(
            from: :qualification_type,
            branches: [
              { when: :is_ielts?, then: :ielts_details },
              { when: :is_toefl?, then: :toefl_details },
              { when: :is_other?, then: :other_details },
            ],
            default: :review,
            label: 'Qualification Type',
          )

          graph.add_edge from: :ielts_details, to: :review
          graph.add_edge from: :toefl_details, to: :review
          graph.add_edge from: :other_details, to: :review
        end
      end

      def route_strategy
        DfE::Wizard::RouteStrategy::ConfigurableRoutes.new(wizard: self)
      end

      def logger
        DfE::Wizard::Logger.new(Rails.logger)
      end

      delegate :has_qualification?, :is_ielts?, :is_toefl?, :is_other?,
               to: :state_store
    end
  end

  let(:state_store_class) do
    Class.new do
      include DfE::Wizard::Core::StateStore

      def has_qualification?(_step = nil)
        # Solution 3: Read flat hash directly
        read[:has_qualification] == 'yes'
      end

      def is_ielts?(_step = nil)
        read[:qualification_type] == 'ielts'
      end

      def is_toefl?(_step = nil)
        read[:qualification_type] == 'toefl'
      end

      def is_other?(_step = nil)
        read[:qualification_type] == 'other'
      end
    end
  end

  before(:all) do
    unless defined?(Steps::EflStart)
      module Steps
        class EflStart
          include DfE::Wizard::Step

          attribute :qualification_status

          validates :qualification_status, presence: true, inclusion: { in: %w[has_qualification no_qualification] }

          def self.permitted_params
            %w[qualification_status]
          end
        end

        class QualificationType
          include DfE::Wizard::Step

          attribute :has_qualification
          attribute :qualification_type

          validates :has_qualification, presence: true, inclusion: { in: %w[yes no] }
          validates :qualification_type, presence: true, inclusion: { in: %w[ielts toefl other] }, if: lambda {
            has_qualification == 'yes'
          }

          def self.permitted_params
            %w[has_qualification qualification_type]
          end
        end

        class IeltsDetails
          include DfE::Wizard::Step

          attribute :ielts_score
          attribute :test_date

          validates :ielts_score, presence: true,
                                  numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 9 }
          validates :test_date, presence: true

          def self.permitted_params
            %w[ielts_score test_date]
          end
        end

        class ToeflDetails
          include DfE::Wizard::Step

          attribute :toefl_score
          attribute :test_date

          validates :toefl_score, presence: true,
                                  numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 120 }
          validates :test_date, presence: true

          def self.permitted_params
            %w[toefl_score test_date]
          end
        end

        class OtherDetails
          include DfE::Wizard::Step

          attribute :qualification_name
          attribute :test_date

          validates :qualification_name, :test_date, presence: true

          def self.permitted_params
            %w[qualification_name test_date]
          end
        end

        class Review
          include DfE::Wizard::Step

          def self.permitted_params
            []
          end
        end
      end
    end
  end

  let(:repository) { DfE::Wizard::Repository::InMemory.new }
  let(:state_store) { state_store_class.new(repository: repository) }
  let(:wizard) { wizard_class.new(current_step:, state_store:, current_step_params:) }
  let(:current_step) { :start }
  let(:current_step_params) { {} }

  describe '#find_step' do
    it 'returns step class for valid step' do
      expect(wizard.find_step(:start)).to eq(Steps::EflStart)
      expect(wizard.find_step(:ielts_details)).to eq(Steps::IeltsDetails)
    end

    it 'returns nil for non-existent step' do
      expect(wizard.find_step(:nonexistent)).to be_nil
    end

    it 'returns all step classes in flow' do
      %i[start qualification_type ielts_details toefl_details other_details review].each do |step_id|
        expect(wizard.find_step(step_id)).to be_a(Class)
      end
    end
  end

  describe '#permitted_params' do
    context 'at start step' do
      let(:current_step) { :start }

      it 'returns permitted params for EflStart' do
        expect(wizard.permitted_params).to eq(%w[qualification_status])
      end
    end

    context 'at qualification_type step' do
      let(:current_step) { :qualification_type }

      it 'returns permitted params for QualificationType' do
        expect(wizard.permitted_params).to eq(%w[has_qualification qualification_type])
      end
    end

    context 'at ielts_details step' do
      let(:current_step) { :ielts_details }

      it 'returns permitted params for IeltsDetails' do
        expect(wizard.permitted_params).to eq(%w[ielts_score test_date])
      end
    end

    context 'at review step' do
      let(:current_step) { :review }

      it 'returns empty array for Review' do
        expect(wizard.permitted_params).to eq([])
      end
    end
  end

  describe '#current_step_params' do
    context 'with Rails ActionController::Parameters' do
      let(:params) do
        ActionController::Parameters.new(
          qualification_type: {
            has_qualification: 'yes',
            qualification_type: 'ielts',
          },
        )
      end
      let(:current_step) { :qualification_type }
      let(:current_step_params) { params }

      it 'extracts and permits parameters for current step' do
        result = wizard.current_step_params

        expect(result[:has_qualification]).to eq('yes')
        expect(result[:qualification_type]).to eq('ielts')
      end

      it 'returns empty hash when step params not provided' do
        params_no_key = ActionController::Parameters.new({})
        wizard_instance = wizard_class.new(
          current_step: :qualification_type,
          state_store:,
          current_step_params: params_no_key,
        )

        expect(wizard_instance.current_step_params).to eq({})
      end
    end

    context 'with Hash' do
      let(:current_step_params) do
        {
          ielts_details: {
            ielts_score: 7.5,
            test_date: '2023-06-15',
          },
        }
      end
      let(:current_step) { :ielts_details }

      it 'extracts parameters for current step' do
        result = wizard.current_step_params

        expect(result[:ielts_score]).to eq(7.5)
        expect(result[:test_date]).to eq('2023-06-15')
      end

      it 'returns empty hash when step key missing' do
        wizard_instance = wizard_class.new(
          current_step: :qualification_type,
          state_store:,
          current_step_params: {},
        )

        expect(wizard_instance.current_step_params).to eq({})
      end
    end

    context 'with missing/invalid step parameters' do
      let(:current_step) { :qualification_type }
      let(:current_step_params) { {} }

      it 'returns empty hash' do
        expect(wizard.current_step_params).to eq({})
      end

      it 'does not raise error' do
        expect { wizard.current_step_params }.not_to raise_error
      end

      it 'handles NotImplementedError gracefully' do
        # When permitted_params is not defined
        allow_any_instance_of(Steps::QualificationType).to receive(:permitted_params).and_raise(NotImplementedError)

        expect(wizard.current_step_params).to eq({})
      end
    end
  end

  describe '#fetch_step_attributes' do
    context 'with no persisted data and no params' do
      let(:current_step) { :qualification_type }
      let(:current_step_params) { {} }

      it 'returns empty hash' do
        expect(wizard.fetch_step_attributes).to eq({})
      end
    end

    context 'with persisted data only' do
      let(:current_step) { :qualification_type }

      before do
        # Solution 3: Write flat hash directly to repository
        repository.write({
                           has_qualification: 'yes',
                           qualification_type: 'ielts',
                         })
      end

      it 'returns persisted data for current step attributes' do
        expect(wizard.fetch_step_attributes).to include(
          has_qualification: 'yes',
          qualification_type: 'ielts',
        )
      end
    end

    context 'with current step params only' do
      let(:current_step) { :ielts_details }
      let(:current_step_params) do
        {
          ielts_details: {
            ielts_score: 7.5,
            test_date: '2023-06-15',
          },
        }
      end

      it 'returns current params' do
        result = wizard.fetch_step_attributes

        expect(result[:ielts_score]).to eq(7.5)
        expect(result[:test_date]).to eq('2023-06-15')
      end
    end

    context 'with both persisted data and current params (params take precedence)' do
      let(:current_step) { :ielts_details }
      let(:current_step_params) do
        {
          ielts_details: {
            ielts_score: 8.0,
            test_date: '2024-01-01',
          },
        }
      end

      before do
        # Solution 3: Write flat hash
        repository.write({
                           ielts_score: 7.0,
                           test_date: '2023-01-01',
                         })
      end

      it 'merges with current params taking precedence' do
        result = wizard.fetch_step_attributes

        # Current params override persisted data
        expect(result[:ielts_score]).to eq(8.0)
        expect(result[:test_date]).to eq('2024-01-01')
      end
    end

    context 'merge with existing flat data' do
      let(:current_step) { :qualification_type }
      let(:current_step_params) do
        {
          qualification_type: {
            qualification_type: 'toefl',
          },
        }
      end

      before do
        # Solution 3: Flat hash with both attributes
        repository.write({
                           has_qualification: 'yes',
                           qualification_type: 'ielts',
                         })
      end

      it 'merges persisted and current data' do
        result = wizard.fetch_step_attributes

        # Persisted has_qualification preserved
        expect(result[:has_qualification]).to eq('yes')
        # Current params override qualification_type
        expect(result[:qualification_type]).to eq('toefl')
      end
    end
  end

  describe '#current_step (renamed from #current_step)' do
    context 'with no persisted data or params' do
      let(:current_step) { :start }

      it 'instantiates step with default values' do
        step = wizard.current_step

        expect(step).to be_a(Steps::EflStart)
        expect(step.step_id).to eq(:start)
        expect(step.wizard).to eq(wizard)
      end

      it 'caches the step instance' do
        step1 = wizard.current_step
        step2 = wizard.current_step

        expect(step1).to equal(step2)
      end
    end

    context 'with persisted and current data' do
      let(:current_step) { :ielts_details }
      let(:current_step_params) do
        {
          ielts_details: {
            ielts_score: 8.5,
            test_date: '2024-06-15',
          },
        }
      end

      before do
        # Solution 3: Write flat attributes
        repository.write({
                           ielts_score: 7.0,
                           test_date: '2023-06-15',
                         })
      end

      it 'hydrates step with merged data' do
        step = wizard.current_step

        expect(step).to be_a(Steps::IeltsDetails)
        expect(step.ielts_score).to eq(8.5)
        expect(step.test_date).to eq('2024-06-15')
      end

      it 'sets wizard and step_id' do
        step = wizard.current_step

        expect(step.wizard).to eq(wizard)
        expect(step.step_id).to eq(:ielts_details)
      end
    end

    context 'caching behavior' do
      let(:current_step) { :qualification_type }
      let(:current_step_params) do
        {
          qualification_type: {
            has_qualification: 'yes',
            qualification_type: 'ielts',
          },
        }
      end

      it 'caches instance across multiple accesses' do
        step1 = wizard.current_step
        step2 = wizard.current_step
        step3 = wizard.current_step

        expect(step1.object_id).to eq(step2.object_id)
        expect(step2.object_id).to eq(step3.object_id)
      end
    end
  end

  describe '#hydrate_step' do
    context 'for current step' do
      let(:current_step) { :ielts_details }
      let(:current_step_params) do
        {
          ielts_details: {
            ielts_score: 8.0,
            test_date: '2024-06-15',
          },
        }
      end

      before do
        # Solution 3: Flat attributes
        repository.write({
                           ielts_score: 7.0,
                           test_date: '2023-06-15',
                         })
      end

      it 'merges persisted and current params' do
        step = wizard.hydrate_step(:ielts_details)

        # Current params take precedence
        expect(step.ielts_score).to eq(8.0)
        expect(step.test_date).to eq('2024-06-15')
      end
    end

    context 'for non-current step' do
      let(:current_step) { :qualification_type }

      before do
        # Solution 3: Flat attributes for ielts
        repository.write({
                           ielts_score: 7.5,
                           test_date: '2023-06-15',
                         })
      end

      it 'uses only persisted data (ignores current_step_params)' do
        step = wizard.hydrate_step(:ielts_details)

        expect(step.ielts_score).to eq(7.5)
        expect(step.test_date).to eq('2023-06-15')
      end
    end

    context 'for step with no data' do
      let(:current_step) { :toefl_details }

      it 'instantiates with empty/default values' do
        step = wizard.hydrate_step(:toefl_details)

        expect(step).to be_a(Steps::ToeflDetails)
        expect(step.toefl_score).to be_nil
        expect(step.test_date).to be_nil
      end
    end
  end

  describe '#step' do
    context 'basic retrieval' do
      before do
        # Solution 3: Flat attributes
        repository.write({
                           has_qualification: 'yes',
                           qualification_type: 'ielts',
                         })
      end

      it 'returns hydrated step' do
        step = wizard.step(:qualification_type)

        expect(step).to be_a(Steps::QualificationType)
        expect(step.has_qualification).to eq('yes')
      end

      it 'caches step instances' do
        step1 = wizard.step(:qualification_type)
        step2 = wizard.step(:qualification_type)

        expect(step1.object_id).to eq(step2.object_id)
      end
    end

    context 'caching across different steps' do
      it 'maintains separate caches for each step' do
        start_step = wizard.step(:start)
        qual_step = wizard.step(:qualification_type)

        expect(start_step).to be_a(Steps::EflStart)
        expect(qual_step).to be_a(Steps::QualificationType)
        expect(start_step.object_id).not_to eq(qual_step.object_id)
      end

      it 'retrieves from cache on second access' do
        start_step_1 = wizard.step(:start)
        start_step_2 = wizard.step(:start)

        expect(start_step_1.object_id).to eq(start_step_2.object_id)
      end
    end
  end

  describe '#flow_steps' do
    before do
      # Solution 3: Write all flat attributes at once
      repository.write({
                         qualification_status: 'has_qualification',
                         has_qualification: 'yes',
                         qualification_type: 'ielts',
                         ielts_score: 7.5,
                         test_date: '2023-06-15',
                       })
    end

    let(:current_step) { :review }

    it 'returns step objects for all steps in flow' do
      steps = wizard.flow_steps

      expect(steps).to all(be_a(DfE::Wizard::Step))
    end

    it 'returns steps in flow order' do
      steps = wizard.flow_steps

      expect(steps.map(&:step_id)).to eq(%i[start qualification_type ielts_details review])
    end
  end

  describe '#saved_steps' do
    before do
      # Solution 3: Write flat hash
      repository.write({
                         qualification_status: 'has_qualification',
                         has_qualification: 'yes',
                         qualification_type: 'ielts',
                         ielts_score: 7.5,
                         test_date: '2023-06-15',
                       })
    end

    let(:current_step) { :ielts_details }

    it 'returns hydrated step objects with data' do
      steps = wizard.saved_steps

      expect(steps).to all(be_a(DfE::Wizard::Step))
      expect(steps.map(&:step_id)).to include(:start, :qualification_type, :ielts_details)
    end

    it 'contains steps with valid data' do
      saved = wizard.saved_steps

      expect(saved.map(&:step_id)).to eq(%i[start qualification_type ielts_details])
    end
  end

  describe '#valid_steps' do
    before do
      # Solution 3: Write flat attributes
      repository.write({
                         qualification_status: 'has_qualification',
                         has_qualification: 'yes',
                         qualification_type: 'ielts',
                         ielts_score: 7.5,
                         test_date: '2023-06-15',
                       })
    end

    let(:current_step) { :ielts_details }

    it 'returns only valid steps' do
      steps = wizard.valid_steps

      expect(steps).to all(be_valid)
    end
  end

  describe '#step with params filtering' do
    context 'ActionController::Parameters provided' do
      let(:params) do
        ActionController::Parameters.new(
          ielts_details: {
            ielts_score: 8.0,
            test_date: '2024-06-15',
            extra_field: 'should_be_filtered',
          },
        )
      end
      let(:current_step) { :ielts_details }
      let(:current_step_params) { params }

      it 'filters parameters based on permitted_params' do
        step = wizard.current_step

        expect(step.ielts_score).to eq(8.0)
        expect(step.test_date).to eq('2024-06-15')
        expect(step.attributes).to eq({ 'ielts_score' => 8.0, 'test_date' => '2024-06-15' })
      end
    end
  end

  describe '#step with symbol key conversion' do
    let(:current_step) { :qualification_type }
    let(:current_step_params) do
      {
        qualification_type: {
          'has_qualification' => 'yes', # String key
          'qualification_type' => 'toefl', # String key
        },
      }
    end

    before do
      # Solution 3: Flat attributes
      repository.write({
                         has_qualification: 'yes',
                         qualification_type: 'ielts',
                       })
    end

    it 'converts string keys to symbols for step initialization' do
      step = wizard.current_step

      # Should be able to access with symbols despite string keys in params
      expect(step.has_qualification).to eq('yes')
      expect(step.qualification_type).to eq('toefl')
    end
  end

  describe 'integration: complete wizard flow' do
    let(:current_step) { :review }
    let(:current_step_params) { {} }

    before do
      # Solution 3: Write all flat attributes
      repository.write({
                         qualification_status: 'has_qualification',
                         has_qualification: 'yes',
                         qualification_type: 'ielts',
                         ielts_score: 7.5,
                         test_date: '2023-06-15',
                       })
    end

    it 'retrieves all steps with complete data' do
      flow_steps = wizard.flow_steps

      expect(flow_steps.size).to eq(4)
      expect(flow_steps.map(&:class)).to eq([
                                              Steps::EflStart,
                                              Steps::QualificationType,
                                              Steps::IeltsDetails,
                                              Steps::Review,
                                            ])
    end

    it 'hydrates steps with correct data' do
      start_step = wizard.step(:start)
      qual_step = wizard.step(:qualification_type)
      ielts_step = wizard.step(:ielts_details)

      expect(start_step.qualification_status).to eq('has_qualification')
      expect(qual_step.has_qualification).to eq('yes')
      expect(qual_step.qualification_type).to eq('ielts')
      expect(ielts_step.ielts_score).to eq(7.5)
    end

    it 'caches steps properly during flow traversal' do
      step1 = wizard.step(:qualification_type)
      step2 = wizard.step(:qualification_type)

      expect(step1.object_id).to eq(step2.object_id)
    end
  end

  describe 'integration: different qualification types' do
    context 'TOEFL path' do
      let(:current_step) { :review }

      before do
        # Solution 3: Flat attributes for TOEFL path
        repository.write({
                           qualification_status: 'has_qualification',
                           has_qualification: 'yes',
                           qualification_type: 'toefl',
                           toefl_score: 110,
                           test_date: '2024-06-15',
                         })
      end

      it 'returns TOEFL step with correct data' do
        step = wizard.step(:toefl_details)

        expect(step).to be_a(Steps::ToeflDetails)
        expect(step.toefl_score).to eq(110)
      end
    end

    context 'Other qualification path' do
      let(:current_step) { :review }

      before do
        # Solution 3: Flat attributes for Other path
        repository.write({
                           qualification_status: 'has_qualification',
                           has_qualification: 'yes',
                           qualification_type: 'other',
                           qualification_name: 'Cambridge CPE',
                           test_date: '2023-12-01',
                         })
      end

      it 'returns Other qualification step with correct data' do
        step = wizard.step(:other_details)

        expect(step).to be_a(Steps::OtherDetails)
        expect(step.qualification_name).to eq('Cambridge CPE')
      end
    end

    context 'No qualification path' do
      let(:current_step) { :review }

      before do
        # Solution 3: Flat attributes for no qualification
        repository.write({
                           qualification_status: 'no_qualification',
                           has_qualification: 'no',
                         })
      end

      it 'skips qualification detail steps' do
        flow_path = wizard.flow_path

        expect(flow_path).not_to include(:ielts_details, :toefl_details, :other_details)
        expect(flow_path).to eq(%i[start qualification_type review])
      end
    end
  end

  describe 'error handling: parameter extraction' do
    let(:current_step) { :qualification_type }

    context 'when ActionController::ParameterMissing is raised' do
      it 'returns empty hash gracefully' do
        invalid_params = ActionController::Parameters.new({})

        wizard_instance = wizard_class.new(
          current_step:,
          state_store:,
          current_step_params: invalid_params,
        )

        expect(wizard_instance.current_step_params).to eq({})
      end
    end

    context 'when NotImplementedError is raised' do
      it 'returns empty hash' do
        # When permitted_params raises NotImplementedError
        params = { qualification_type: {} }

        wizard_instance = wizard_class.new(
          current_step:,
          state_store:,
          current_step_params: params,
        )

        expect(wizard_instance.current_step_params).to eq({})
      end
    end
  end
end
