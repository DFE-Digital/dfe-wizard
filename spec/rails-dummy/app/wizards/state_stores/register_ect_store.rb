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

    def prohibited_from_teaching?
      trn == '5555555'
    end

    def cant_use_email?; end

    def school_independent?; end

    def provider_led?; end

    private

    def trn
      read[:trn].to_s
    end
  end
end
