class AssistantConversation < ApplicationRecord
  belongs_to :user
  belongs_to :context, polymorphic: true

  # Transitional: challenge rows are written with the legacy "Project"
  # context_type (see Challenge.polymorphic_name) and will be written as
  # "Challenge" once that override is removed, so reads must accept both
  # until the backfill migration has run. Remove after the backfill.
  scope :for_context, lambda { |context|
    types = context.is_a?(Challenge) ? %w[Project Challenge] : [context.class.polymorphic_name]
    where(context_type: types, context_id: context.id)
  }
end
