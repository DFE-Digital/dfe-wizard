module Steps
  class PersonalDetails
    include DfE::Wizard::Step

    attr_accessor :first_name, :last_name, :date_of_birth

    def self.permitted_params
      %w[
        first_name
        last_name
        date_of_birth
      ]
    end
  end
end
