module Steps
  module RegisterECT
    class ReviewECTDetailsStep
      include DfE::Wizard::Step

      attribute :details_correct, :string
      attribute :correct_full_name, :string

      validates :details_correct, presence: true
      validates :correct_full_name, presence: true, if: -> { details_correct == 'no' }

      def self.permitted_params
        %w[details_correct correct_full_name]
      end
    end
  end
end
