class ExerciseSubmission::Create
  include Mandate

  initialize_with :context, :files, progression_scores: nil

  def call
    validate_files_present!
    validate_file_count!
    validate_unique_filenames!

    ActiveRecord::Base.transaction do
      ExerciseSubmission.create!(
        context:,
        uuid:,
        progression_scores: sanitized_progression_scores
      ).tap do |submission|
        files.each do |file_params|
          ExerciseSubmission::File::Create.(
            submission,
            file_params[:filename],
            file_params[:code]
          )
        end

        User::ActivityLog::LogActivity.(context.user, Date.current)
      end
    end
  end

  private
  def validate_files_present!
    raise InvalidSubmissionError, "Submission must include at least one file" if files.empty?
  end

  def validate_file_count!
    raise TooManyFilesError, "Too many files (maximum 20)" if files.length > 20
  end

  def validate_unique_filenames!
    filenames = files.map { |f| f[:filename] }
    duplicates = filenames.select { |fn| filenames.count(fn) > 1 }.uniq

    raise DuplicateFilenameError, "Duplicate filenames: #{duplicates.join(', ')}" if duplicates.any?
  end

  memoize
  def uuid = SecureRandom.uuid

  # Analytics data from the frontend "stuckometer". Must never block a
  # submission, so anything that isn't a JSON object of integer values is
  # silently normalized to nil rather than raising.
  memoize
  def sanitized_progression_scores
    scores = progression_scores
    scores = scores.to_unsafe_h if scores.respond_to?(:to_unsafe_h)
    return nil unless scores.is_a?(Hash)

    scores = scores.to_h
    return nil if scores.empty?
    return nil unless scores.values.all?(Integer)

    scores
  end
end
