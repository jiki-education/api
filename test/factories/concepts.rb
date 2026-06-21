FactoryBot.define do
  factory :concept do
    sequence(:title) { |n| "Concept #{n}" }
    sequence(:description) { |n| "A brief description of Concept #{n}" }
  end
end
