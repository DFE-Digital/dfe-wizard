class ApplicationForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :id, :integer, default: -> { SecureRandom.uuid }
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :date_of_birth, :date
  attribute :nationality, :string
  attribute :other_nationality, :string
  attribute :right_to_work, :string
  attribute :visa_type, :string
  attribute :visa_expiry, :date
  attribute :immigration_status, :string
  attribute :other_status, :string
  attribute :wizard_state, :string, default: '{}'

  validates :first_name, :last_name, :date_of_birth, presence: true

  attribute :highest_qualification, :string
  attribute :institution_name, :string
  attribute :needs_funding, :boolean
  attribute :funding_type, :string
  attribute :amount_requested, :float
  attribute :funding_section_complete, :boolean
  attribute :has_visa, :boolean
  attribute :needs_support, :boolean
  attribute :requires_accessibility, :boolean
  attribute :support_notes, :boolean

  alias nationalities nationality
  alias nationalities= nationality=
  alias other_nationalities= other_nationality=
  alias other_nationalities other_nationality
  alias right_to_work_or_study= right_to_work=
  alias right_to_work_or_study right_to_work

  alias status immigration_status
  alias status= immigration_status=
  alias other_status= immigration_status=
  alias status= immigration_status=

  def update!(attrs)
    assign_attributes(attrs)
    self
  end
end

FactoryBot.define do
  factory :application_form, class: ApplicationForm do
    # Shared attributes
    first_name           { Faker::Name.first_name }
    last_name            { Faker::Name.last_name }
    date_of_birth        { Faker::Date.birthday(min_age: 18, max_age: 65) }

    # Personal Information Wizard defaults
    nationalities        { ['British'] }
    other_nationalities  { [] }
    right_to_work_or_study { 'yes' }
    immigration_status { nil }

    # Get Funding Wizard defaults
    highest_qualification      { 'Bachelor' }
    institution_name           { 'Test University' }
    needs_funding              { false }
    funding_type               { 'scholarship' }
    amount_requested           { nil }
    funding_section_complete   { false }
    has_visa                   { false }
    needs_support              { false }
    requires_accessibility     { false }
    support_notes              { '' }

    ### -- Personal Information Traits ---

    trait :british_national do
      nationalities { ['British'] }
    end

    trait :irish_national do
      nationalities { ['Irish'] }
    end

    trait :non_uk_national do
      nationalities { ['French'] }
    end

    trait :with_right_to_work do
      right_to_work_or_study { 'yes' }
    end

    trait :without_right_to_work do
      right_to_work_or_study { 'no' }
    end

    trait :with_immigration_status do
      immigration_status { 'student_visa' }
    end

    ### -- Get Funding Traits ---

    trait :with_funding_needed do
      needs_funding { true }
      funding_type { 'grant' }
      amount_requested { 8000 }
    end

    trait :with_funding_not_needed do
      needs_funding { false }
      funding_type { nil }
      amount_requested { nil }
    end

    trait :funding_complete do
      funding_section_complete { true }
    end

    trait :funding_incomplete do
      funding_section_complete { false }
    end

    trait :with_visa do
      has_visa { true }
    end

    trait :with_support_needs do
      needs_support { true }
    end

    trait :with_accessibility_requirements do
      requires_accessibility { true }
      support_notes { 'Requires wheelchair access' }
    end
  end
end
