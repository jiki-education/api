class User::Avatar::CopyFromUrl
  include Mandate

  queue_as :default

  initialize_with :user, :url

  def call
    # Avatars are best-effort: if the download fails, leave the user without one
    return unless response.success?

    begin
      User::Avatar::Upload.(user, uploaded_file)
    ensure
      tempfile.close!
    end
  end

  private
  CONTENT_TYPE_EXTENSIONS = {
    'image/jpeg' => '.jpg',
    'image/png' => '.png',
    'image/gif' => '.gif',
    'image/webp' => '.webp'
  }.freeze

  memoize
  def uploaded_file
    ActionDispatch::Http::UploadedFile.new(
      tempfile:,
      type: content_type,
      filename: "avatar#{extension}"
    )
  end

  memoize
  def tempfile
    Tempfile.new(['avatar', extension.to_s], binmode: true).tap do |file|
      file.write(response.body)
      file.rewind
    end
  end

  memoize
  def content_type = response.headers['content-type'].to_s.split(';').first

  def extension = CONTENT_TYPE_EXTENSIONS[content_type]

  memoize
  def response = HTTParty.get(url)
end
