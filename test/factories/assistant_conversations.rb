FactoryBot.define do
  factory :assistant_conversation do
    user
    association :context, factory: %i[lesson exercise]
    messages { [] }

    trait :with_messages do
      messages do
        [
          {
            role: "user",
            content: "How do I solve this problem?",
            timestamp: "2025-10-31T08:15:30.000Z"
          },
          {
            role: "assistant",
            content: "Let me help you break it down step by step.",
            timestamp: "2025-10-31T08:15:35.000Z"
          }
        ]
      end
    end
  end
end
