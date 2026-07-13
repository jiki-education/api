class ExerciseSubmission::Create
  include Mandate

  initialize_with :context, :files, progression_scores: nil

  def call
    validate_files_present!
    validate_file_count!
    validate_unique_filenames!

    # Identical re-runs are common (the frontend submits on every test run),
    # so silently return the previous submission rather than storing a copy.
    return previous_submission if duplicate_of_previous?

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
  MAX_FILES = 20

  def validate_files_present!
    raise InvalidSubmissionError, :no_files if files.empty?
  end

  def validate_file_count!
    raise TooManyFilesError.new(files.length, MAX_FILES) if files.length > MAX_FILES
  end

  def validate_unique_filenames!
    filenames = files.map { |f| f[:filename] }
    duplicates = filenames.select { |fn| filenames.count(fn) > 1 }.uniq

    raise DuplicateFilenameError, duplicates if duplicates.any?
  end

  memoize
  def previous_submission
    context.exercise_submissions.order(id: :desc).first
  end

  def duplicate_of_previous?
    return false unless previous_submission

    # A nil code is invalid - let File::Create raise rather than matching
    # a previous empty-string file's digest.
    return false if files.any? { |f| f[:code].nil? }

    previous_submission.files.pluck(:filename, :digest).sort ==
      files.map { |f| [f[:filename].to_s, ExerciseSubmission::File::GenerateDigest.(f[:code])] }.sort
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
