# Wraps JSON responses with metadata including events
#
# Automatically adds a meta key with events to all JSON responses.
# Events are collected during request processing via Current.add_event
# and included in the response metadata.
#
# @example Without events
#   render json: {lesson: {...}}
#   # Response: {lesson: {...}, meta: {events: []}}
#
# @example With events
#   Current.add_event(:lesson_completed, {lesson_slug: 'intro-1'})
#   render json: {lesson: {...}}
#   # Response: {lesson: {...}, meta: {events: [{type: "lesson_completed", data: {...}}]}}
#
# @example With existing meta
#   render json: {results: [...], meta: {current_page: 1}}
#   # Response: {results: [...], meta: {current_page: 1, events: []}}
module MetaResponseWrapper
  extend ActiveSupport::Concern

  def render(*args, **options)
    # Skip wrapping for admin controllers
    return super(*args, **options) if skip_meta_wrapper?

    # Only process JSON hash responses
    if options[:json].is_a?(Hash)
      json_data = options[:json]
      events = Current.events || []

      # Merge events into existing meta or create new meta key
      json_data[:meta] = (json_data[:meta] || {}).merge(events: events)

      options[:json] = json_data
    end

    super(*args, **options)
  end

  private
  def skip_meta_wrapper?
    is_a?(Admin::BaseController)
  end
end
