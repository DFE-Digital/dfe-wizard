module Steps
  module RegisterECT
    class WorkingPatternStep
      include DfE::Wizard::Step

      attribute :working_pattern, :string

      validates :working_pattern, presence: true

      def self.permitted_params
        %w[working_pattern]
      end
    end
  end
end
