class User::Avatar::Upload
  include Mandate

  initialize_with :user, :file

  MAX_FILE_SIZE = 5.megabytes
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

  def call
    validate_file!

    ActiveRecord::Base.transaction do
      user.avatar.purge if user.avatar.attached?

      key = storage_key
      user.avatar.attach(
        io: file_io,
        filename: "avatar#{extension}",
        content_type: file.content_type,
        key: key
      )
      user.update!(avatar_url: "#{Jiki.config.uploads_host}/#{key}")
    end
  end

  private
  def validate_file!
    raise InvalidAvatarError, "No file provided" unless file.present?
    raise InvalidAvatarError, "Invalid file type" unless valid_content_type?
    raise AvatarTooLargeError, "File exceeds 5MB limit" if file.size > MAX_FILE_SIZE
  end

  def valid_content_type?
    file.content_type.in?(ALLOWED_CONTENT_TYPES)
  end

  def file_io
    file.respond_to?(:tempfile) ? file.tempfile : file
  end

  def extension
    ext = File.extname(file.original_filename).delete_prefix(".").presence
    ext ? ".#{ext}" : nil
  end

  # Key format: xx/yy/zzz/rest-of-uuid.ext
  def storage_key
    uuid = SecureRandom.uuid
    "#{uuid[0, 2]}/#{uuid[2, 2]}/#{uuid[4, 3]}/#{uuid[7..]}#{extension}"
  end
end
