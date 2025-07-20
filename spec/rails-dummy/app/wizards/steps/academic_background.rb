module Steps
  class AcademicBackground < DfE::Wizard::Step
    attr_accessor :highest_qualification, :institution_name, :needs_funding

    def self.permitted_params
      %w[
        highest_qualification
        institution_name
        needs_funding
      ]
    end
  end
end
