class ExerciseSubmission::Create
  include Mandate

  initialize_with :context, :files

  def call
    validate_files_present!
    validate_file_count!
    validate_unique_filenames!

    ActiveRecord::Base.transaction do
      ExerciseSubmission.create!(
        context:,
        uuid:
      ).tap do |s|
        files.each do |file_params|
          ExerciseSubmission::File::Create.(
            s,
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
end
