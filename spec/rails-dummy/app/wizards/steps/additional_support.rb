module Steps
  class AdditionalSupport
    include DfE::Wizard::Step

    attr_accessor :requires_accessibility, :support_notes

    def self.permitted_params
      %w[
        requires_accessibility
        support_notes
      ]
    end
  end
end
