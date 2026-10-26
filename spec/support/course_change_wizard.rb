# A small course wizard for the check answers specs. Its branches mirror the
# changes users make from check answers: a subject that needs a specialism,
# a qualification that skips funding, funding that picks the visa question,
# and visa answers that bring in the deadline questions.
#
#   level ─(further education)─────────────────────────┐
#     └─ subject ─(physics)─ physics_specialism ─┐      │
#            └───────────────────────────────────┴─ qualification
#   qualification ─(tda)──────────────────────────────────────── start_date
#     └─ funding_type ─(salary)─ skilled_worker_visa ─(yes)─ deadline_required
#            └──────────────── student_visa ─(yes)───────┘   ├─(yes)─ deadline_at ─ start_date
#                                                            └──────────────────── start_date
#   start_date ─ check_answers ─ declaration ─ courses (redirect)
#
# During a change (a return_to_review param) it uses the review navigation.
module CourseChange
  class StateStore
    include DfE::Wizard::StateStore

    def further_education?
      level == 'further_education'
    end

    def physics?
      subject == 'physics'
    end

    def tda?
      qualification == 'tda'
    end

    def salary?
      funding_type == 'salary'
    end

    def sponsors_student_visa?
      can_sponsor_student_visa == true
    end

    def sponsors_skilled_worker_visa?
      can_sponsor_skilled_worker_visa == true
    end

    def deadline_required?
      visa_deadline_required == true
    end
  end

  module Steps
    # A question: its permitted params are its attributes
    class Question
      include DfE::Wizard::Step

      def self.permitted_params
        attribute_names.map(&:to_sym)
      end
    end

    Level = Class.new(Question) do
      attribute :level, :string
      validates :level, inclusion: { in: %w[secondary further_education] }
    end

    Subject = Class.new(Question) do
      attribute :subject, :string
      validates :subject, inclusion: { in: %w[physics history] }
    end

    PhysicsSpecialism = Class.new(Question) do
      attribute :physics_specialism, :string
      validates :physics_specialism, inclusion: { in: %w[engineers none] }
    end

    Qualification = Class.new(Question) do
      attribute :qualification, :string
      validates :qualification, inclusion: { in: %w[qts tda] }
    end

    FundingType = Class.new(Question) do
      attribute :funding_type, :string
      validates :funding_type, inclusion: { in: %w[fee salary] }
    end

    StudentVisa = Class.new(Question) do
      attribute :can_sponsor_student_visa, :boolean
      validates :can_sponsor_student_visa, inclusion: { in: [true, false] }
    end

    SkilledWorkerVisa = Class.new(Question) do
      attribute :can_sponsor_skilled_worker_visa, :boolean
      validates :can_sponsor_skilled_worker_visa, inclusion: { in: [true, false] }
    end

    DeadlineRequired = Class.new(Question) do
      attribute :visa_deadline_required, :boolean
      validates :visa_deadline_required, inclusion: { in: [true, false] }
    end

    DeadlineAt = Class.new(Question) do
      attribute :visa_deadline_at, :string
      validates :visa_deadline_at, inclusion: { in: %w[2026-09-01 2026-10-01] }
    end

    StartDate = Class.new(Question) do
      attribute :start_date, :string
      validates :start_date, inclusion: { in: %w[2026-09 2027-01] }
    end

    Declaration = Class.new(Question) do
      attribute :declared, :boolean
      validates :declared, inclusion: { in: [true, false] }
    end

    class CheckAnswers
      include DfE::Wizard::Step

      def self.permitted_params
        []
      end
    end
  end

  class Wizard
    include DfE::Wizard

    def steps_processor
      DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
        graph.add_node :level, Steps::Level
        graph.add_node :subject, Steps::Subject
        graph.add_node :physics_specialism, Steps::PhysicsSpecialism
        graph.add_node :qualification, Steps::Qualification
        graph.add_node :funding_type, Steps::FundingType
        graph.add_node :student_visa, Steps::StudentVisa
        graph.add_node :skilled_worker_visa, Steps::SkilledWorkerVisa
        graph.add_node :deadline_required, Steps::DeadlineRequired
        graph.add_node :deadline_at, Steps::DeadlineAt
        graph.add_node :start_date, Steps::StartDate
        graph.check_answers :check_answers, Steps::CheckAnswers
        graph.add_node :declaration, Steps::Declaration
        graph.add_node :courses, DfE::Wizard::Redirect

        graph.root :level
        graph.add_conditional_edge from: :level, when: :further_education?, then: :qualification, else: :subject
        graph.add_conditional_edge from: :subject, when: :physics?, then: :physics_specialism, else: :qualification
        graph.add_edge from: :physics_specialism, to: :qualification
        graph.add_conditional_edge from: :qualification, when: :tda?, then: :start_date, else: :funding_type
        graph.add_conditional_edge from: :funding_type, when: :salary?, then: :skilled_worker_visa, else: :student_visa
        graph.add_conditional_edge from: :student_visa, when: :sponsors_student_visa?,
                                   then: :deadline_required, else: :start_date
        graph.add_conditional_edge from: :skilled_worker_visa, when: :sponsors_skilled_worker_visa?,
                                   then: :deadline_required, else: :start_date
        graph.add_conditional_edge from: :deadline_required, when: :deadline_required?,
                                   then: :deadline_at, else: :start_date
        graph.add_edge from: :deadline_at, to: :start_date
        graph.add_edge from: :start_date, to: :check_answers
        graph.add_edge from: :check_answers, to: :declaration
        graph.add_edge from: :declaration, to: :courses

        graph.before_next_step { next_step_in_review if return_to_review }
        graph.before_previous_step { previous_step_in_review(return_to_review) }
      end
    end

    # The step whose Change link the user followed on check answers
    def return_to_review
      @current_step_params[:return_to_review]
    end

    # Answers for a complete secondary history course: QTS, fee-paying,
    # sponsoring student visas with an application deadline
    def self.complete_answers
      {
        level: 'secondary',
        subject: 'history',
        qualification: 'qts',
        funding_type: 'fee',
        can_sponsor_student_visa: true,
        visa_deadline_required: true,
        visa_deadline_at: '2026-09-01',
        start_date: '2026-09',
      }
    end
  end

  # A graph whose path stops before check answers when the level is not
  # further education: the edge from level has no matching branch
  class DeadEndWizard
    include DfE::Wizard

    def steps_processor
      DfE::Wizard::StepsProcessor::Graph.draw(self, predicate_caller: state_store) do |graph|
        graph.add_node :level, Steps::Level
        graph.add_node :subject, Steps::Subject
        graph.check_answers :check_answers, Steps::CheckAnswers
        graph.root :level
        graph.add_multiple_conditional_edges from: :level, branches: [{ when: :further_education?, then: :subject }]
        graph.add_edge from: :subject, to: :check_answers
      end
    end
  end
end
