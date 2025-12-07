module StateStores
  class AddCourse
    include DfE::Wizard::StateStore

    attr_reader :provider

    def initialize(repository:, provider:, attribute_names: [], step_definitions: [])
      @provider = provider

      super(repository:, attribute_names:, step_definitions:)
    end

    def further_education?
      level == 'Further education'
    end

    def uni_or_scitt?
      provider.accredited?
    end

    def school_direct?
      !(uni_or_scitt? || further_education?)
    end

    def design_technology?; end

    def modern_languages?; end

    def physics?; end

    def further_education_and_skip_applications_open?
      further_education? && !FeatureFlag.active?(:applications_open)
    end

    def fee_based?
      funding_type == 'fee'
    end

    # fixme
    def read
      repository.read.with_indifferent_access
    end
  end
end
