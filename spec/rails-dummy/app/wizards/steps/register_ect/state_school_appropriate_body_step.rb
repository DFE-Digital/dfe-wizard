module Steps
  module RegisterECT
    class StateSchoolAppropriateBodyStep
      include DfE::Wizard::Step

      attribute :appropriate_body_name, :string
      validates :appropriate_body_name,
                presence: {
                  message: "Enter the name of the appropriate body which will be supporting the ECT's induction",
                }

      def self.permitted_params
        %w[appropriate_body_name]
      end
    end
  end
end
