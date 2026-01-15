module Steps
  module RegisterECT
    class ProgrammeTypeStep
      include DfE::Wizard::Step

      attribute :training_programme, :string

      validates :training_programme, presence: true

      def self.permitted_params
        %w[training_programme]
      end
    end
  end
end
