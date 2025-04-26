class ApplicationForm
  include ActiveModel::Model

  attr_accessor :first_name,
                :last_name,
                :date_of_birth,
                :nationalities,
                :other_nationalities,
                :right_to_work_or_study,
                :immigration_status
end

FactoryBot.define do
  factory :application_form, class: ApplicationForm do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    date_of_birth { Faker::Date.birthday(min_age: 18, max_age: 65) }
    nationalities { ['British'] }
    other_nationalities { [] }
    right_to_work_or_study { 'yes' }
    immigration_status { nil }

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
  end
end
