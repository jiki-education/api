FactoryBot.define do
  factory :level do
    slug { "level-#{SecureRandom.hex(4)}" }
    title { "Level #{slug}" }
    description { "Description for #{title}" }
    milestone_summary { "You completed this level! Great work on finishing all lessons." }
    milestone_content { "# Congratulations!\n\nYou've finished all lessons in this level." }

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
