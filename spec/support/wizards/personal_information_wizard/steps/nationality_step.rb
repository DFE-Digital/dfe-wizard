class PersonalInformation::NationalityStep < DfE::Wizard::Step
  attribute :nationalities, default: []
  attribute :other_nationalities, :string

  validates :nationalities, presence: true
  validates :nationalities, length: { minimum: 1 }
  validates :other_nationality, presence: true, if: -> { nationalities.include?(:other) }

  def self.permitted_params
    %i[nationalities other_nationalities]
  end
end
