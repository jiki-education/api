class AssistantConversation < ApplicationRecord
  belongs_to :user
  belongs_to :context, polymorphic: true

  # Transitional: challenge rows written before the rename still have the
  # legacy "Project" context_type, so reads must accept both names until
  # the backfill migration has run. Remove after the backfill.
  scope :for_context, lambda { |context|
    types = context.is_a?(Challenge) ? %w[Project Challenge] : [context.class.polymorphic_name]
    where(context_type: types, context_id: context.id)
  }
end
