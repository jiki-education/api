class AssistantConversation < ApplicationRecord
  belongs_to :user
  belongs_to :context, polymorphic: true
end
