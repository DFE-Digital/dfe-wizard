module Steps
  class Nationality < DfE::Wizard::Step
    attr_accessor :nationalities, :other_nationalities

    def self.permitted_params
      %w[
        british
        irish
        other_nationalities
      ]
    end
  end
end
