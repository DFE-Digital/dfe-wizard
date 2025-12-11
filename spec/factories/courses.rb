FactoryBot.define do
  factory :course do
    sequence(:course_code) { |n| "C#{n.to_s.rjust(3, '0')}" }
    sequence(:provider_code) { |n| "P#{n.to_s.rjust(3, '0')}" }
    recruitment_cycle_year { 2024 }

    a_level_subject_requirements { [] }
    accept_pending_a_level { nil }
    accept_a_level_equivalency { nil }
    additional_a_level_equivalencies { nil }

    trait :with_a_level_requirements do
      a_level_subject_requirements {
        [{ uuid: SecureRandom.uuid, subject: 'any_subject', minimum_grade_required: 'A' }]
      }
      accept_pending_a_level { true }
      accept_a_level_equivalency { true }
      additional_a_level_equivalencies { 'Some text' }
    end

    trait :with_equivalencies do
      accept_a_level_equivalency { true }
      additional_a_level_equivalencies { 'IB Diploma accepted at 32 points' }
    end

    trait :with_other_subject do
      a_level_subject_requirements do
        [
          {
            uuid: SecureRandom.uuid,
            subject: 'other_subject',
            other_subject: 'Computer Science',
            minimum_grade_required: 'A',
          },
        ]
      end
    end
  end
end
