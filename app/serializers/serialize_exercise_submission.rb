class SerializeExerciseSubmission
  include Mandate

  initialize_with :submission

  def call
    {
      uuid: submission.uuid,
      context_type: submission.context_type,
      context_slug: context_slug,
      files: submission.files.map { |file| serialize_file(file) }
    }
  end

  private
  def context_slug
    case submission.context
    when UserLesson
      submission.context.lesson.slug
    when UserProject
      submission.context.project.slug
    else
      raise "Unknown context type: #{submission.context_type}"
    end
  end

  def serialize_file(file)
    {
      filename: file.filename,
      content: file.content.download
    }
  end
end
