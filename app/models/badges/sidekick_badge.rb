module Badges
  class SidekickBadge < Badge
    def award_to?(user)
      user.assistant_conversations.any? do |conversation|
        conversation.messages.any? { |message| message["role"] == "user" }
      end
    end
  end
end
