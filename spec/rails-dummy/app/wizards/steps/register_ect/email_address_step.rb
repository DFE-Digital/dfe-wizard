module Steps
  module RegisterECT
    class EmailAddressStep
      include DfE::Wizard::Step

      attribute :email, :string

      validates :email, presence: true

      def self.permitted_params
        %w[email]
      end
    end
  end
end
