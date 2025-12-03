RSpec.describe DfE::Wizard::Core::Metadata do
  class WorkExperienceStateStore
    include DfE::Wizard::StateStore
  end

  module Steps
    class WorkTitle
      include DfE::Wizard::Step

      attribute :title, :string

      validates :title, presence: true, length: { minimum: 2, maximum: 100 }

      def self.permitted_params
        %i[title]
      end
    end

    class Employer
      include DfE::Wizard::Step

      attribute :name, :string
      attribute :website, :string

      validates :name, presence: true, length: { minimum: 2 }
      validates :website, format: { with: URI::DEFAULT_PARSER.make_regexp, message: 'must be valid URL' },
                          allow_blank: true

      def self.permitted_params
        %i[name website]
      end
    end

    class StartDate
      include DfE::Wizard::Step

      attribute :date, :string

      validates :date, presence: true
      validates :date, format: { with: /\A\d{4}-\d{2}-\d{2}\z/, message: 'must be YYYY-MM-DD format' }

      def self.permitted_params
        %i[date]
      end
    end

    class EndDate
      include DfE::Wizard::Step

      attribute :date, :string

      validates :date, presence: true
      validates :date, format: { with: /\A\d{4}-\d{2}-\d{2}\z/, message: 'must be YYYY-MM-DD format' }

      def self.permitted_params
        %i[date]
      end
    end

    class Review
      include DfE::Wizard::Step

      def self.permitted_params
        []
      end
    end
  end

  class SendNotification
    def initialize(repository:, step:)
      @repository = repository
      @step = step
    end

    def execute
      { success: true, notification_sent: true }
    end

    def rollback
      # No-op
    end
  end

  class SendEmail
    def self.description
      'Send email after is saved successfully.'
    end

    def execute
      { success: true, notification_sent: true }
    end

    def rollback
      # No-op
    end
  end

  class WorkExperienceWizard
    include DfE::Wizard

    def steps_processor
      @steps_processor ||= DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
        graph.add_node :work_title, Steps::WorkTitle
        graph.add_node :employer, Steps::Employer
        graph.add_node :start_date, Steps::StartDate
        graph.add_node :end_date, Steps::EndDate
        graph.add_node :review, Steps::Review

        graph.root :work_title
        graph.add_edge from: :work_title, to: :employer
        graph.add_edge from: :employer, to: :start_date
        graph.add_edge from: :start_date, to: :end_date
        graph.add_edge from: :end_date, to: :review
      end
    end

    def steps_operator
      @steps_operator ||= DfE::Wizard::StepsOperator::Builder.draw(
        wizard: self,
        callable: state_store,
      ) do |builder|
        builder.on_step(:work_title, add: [])
        builder.on_step(:employer, add: [SendNotification])
        builder.on_step(:start_date, add: [])
        builder.on_step(:end_date, add: [])
        builder.on_step(:review, use: [SendEmail])
      end
    end
  end

  let(:wizard) { WorkExperienceWizard.new(state_store: WorkExperienceStateStore.new) }

  describe 'Attributes Extraction' do
    let(:metadata) { described_class.new(wizard).to_h }

    describe 'work_title step' do
      let(:step_data) { metadata[:steps][:work_title] }

      it 'extracts attribute' do
        expect(step_data[:attributes]).to eq(
          [
            {
              name: :title,
              type: ActiveModel::Type::String,
            },
          ],
        )
      end
    end

    describe 'employer step' do
      let(:step_data) { metadata[:steps][:employer] }

      it 'extracts attributes' do
        expect(step_data[:attributes]).to eq(
          [
            {
              name: :name,
              type: ActiveModel::Type::String,
            },
            {
              name: :website,
              type: ActiveModel::Type::String,
            },
          ],
        )
      end
    end

    describe 'review step' do
      let(:step_data) { metadata[:steps][:review] }

      it 'has no attributes' do
        expect(step_data[:attributes]).to eq([])
      end
    end
  end

  describe 'Validators Extraction' do
    let(:metadata) { described_class.new(wizard).to_h }

    describe 'work_title step' do
      let(:step_data) { metadata[:steps][:work_title] }

      it 'extracts validators' do
        expect(step_data[:validators]).to eq(
          [
            {
              name: :title,
              class: 'ActiveModel::Validations::PresenceValidator',
              type: :presence,
              message: nil,
            },
            {
              name: :title,
              class: 'ActiveModel::Validations::LengthValidator',
              type: :length,
              message: nil,
            },
          ],
        )
      end
    end

    describe 'employer step' do
      let(:step_data) { metadata[:steps][:employer] }

      it 'extracts validators' do
        expect(step_data[:validators]).to eq(
          [
            {
              name: :name,
              class: 'ActiveModel::Validations::PresenceValidator',
              type: :presence,
              message: nil,
            },
            {
              name: :name,
              class: 'ActiveModel::Validations::LengthValidator',
              type: :length,
              message: nil,
            },
            {
              name: :website,
              class: 'ActiveModel::Validations::FormatValidator',
              type: :format,
              message: 'must be valid URL',
            },
          ],
        )
      end
    end

    describe 'start_date step' do
      let(:step_data) { metadata[:steps][:start_date] }

      it 'extracts validators' do
        expect(step_data[:validators]).to eq(
          [
            {
              class: 'ActiveModel::Validations::PresenceValidator',
              message: nil,
              name: :date,
              type: :presence,
            },
            {
              class: 'ActiveModel::Validations::FormatValidator',
              message: 'must be YYYY-MM-DD format',
              name: :date,
              type: :format,
            },
          ],
        )
      end
    end

    describe 'review step' do
      let(:step_data) { metadata[:steps][:review] }

      it 'has no validators' do
        expect(step_data[:validators]).to eq([])
      end
    end
  end

  describe 'Operations Extraction' do
    let(:metadata) { described_class.new(wizard).to_h }

    describe 'work_title step' do
      let(:step_data) { metadata[:steps][:work_title] }

      it 'has operations' do
        expect(step_data[:operations]).to eq(
          [
            {
              description: 'Validate operation',
              name: :validate,
            },
            {
              description: 'Persist operation',
              name: :persist,
            },
          ],
        )
      end
    end

    describe 'employer step' do
      let(:step_data) { metadata[:steps][:employer] }

      it 'has validate, persist, and send_notification operations' do
        expect(step_data[:operations]).to eq(
          [
            {
              description: 'Validate operation',
              name: :validate,
            },
            {
              description: 'Persist operation',
              name: :persist,
            },
            {
              description: 'SendNotification operation',
              name: :send_notification,
            },
          ],
        )
      end
    end

    describe 'start_date step' do
      let(:step_data) { metadata[:steps][:start_date] }

      it 'has validate and persist operations' do
        expect(step_data[:operations]).to eq(
          [
            {
              description: 'Validate operation',
              name: :validate,
            },
            {
              description: 'Persist operation',
              name: :persist,
            },
          ],
        )
      end
    end

    describe 'end_date step' do
      let(:step_data) { metadata[:steps][:end_date] }

      it 'has validate and persist operations' do
        expect(step_data[:operations]).to eq(
          [
            {
              description: 'Validate operation',
              name: :validate,
            },
            {
              description: 'Persist operation',
              name: :persist,
            },
          ],
        )
      end
    end

    describe 'review step' do
      let(:step_data) { metadata[:steps][:review] }

      it 'has no operations' do
        expect(step_data[:operations]).to eq(
          [
            {
              description: 'Send email after is saved successfully.',
              name: :send_email,
            },
          ],
        )
      end
    end
  end

  describe 'Complete Metadata' do
    let(:metadata) { described_class.new(wizard).to_h }

    it 'metadata structure type is :graph' do
      expect(metadata[:structure_type]).to eq(:graph)
    end

    it 'root_step is :work_title' do
      expect(metadata[:root_step]).to eq(:work_title)
    end

    it 'all 5 steps present' do
      step_ids = metadata[:steps].keys
      expect(step_ids).to match_array(%i[work_title employer start_date end_date review])
    end

    it 'work_title has label' do
      expect(metadata[:steps][:work_title][:label]).not_to be_nil
    end

    it 'work_title has class reference' do
      expect(metadata[:steps][:work_title][:class]).not_to be_nil
    end
  end

  describe 'Initialization Errors' do
    it 'raises ArgumentError when wizard has no steps_processor' do
      bad_wizard = Object.new
      expect do
        described_class.new(bad_wizard)
      end.to raise_error(ArgumentError, /steps_processor/)
    end
  end

  describe 'Caching' do
    let(:metadata_object) { described_class.new(wizard) }

    it 'returns same instance on multiple to_h calls' do
      first = metadata_object.to_h
      second = metadata_object.to_h
      expect(first).to equal(second)
    end
  end

  describe 'Non-Destructive Enrichment' do
    it 'does not modify processor metadata' do
      original = wizard.steps_processor.metadata.deep_dup
      described_class.new(wizard).to_h
      expect(wizard.steps_processor.metadata).to eq(original)
    end
  end

  describe 'Hash-like Access' do
    let(:metadata_object) { described_class.new(wizard) }

    it 'bracket access returns structure_type' do
      expect(metadata_object[:structure_type]).to eq(:graph)
    end

    it 'bracket access returns steps hash' do
      expect(metadata_object[:steps]).to be_a(Hash)
    end

    it 'key? returns true for structure_type' do
      expect(metadata_object.key?(:structure_type)).to be true
    end

    it 'key? returns false for nonexistent key' do
      expect(metadata_object.key?(:nonexistent)).to be false
    end

    it 'to_hash returns same as to_h' do
      expect(metadata_object.to_hash).to eq(metadata_object.to_h)
    end

    it 'each iteration includes all metadata keys' do
      keys = []
      values = []

      metadata_object.each do |key, value|
        keys << key
        values << value
      end

      expect(keys).to include(:structure_type, :steps, :root_step, :transitions)
      expect(values).to include(:graph)
    end
  end
end
