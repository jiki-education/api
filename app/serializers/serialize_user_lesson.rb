class SerializeUserLesson
  include Mandate

  initialize_with :user_lesson

  def call
    {
      lesson_slug: user_lesson.lesson.slug,
      status: status,
      conversation: conversation,
      data: data
    }
  end

  private
  def status
    user_lesson.completed_at.present? ? "completed" : "started"
  end

  def conversation
    assistant_conversation = AssistantConversation.find_by(
      user: user_lesson.user,
      context_type: "lesson",
      context_identifier: user_lesson.lesson.slug
    )

    assistant_conversation&.messages || []
  end

  def data
    case user_lesson.lesson.type
    when "exercise"
      exercise_data
    else
      {}
    end
  end

  def exercise_data
    { last_submission: exercise_data_last_submission }
  end

  def exercise_data_last_submission
    last_submission = user_lesson.exercise_submissions.
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
  end
end
