module Steps
  module RegisterECT
    class NotFoundStep
      include DfE::Wizard::Step

      def self.permitted_params
        []
      end
    end
  end
end
