class SerializeUserChallenge
  include Mandate

  initialize_with :user_challenge

  def call
    {
      challenge_slug: user_challenge.challenge.slug,
      status: status,
      conversation: conversation,
      conversation_allowed: conversation_allowed,
      data: data
    }
  end

  private
  def status
    user_challenge.completed_at.present? ? "completed" : "started"
  end

  def conversation = user_challenge.assistant_conversation&.messages || []

  def conversation_allowed
    AssistantConversation::CheckUserAccess.(user_challenge.user, user_challenge.challenge)
  end

  def data
    { last_submission: exercise_data_last_submission }
  end

  def exercise_data_last_submission
    last_submission = user_challenge.exercise_submissions.
      includes(files: { content_attachment: :blob }).
      order(created_at: :desc).
      first

    return nil unless last_submission

    {
      uuid: last_submission.uuid,
      files: last_submission.files.map do |file|
        {
          filename: file.filename,
          content: file.content.download
        }
      end
    }
  rescue ActiveStorage::FileNotFoundError => e
    Sentry.capture_exception(e, extra: { exercise_submission_id: last_submission&.id })
    nil
  end
end
