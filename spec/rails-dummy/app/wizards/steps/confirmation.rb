module Steps
  class Confirmation
    include DfE::Wizard::Step

    def self.permitted_params
      []
    end

    def mentor_name
      'Alice Mentor'
    end

    def ect_name
      'Peter Davison'
    end
  end
end
