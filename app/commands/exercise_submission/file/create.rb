class ExerciseSubmission::File::Create
  include Mandate

  initialize_with :exercise_submission, :filename, :content

  MAX_FILE_SIZE = 100_000 # 100KB

  def call
    validate_required_fields!
    validate_file_size!

    exercise_submission.files.create!(
      filename:,
      digest:
    ).tap do |file|
      file.content.attach(
        io: StringIO.new(sanitized_content),
        filename:,
        content_type: 'text/plain'
      )
    end
  end

  private
  def validate_required_fields!
    raise InvalidSubmissionError, "filename is required" if filename.blank?
    raise InvalidSubmissionError, "code is required" if content.nil?
  end

  def validate_file_size!
    return if content.bytesize <= MAX_FILE_SIZE

    raise FileTooLargeError, "File '#{filename}' is too large (maximum #{MAX_FILE_SIZE} bytes)"
  end

  memoize
  def sanitized_content
    # Convert to UTF-8 encoding, replacing invalid characters
    # This prevents encoding errors when storing/retrieving content
    content.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
  end

  memoize
  def digest = ExerciseSubmission::File::GenerateDigest.(content)
end
