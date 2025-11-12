class Images::Upload
  include Mandate

  initialize_with :image_data, :filename

  MAX_FILE_SIZE = 5.megabytes
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

  def call
    validate_file_size!
    validate_content_type!

    Utils::R2::Upload.(r2_key, image_data, content_type)

    {
      r2_key:,
      url: cdn_url,
      digest:
    }
  end

  private
  def validate_file_size!
    return if image_data.bytesize <= MAX_FILE_SIZE

    raise Jiki::ConfigError, "Image file size exceeds maximum of #{MAX_FILE_SIZE / 1.megabyte}MB"
  end

  def validate_content_type!
    return if ALLOWED_CONTENT_TYPES.include?(content_type)

    raise Jiki::ConfigError, "Invalid image type. Allowed types: #{ALLOWED_CONTENT_TYPES.join(', ')}"
  end

  memoize
  def content_type
    # Try to detect content type from file data
    detected = Marcel::MimeType.for(StringIO.new(image_data), name: filename)

    # Fallback to filename extension if detection fails
    return detected if ALLOWED_CONTENT_TYPES.include?(detected)

    case File.extname(filename).downcase
    when '.jpg', '.jpeg' then 'image/jpeg'
    when '.png' then 'image/png'
    when '.gif' then 'image/gif'
    when '.webp' then 'image/webp'
    else
      'application/octet-stream'
    end
  end

  memoize
  def digest = XXhash.xxh64(image_data).to_s

  memoize
  def extension
    case content_type
    when 'image/jpeg' then 'jpg'
    when 'image/png' then 'png'
    when 'image/gif' then 'gif'
    when 'image/webp' then 'webp'
    else
      File.extname(filename).delete('.')
    end
  end

  memoize
  def r2_key = "#{Jiki.env}/images/#{digest}/#{SecureRandom.uuid}.#{extension}"

  memoize
  def cdn_url = "#{Jiki.config.assets_cdn_url}/#{r2_key}"
end
