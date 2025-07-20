module Steps
  class AdditionalSupport < DfE::Wizard::Step
    attr_accessor :requires_accessibility, :support_notes

    def self.permitted_params
      %w[
        requires_accessibility
        support_notes
      ]
    end
  end
end
