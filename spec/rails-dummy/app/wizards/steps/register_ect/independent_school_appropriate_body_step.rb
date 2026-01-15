module Steps
  module RegisterECT
    class IndependentSchoolAppropriateBodyStep
      include DfE::Wizard::Step

      attribute :appropriate_body_type, :string
      attribute :independent_appropriate_body_name, :string

      validates :appropriate_body_type, presence: true
      validates :independent_appropriate_body_name, presence: true, if: lambda {
        appropriate_body_type == 'teaching_school_hub'
      }

      def self.permitted_params
        %w[appropriate_body_type independent_appropriate_body_name]
      end
    end
  end
end
