module Steps
  class VisaRequirement < DfE::Wizard::Step
    attr_accessor :has_visa, :needs_support

    def self.permitted_params
      %w[
        has_visa
        needs_support
      ]
    end
  end
end
