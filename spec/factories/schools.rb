FactoryBot.define do
  factory :school do
    sequence(:name) { |n| "#{Faker::University.name}-#{n}" }
    provider
  end
end
