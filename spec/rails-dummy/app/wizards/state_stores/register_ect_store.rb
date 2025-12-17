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

    private

    def trn
      read[:trn].to_s
    end
  end
end
