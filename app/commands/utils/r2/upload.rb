class Utils::R2::Upload
  include Mandate

  initialize_with :r2_key, :body, :content_type

  def call
    r2_client.put_object(
      bucket: bucket_name,
      key: r2_key,
      body:,
      content_type:
    )

    r2_key
  end

  private
  memoize
  def r2_client = Jiki.r2_client

  memoize
  def bucket_name = Jiki.config.r2_bucket_assets
end
