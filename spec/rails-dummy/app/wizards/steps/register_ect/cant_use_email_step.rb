module Steps
  module RegisterECT
    class CantUseEmailStep
      include DfE::Wizard::Step

      def self.permitted_params
        []
      end
    end
  end
end
