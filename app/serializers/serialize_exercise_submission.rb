class SerializeExerciseSubmission
  include Mandate

  initialize_with :submission

  def call
    {
      uuid: submission.uuid,
      context_type: context_type,
      context_slug: context_slug,
      files: submission.files.map { |file| serialize_file(file) }
    }
  end

  private
  # Rows written before the rename still store the legacy "UserProject"
  # context_type, so use the class name instead of the raw column.
  # Remove after the backfill migration.
  def context_type = submission.context.class.name

  def context_slug
    case submission.context
    when UserLesson
      submission.context.lesson.slug
    when UserChallenge
      submission.context.challenge.slug
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
