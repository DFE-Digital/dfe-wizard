module StateStores
  class AddCourse
    include DfE::Wizard::StateStore

    attr_reader :provider

    delegate :recruitment_cycle_year, to: :provider

    delegate :code, to: :provider, prefix: true

    def initialize(repository:, provider:, attribute_names: [], step_definitions: [])
      @provider = provider

      super(repository:, attribute_names:, step_definitions:)
    end

    def state_key
      @repository.model.state_key
    end

    def further_education?
      level == 'Further education'
    end

    def primary?
      level == 'primary'
    end

    def uni_or_scitt?
      provider.accredited?
    end

    def school_direct?
      !(uni_or_scitt? || further_education?)
    end

    def design_technology?
      main_subject == 'Design and technology'
    end

    def modern_languages?
      main_subject == 'Modern languages'
    end

    def physics?
      main_subject == 'Physics'
    end

    def applications_open_feature_flag_inactive?
      !FeatureFlag.active?(:applications_open)
    end

    def fee_based?
      funding_type == 'fee'
    end

    def single_accredited_provider_or_self_accredited?
      single_accredited_provider? || self_accredited?
    end

    def single_accredited_provider?
      provider.accredited_partners.size == 1
    end

    def self_accredited?
      uni_or_scitt?
    end

    def teacher_degree_apprenticeship?
      qualification == 'undergraduate_degree_with_qts'
    end

    def no_visa_sponsorship?
      !can_sponsor_visa?
    end

    def can_sponsor_visa?
      (fee_based? && can_sponsor_student_visa?) || ((salary? || apprenticeship?) && can_sponsor_skilled_worker_visa?)
    end

    def can_sponsor_student_visa?
      can_sponsor_student_visa.present?
    end

    def can_sponsor_skilled_worker_visa?
      can_sponsor_skilled_worker_visa.present?
    end

    def salary?
      funding_type == 'salary'
    end

    def apprenticeship?
      funding_type == 'apprenticeship'
    end

    def visa_deadline_required?
      visa_deadline_required.present?
    end

    # fixme
    def read
      repository.read.with_indifferent_access
    end
  end
end
