class Utils::S3::Upload
  include Mandate

  initialize_with :s3_key, :body, :content_type, :bucket

  BUCKETS = {
    video_production: Jiki.config.s3_bucket_video_production
  }.freeze

  def call
    s3_client.put_object(
      bucket: bucket_name,
      key: s3_key,
      body: body,
      content_type: content_type
    )

    s3_key
  end

  private
  memoize
  def s3_client = Jiki.s3_client

  memoize
  def bucket_name = BUCKETS.fetch(bucket)
end
