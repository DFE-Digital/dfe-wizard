class RegisterECTWizard
  include DfE::Wizard

  delegate :in_trs?,
           :matches_trs_dob?,
           :active_at_school?,
           :induction_exempt?,
           :induction_failed?,
           :prohibited_from_teaching?,
           :induction_completed?,
           :cant_use_email?,
           :school_independent?,
           :provider_led?,
           to: :state_store

  def steps_processor
    DfE::Wizard::StepsProcessor::Graph.draw(self) do |graph|
      graph.add_node :cannot_register_ect, Steps::RegisterECT::CannotRegisterECTStep
      graph.add_node :cant_use_email, Steps::RegisterECT::CantUseEmailStep
      graph.add_node :check_answers, Steps::RegisterECT::CheckAnswersStep
      graph.add_node :confirmation, Steps::RegisterECT::ConfirmationStep
      graph.add_node :email_address, Steps::RegisterECT::EmailAddressStep
      graph.add_node :find_ect, Steps::RegisterECT::FindECTStep
      graph.add_node :trn_not_found, Steps::RegisterECT::TRNNotFoundStep
      graph.add_node :already_active_at_school, Steps::RegisterECT::AlreadyActiveAtSchoolStep
      graph.add_node :independent_school_appropriate_body, Steps::RegisterECT::IndependentSchoolAppropriateBodyStep
      graph.add_node :induction_completed, Steps::RegisterECT::InductionCompletedStep
      graph.add_node :induction_exempt,  Steps::RegisterECT::InductionExemptStep
      graph.add_node :induction_failed,  Steps::RegisterECT::InductionFailedStep
      graph.add_node :lead_provider, Steps::RegisterECT::LeadProviderStep
      graph.add_node :national_insurance_number, Steps::RegisterECT::NationalInsuranceNumberStep
      graph.add_node :not_found, Steps::RegisterECT::NotFoundStep
      graph.add_node :programme_type, Steps::RegisterECT::ProgrammeTypeStep
      graph.add_node :review_ect_details, Steps::RegisterECT::ReviewECTDetailsStep
      graph.add_node :start_date, Steps::RegisterECT::StartDateStep
      graph.add_node :state_school_appropriate_body, Steps::RegisterECT::StateSchoolAppropriateBodyStep
      graph.add_node :working_pattern, Steps::RegisterECT::WorkingPatternStep

      graph.root :find_ect

      graph.add_custom_branching_edge(
        from: :find_ect,
        conditional: :find_ect_transitions,
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

      graph.add_custom_branching_edge(
        from: :national_insurance_number,
        conditional: :national_insurance_number_transitions,
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
      )

      graph.add_edge from: :start_date, to: :working_pattern

      graph.add_conditional_edge(
        from: :working_pattern,
        when: :school_independent?,
        then: :independent_school_appropriate_body,
        else: :state_school_appropriate_body,
      )

      graph.add_edge from: :independent_school_appropriate_body, to: :programme_type
      graph.add_edge from: :state_school_appropriate_body, to: :programme_type

      graph.add_conditional_edge(
        from: :programme_type,
        when: :provider_led?,
        then: :lead_provider,
        else: :check_answers,
      )

      graph.add_edge from: :lead_provider, to: :check_answers
      graph.add_edge from: :check_answers, to: :confirmation

      graph.before_next_step(:next_step_override)
      graph.before_previous_step(:previous_step_override)
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

  def next_step_override
    target = @current_step_params[:return_to_review]

    :check_answers if target.present? && valid_path_to?(:check_answers)
  end

  def previous_step_override
    target = @current_step_params[:return_to_review]&.to_sym

    :check_answers if current_step_name == target && valid_path_to?(:check_answers)
  end

  def find_ect_transitions
    return :trn_not_found unless in_trs?
    return :national_insurance_number unless matches_trs_dob?
    return :already_active_at_school if active_at_school?
    return :induction_completed if induction_completed?
    return :induction_exempt if induction_exempt?
    return :induction_failed if induction_failed?
    return :cannot_register_ect if prohibited_from_teaching?

    :review_ect_details
  end

  def national_insurance_number_transitions
    return :not_found unless in_trs?
    return :induction_completed if induction_completed?
    return :induction_exempt if induction_exempt?

    :review_ect_details
  end
end
