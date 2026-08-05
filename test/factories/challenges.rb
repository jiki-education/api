FactoryBot.define do
  factory :challenge do
    # Zero-padded: challenges are ordered by slug, and an unpadded sequence
    # would sort challenge-10 before challenge-9.
    sequence(:slug) { |n| "challenge-#{n.to_s.rjust(4, '0')}" }
    exercise_slug { slug }

    trait :with_unlocking_lesson do
      association :unlocked_by_lesson, factory: :lesson
    end
  end
end
