module Badges
  class SidekickBadge < Badge
    seed "Sidekick", "Sent your first message to Jiki",
      fun_fact: "Two heads are better than one. Thanks for chatting with Jiki!"

    def award_to?(user)
      user.assistant_conversations.any? do |conversation|
        conversation.messages.any? { |message| message["role"] == "user" }
      end
    end
  end
end
