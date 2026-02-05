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
    @steps_processor ||= DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
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
