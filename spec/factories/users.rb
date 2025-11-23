FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    date_of_birth { Faker::Date.birthday(min_age: 18, max_age: 65) }
    phone { Faker::PhoneNumber.phone_number }
    bio { Faker::Lorem.paragraph }
    password_digest { Faker::Crypto.sha256 }
    api_token { Faker::Alphanumeric.alphanumeric(number: 32) }
    secret_key { Faker::Alphanumeric.alphanumeric(number: 64) }
  end
end
