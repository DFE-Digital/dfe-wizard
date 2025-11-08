module StateStores
  class RegisterECTStore < DfE::Wizard::StateStore::Session
    def in_trs?; end

    def matches_trs_dob?; end

    def active_at_school?; end

    def induction_exempt?; end

    def prohibited_from_teaching?; end

    def induction_completed?; end

    def cant_use_email?; end

    def school_independent?; end

    def provider_led?; end
  end
end
