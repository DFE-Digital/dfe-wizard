module Steps
  module RegisterECT
    class ConfirmationStep
      include DfE::Wizard::Step

      def self.permitted_params
        []
      end
    end
  end
end
