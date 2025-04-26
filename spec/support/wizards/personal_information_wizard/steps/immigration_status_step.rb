class ImmigrationStatusStep < DfE::Wizard::Step
  attr_accessor :status

  validates :status, presence: true

  def self.permitted_params
    %w[
      status
    ]
  end
end
