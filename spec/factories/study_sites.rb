FactoryBot.define do
  factory :study_site do
    sequence(:name) { |n| "#{Faker::University.name}-#{n}" }
    provider
  end
end
