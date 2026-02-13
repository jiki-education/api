FactoryBot.define do
  factory :level do
    course
    slug { "level-#{SecureRandom.hex(4)}" }
    title { "Level #{slug}" }
    description { "Description for #{title}" }
    milestone_summary { "You completed this level! Great work on finishing all lessons." }
    milestone_content { "# Congratulations!\n\nYou've finished all lessons in this level." }
    milestone_email_subject { "Congratulations on completing #{title}!" }
    milestone_email_content_markdown { "You've finished all lessons in **#{title}**. Great work!" }
    milestone_email_image_url { "https://cdn.jiki.io/emails/level-complete.jpg" }

    trait :with_translations do
      after(:create) do |level|
        create(:level_translation, :hungarian, level:)
      end
    end

    trait :with_all_translations do
      after(:create) do |level|
        create(:level_translation, :hungarian, level:)
        create(:level_translation, :french, level:)
      end
    end
  end
end
