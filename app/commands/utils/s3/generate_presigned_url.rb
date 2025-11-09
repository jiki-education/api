class Utils::S3::GeneratePresignedUrl
  include Mandate

  initialize_with :s3_key, :bucket, expires_in: 1.hour

  BUCKETS = {
    video_production: Jiki.config.s3_bucket_video_production
  }.freeze

  def call
    s3_object.presigned_url(:get, expires_in: expires_in)
  end

  private
  memoize
  def s3_client = Jiki.s3_client

  memoize
  def bucket_name = BUCKETS.fetch(bucket)

  memoize
  def s3_object
    Aws::S3::Object.new(
      bucket_name: bucket_name,
      key: s3_key,
      client: s3_client
    )
  end
end
