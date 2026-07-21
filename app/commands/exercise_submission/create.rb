class ExerciseSubmission::Create
  include Mandate

  initialize_with :context, :files

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
        uuid:
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
  def previous_submission
    context.exercise_submissions.includes(:files).order(id: :desc).first
  end

  def duplicate_of_previous?
    return false unless previous_submission
    # A nil code is invalid - let File::Create raise rather than matching
    # a previous empty-string file's digest.
    return false if files.any? { |f| f[:code].nil? }

    previous_submission.files.map { |f| [f.filename, f.digest] }.sort ==
      files.map { |f| [f[:filename].to_s, ExerciseSubmission::File::GenerateDigest.(f[:code])] }.sort
  end

  memoize
  def uuid = SecureRandom.uuid
end
