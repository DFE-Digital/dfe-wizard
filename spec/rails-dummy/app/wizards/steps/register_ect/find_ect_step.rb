module Steps
  module RegisterECT
    class FindECTStep
      include DfE::Wizard::Step

      attribute :trn, :string

      validates :trn, presence: true

      def self.permitted_params
        %w[trn]
      end
    end
  end
end
