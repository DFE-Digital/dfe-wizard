module StateStores
  class RegisterECTStore
    include DfE::Wizard::StateStore

    def in_trs?
      trn != '0000000'
    end

    def matches_trs_dob?
      trn != '1111111'
    end

    def active_at_school?
      trn == '2222222'
    end

    def induction_completed?
      trn == '3333333'
    end

    def induction_exempt?
      trn == '4444444'
    end

    def induction_failed?
      trn == '6666666'
    end

    def prohibited_from_teaching?
      trn == '5555555'
    end

    def cant_use_email?
      email_taken = read[:cant_use_email]
      email_value = read[:email].to_s.downcase

      email_taken.present? || email_value == 'taken@example.com'
    end

    def school_independent?
      read[:school_type] == 'independent'
    end

    def provider_led?
      read[:training_programme] == 'provider_led'
    end

    def appropriate_body_text
      appropriate_body_name = if appropriate_body_type == 'national'
                                'Independent Schools Teacher Induction Panel (ISTIP)'
                              elsif appropriate_body_type.present?
                                read[:independent_appropriate_body_name]
                              else
                                read[:appropriate_body_name]
                              end

      appropriate_body_name.presence || 'Not provided'
    end

    # Custom branching: determines next step after find_ect
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

    # Custom branching: determines next step after national_insurance_number
    def national_insurance_number_transitions
      return :not_found unless in_trs?
      return :induction_completed if induction_completed?
      return :induction_exempt if induction_exempt?

      :review_ect_details
    end

    private

    def trn
      read[:trn].to_s
    end
  end
end
