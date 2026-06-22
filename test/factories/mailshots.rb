FactoryBot.define do
  factory :mailshot do
    sequence(:slug) { |n| "mailshot-#{n}" }
    subject { "What's new at Jiki" }
    body_markdown { "## Hello\n\nHere's the latest news." }
    email_communication_preferences_key { "newsletters" }

    trait :sent do
      sent_to_audiences { ["all_users"] }
    end
  end
end
