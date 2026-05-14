class SerializeUserProject
  include Mandate

  initialize_with :user_project

  def call
    {
      project_slug: user_project.project.slug,
      status: status,
      conversation: conversation,
      conversation_allowed: conversation_allowed,
      data: data
    }
  end

  private
  def status
    user_project.completed_at.present? ? "completed" : "started"
  end

  def conversation = user_project.assistant_conversation&.messages || []

  def conversation_allowed
    AssistantConversation::CheckUserAccess.(user_project.user, user_project.project)
  end

  def data
    { last_submission: exercise_data_last_submission }
  end

  def exercise_data_last_submission
    last_submission = user_project.exercise_submissions.
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
