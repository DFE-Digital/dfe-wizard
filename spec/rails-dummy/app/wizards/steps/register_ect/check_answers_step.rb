module Steps
  module RegisterECT
    class CheckAnswersStep
      include DfE::Wizard::Step

      attribute :confirm, :string

      def self.permitted_params
        %w[confirm]
      end
    end
  end
end
