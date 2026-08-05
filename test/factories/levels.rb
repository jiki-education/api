FactoryBot.define do
  factory :level do
    course
    slug { "level-#{SecureRandom.hex(4)}" }
    milestone_email_subject { "Congratulations on completing #{slug}!" }
    milestone_email_content_markdown { "You've finished all lessons in **#{slug}**. Great work!" }
    milestone_email_image_url { "https://cdn.jiki.io/emails/level-complete.jpg" }

    trait :with_translations do
      after(:create) do |level|
        create(:level_translation, :hungarian, level:)
      end
    end

    trait :with_all_translations do
      after(:create) do |level|
        create(:level_translation, :hungarian, level:)
        create(:level_translation, :spanish, level:)
      end
    end
  end
end
