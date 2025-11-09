# Provides request-scoped attributes using ActiveSupport::CurrentAttributes
# Automatically resets after each request, ensuring thread-safety
class Current < ActiveSupport::CurrentAttributes
  attribute :events, :refresh_token_id, :user_agent, :jwt_record_id

  # Adds an event to the current request's event collection
  #
  # @param type [Symbol, String] The event type (e.g., :lesson_completed)
  # @param data [Hash] Additional data associated with the event
  #
  # @example
  #   Current.add_event(:lesson_completed, {lesson_slug: 'intro-1'})
  #   Current.add_event(:project_unlocked, {project_slug: 'calculator'})
  def add_event(type, data = {})
    self.events ||= []
    self.events << { type: type.to_s, data: data }
  end
end
