# 1.0.0 future
#
# RegisterECTWizard.new(
# current_step: :find_ect,
# state_store: SomeStore.new(),
# step_params: {}
# )
#
class RegisterECTWizard
  include DfE::Wizard

  include Steps
  delegate :in_trs?,
           :matches_trs_dob?,
           :active_at_school?,
           :induction_exempt?,
           :prohibited_from_teaching?,
           :induction_completed?,
           :cant_use_email?,
           :school_independent?,
           :provider_led?,
           to: :state_store

  def steps_processor
    DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
      graph.add_node :cannot_register_ect, CannotRegisterECTStep
      graph.add_node :cant_use_email, CantUseEmailStep
      graph.add_node :check_answers, CheckAnswersStep
      graph.add_node :confirmation, ConfirmationStep
      graph.add_node :email_address, EmailAddressStep
      graph.add_node :find_ect, FindECTStep
      graph.add_node :trn_not_found, TRNNotFoundStep
      graph.add_node :already_active_at_school, AlreadyActiveAtSchoolStep
      graph.add_node :independent_school_appropriate_body, IndependentSchoolAppropriateBodyStep
      graph.add_node :induction_completed, InductionCompletedStep
      graph.add_node :induction_exempt, InductionExemptStep
      graph.add_node :lead_provider, LeadProviderStep
      graph.add_node :national_insurance_number, NationalInsuranceNumberStep
      graph.add_node :not_found, NotFoundStep
      graph.add_node :programme_type, ProgrammeTypeStep
      graph.add_node :review_ect_details, ReviewECTDetailsStep
      graph.add_node :start_date, StartDateStep
      graph.add_node :state_school_appropriate_body, StateSchoolAppropriateBodyStep
      graph.add_node :working_pattern, WorkingPatternStep

      graph.root :find_ect

      graph.add_custom_branching_edge(
        from: :find_ect,
        conditional: :find_ect_transitions,
        # this option is only for auto-generated documentation
        potential_transitions: [
          { label: 'TRN not found', nodes: [:trn_not_found] },
          { label: 'National Insurance number', nodes: [:national_insurance_number] },
          { label: 'Already active at school', nodes: [:already_active_at_school] },
          { label: 'Induction completed', nodes: [:induction_completed] },
          { label: 'Induction exempt', nodes: [:induction_exempt] },
          { label: 'Can not register ECT', nodes: [:cannot_register_ect] },
          { label: 'Review ECT details', nodes: [:review_ect_details] },
        ],
      )

      # This method does not exist yet.
      # graph.add_conditional_edges(
      #  from: :national_insurance_number,
      #  transitions: [
      #    {
      #      when: :in_trs?,
      #      then: :not_found,
      #    },
      #    {
      #      when: :induction_completed?,
      #      then: :induction_completed
      #    },
      #    {
      #      when: :induction_exempt?,
      #      then: :induction_exempt
      #    }
      #  ],
      #  else: :review_ect_details,
      #  label: 'Review ECT details',
      # )

      # Or the above you can do as below:
      graph.add_custom_branching_edge(
        from: :national_insurance_number,
        conditional: :national_insurance_number_transitions,
        # this option is only for auto-generated documentation
        potential_transitions: [
          { label: 'In TRS?', nodes: [:not_found] },
          { label: 'Induction completed?', nodes: [:induction_completed] },
          { label: 'Induction exempt', nodes: [:induction_exempt] },
          { label: 'Review ECT details', nodes: [:review_ect_details] },
        ],
      )

      graph.add_edge from: :review_ect_details, to: :email_address

      graph.add_conditional_edge(
        from: :email_address,
        when: :cant_use_email?,
        then: :cant_use_email,
        else: :start_date,
        label: 'Can not use email',
      )

      graph.add_edge from: :start_date, to: :working_pattern

      graph.add_conditional_edge(
        from: :working_pattern,
        when: :school_independent?,
        then: :independent_school_appropriate_body,
        else: :state_school_appropriate_body,
        label: 'School independent?',
      )

      graph.add_edge from: :independent_school_appropriate_body, to: :programme_type
      graph.add_edge from: :state_school_appropriate_body, to: :programme_type

      graph.add_conditional_edge(
        from: :programme_type,
        when: :provider_led?,
        then: :lead_provider,
        else: :check_answers,
        label: 'School independent?',
      )

      graph.add_edge from: :lead_provider, to: :check_answers
      graph.add_edge from: :check_answers, to: :confirmation

      graph.before_next_step(:next_step_override)

      # stil implementing the override
      #      graph.before_previous_step(:previous_step_override)
    end
  end

  def route_strategy
    DfE::Wizard::RouteStrategy::NamedRoutes.new(
      wizard: self,
      namespace: 'register-ect',
    )
  end

  def logger
    DfE::Wizard::Logger.new(Rails.logger) if Rails.env.local?
  end

  # Given you have a wizard like these:
  #
  # A -> B -> C -> D -> CYA
  #      |              |
  #      -> E  -> F ->  G
  #
  # If you were on A -> B -> C -> D -> CYA and the click change on "B" user
  # returned to B step.
  #
  # Then on B you answer something else that needs to go to E.
  #
  # then you don't have a full traversal to CYA anymore and need now to
  # go to E
  #
  #  path_traversal(A -> CYA) => [] # will return empty
  #
  # Then answer E, still not up to CYA then go to G
  #
  #  path_traversal(A -> CYA) => [] # will return empty
  #
  # Then G user answer end up on CYA then is a full path traversal return CYA.
  #
  #     path_traversal(A -> CYA) => [:A, :B, :E, :F, :G, :CYA]
  #
  def next_step_override
    target = step_params[:return_to_review]

    target if user_up_to_check_answers? && target.present?
  end

  # return_to_review="B" B is the page that the user click "Change"
  #
  # A -> B -> C -> D -> CYA
  #      |              |
  #      -> E  -> F ->  G
  #
  # If you were on A -> B -> C -> D -> CYA and the click change on "B"
  # the previous step will go to CYA
  #
  #  ?return_to_review=B
  #
  #  the user change branch and to E
  #
  #  ?return_to_review=B so previous step will be B
  #
  def previous_step_overrride
    target = step_params[:return_to_review]

    target if user_up_to_check_answers? && full_traversal.include?(target)
  end

  def user_up_to_check_answers?
    full_traversal.include?(:check_answers)
  end

  def full_traversal
    path_traversal(:check_answers)
  end

  def find_ect_transitions
    return :trn_not_found unless in_trs?
    return :national_insurance_number unless matches_trs_dob?
    return :already_active_at_school if active_at_school?
    return :induction_completed if induction_completed?
    return :induction_exempt if induction_exempt?
    return :cannot_register_ect if prohibited_from_teaching?

    :review_ect_details
  end

  def national_insurance_number_transitions(_data)
    return :not_found unless in_trs?
    return :induction_completed if induction_completed?
    return :induction_exempt if induction_exempt?

    :review_ect_details
  end
end

# 0.1.1
# module Schools
#  module RegisterECTWizard
#    class Wizard < DfE::Wizard::Base
#      attr_accessor :store, :school
#
#      steps do
#        [
#          {
#            already_active_at_school: AlreadyActiveAtSchoolStep,
#            cannot_register_ect: CannotRegisterECTStep,
#            cant_use_email: CantUseEmailStep,
#            change_email_address: ChangeEmailAddressStep,
#            change_independent_school_appropriate_body: ChangeIndependentSchoolAppropriateBodyStep,
#            change_lead_provider: ChangeLeadProviderStep,
#            change_programme_type: ChangeProgrammeTypeStep,
#            change_review_ect_details: ChangeReviewECTDetailsStep,
#            change_start_date: ChangeStartDateStep,
#            change_state_school_appropriate_body: ChangeStateSchoolAppropriateBodyStep,
#            change_working_pattern: ChangeWorkingPatternStep,
#            check_answers: CheckAnswersStep,
#            confirmation: ConfirmationStep,
#            email_address: EmailAddressStep,
#            find_ect: FindECTStep,
#            independent_school_appropriate_body: IndependentSchoolAppropriateBodyStep,
#            induction_completed: InductionCompletedStep,
#            induction_exempt: InductionExemptStep,
#            lead_provider: LeadProviderStep,
#            national_insurance_number: NationalInsuranceNumberStep,
#            not_found: NotFoundStep,
#            programme_type: ProgrammeTypeStep,
#            review_ect_details: ReviewECTDetailsStep,
#            start_date: StartDateStep,
#            state_school_appropriate_body: StateSchoolAppropriateBodyStep,
#            trn_not_found: TRNNotFoundStep,
#            working_pattern: WorkingPatternStep,
#          }
#        ]
#      end
#
#      def self.step?(step_name)
#        Array(steps).first[step_name].present?
#      end
#
#      delegate :save!, to: :current_step
#      delegate :reset, to: :ect
#
#      def ect
#        @ect ||= ECT.new(store)
#      end
#
#      def appropriate_bodies
#        @appropriate_bodies ||= AppropriateBody.select(:id, :name).all
#      end
#
#      # OPTIMIZE: May eventually depend on the ECT being registered and move to Schools::RegisterECTWizard::ECT
#      def lead_providers
#        @lead_providers ||= LeadProvider.select(:id, :name).all
#      end
#    end
#  end
# end
