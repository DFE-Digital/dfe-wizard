FactoryBot.define do
  factory :provider do
    sequence(:name) { |n| "#{Faker::University.name}-#{n}" }
    sequence(:code) { |n| "A#{n}" }
    recruitment_cycle_year { Date.current.year }
  end
end
