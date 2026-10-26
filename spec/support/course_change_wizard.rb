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
    def self.choice(name, attribute, options)
      Class.new do
        include DfE::Wizard::Step

        attribute attribute, :string
        validates attribute, inclusion: { in: options }

        define_singleton_method(:permitted_params) { [attribute] }
        define_singleton_method(:name) { "CourseChange::Steps::#{name}" }
      end
    end

    def self.yes_no(name, attribute)
      Class.new do
        include DfE::Wizard::Step

        attribute attribute, :boolean
        validates attribute, inclusion: { in: [true, false] }

        define_singleton_method(:permitted_params) { [attribute] }
        define_singleton_method(:name) { "CourseChange::Steps::#{name}" }
      end
    end

    Level = choice('Level', :level, %w[secondary further_education])
    Subject = choice('Subject', :subject, %w[physics history])
    PhysicsSpecialism = choice('PhysicsSpecialism', :physics_specialism, %w[engineers none])
    Qualification = choice('Qualification', :qualification, %w[qts tda])
    FundingType = choice('FundingType', :funding_type, %w[fee salary])
    StudentVisa = yes_no('StudentVisa', :can_sponsor_student_visa)
    SkilledWorkerVisa = yes_no('SkilledWorkerVisa', :can_sponsor_skilled_worker_visa)
    DeadlineRequired = yes_no('DeadlineRequired', :visa_deadline_required)
    DeadlineAt = choice('DeadlineAt', :visa_deadline_at, %w[2026-09-01 2026-10-01])
    StartDate = choice('StartDate', :start_date, %w[2026-09 2027-01])
    Declaration = yes_no('Declaration', :declared)

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
end
