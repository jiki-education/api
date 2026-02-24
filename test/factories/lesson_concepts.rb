FactoryBot.define do
  factory :lesson_concept do
    association :lesson, factory: %i[lesson exercise]
    concept
  end
end
