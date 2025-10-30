class ApplicationForm
  include ActiveModel::Model

  # Shared
  attr_accessor :first_name,
                :last_name,
                :date_of_birth

  # Personal Information wizard
  attr_accessor :nationalities,
                :other_nationalities,
                :right_to_work_or_study,
                :immigration_status

  # Get Funding Wizard
  attr_accessor :highest_qualification,
                :institution_name,
                :needs_funding,
                :funding_type,
                :amount_requested,
                :funding_section_complete,
                :has_visa,
                :needs_support,
                :requires_accessibility,
                :support_notes
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
