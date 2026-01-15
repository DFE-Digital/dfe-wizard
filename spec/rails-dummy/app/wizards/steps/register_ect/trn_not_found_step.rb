module Steps
  module RegisterECT
    class TRNNotFoundStep
      include DfE::Wizard::Step

      def self.permitted_params
        []
      end
    end
  end
end
