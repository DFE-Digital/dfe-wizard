class NameAndDateOfBirthStep < DfE::Wizard::Step
  attr_accessor :first_name, :last_name, :date_of_birth

  validates :first_name, :last_name, :date_of_birth, presence: true

  def self.permitted_params
    %w[
      first_name
      last_name
      date_of_birth
    ]
  end
end
