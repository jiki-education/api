FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    password { "password123" }
    password_confirmation { password }
    name { Faker::Name.name }
    handle { Faker::Internet.unique.username(specifier: 5..15, separators: %w[_]) }
    locale { "en" }
    confirmed_at { Time.current }

    trait :hungarian do
      locale { "hu" }
    end

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :admin do
      admin { true }
    end
  end
end
