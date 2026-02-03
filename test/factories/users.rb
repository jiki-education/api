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

    trait :with_2fa do
      after(:create) do |user|
        user.data.update!(otp_secret: ROTP::Base32.random, otp_enabled_at: Time.current)
      end
    end
  end
end
