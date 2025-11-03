class AssistantConversation < ApplicationRecord
  belongs_to :user

  validates :context_type, presence: true
  validates :context_identifier, presence: true
end
