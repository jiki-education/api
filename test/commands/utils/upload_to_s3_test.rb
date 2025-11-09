require "test_helper"

class Utils::S3::UploadTest < ActiveSupport::TestCase
  test "uploads file to S3 and returns s3_key" do
    s3_key = "test/path/file.mp3"
    body = "test-file-content"
    content_type = "audio/mpeg"

    mock_s3_client = mock('s3_client')
    Jiki.expects(:s3_client).returns(mock_s3_client)
    mock_s3_client.expects(:put_object).with(
      bucket: Jiki.config.s3_bucket_video_production,
      key: s3_key,
      body: body,
      content_type: content_type
    )

    result = Utils::S3::Upload.(s3_key, body, content_type, :video_production)

    assert_equal s3_key, result
  end

  test "uses bucket name from BUCKETS constant" do
    s3_key = "test/file.mp3"
    body = "content"
    content_type = "audio/mpeg"

    mock_s3_client = mock('s3_client')
    Jiki.expects(:s3_client).returns(mock_s3_client)

    # Verify it looks up the bucket from Jiki.config
    mock_s3_client.expects(:put_object).with(
      bucket: Jiki.config.s3_bucket_video_production,
      key: s3_key,
      body: body,
      content_type: content_type
    )

    Utils::S3::Upload.(s3_key, body, content_type, :video_production)
  end

  test "raises error for unknown bucket" do
    error = assert_raises(KeyError) do
      Utils::S3::Upload.("key", "body", "type", :unknown_bucket)
    end

    assert_match(/unknown_bucket/, error.message)
  end

  test "memoizes s3_client" do
    s3_key = "test/file.mp3"
    body = "content"
    content_type = "audio/mpeg"

    mock_s3_client = mock('s3_client')
    # Jiki.s3_client should only be called once due to memoization
    Jiki.expects(:s3_client).once.returns(mock_s3_client)

    command = Utils::S3::Upload.new(s3_key, body, content_type, :video_production)
    # Access s3_client twice internally - should only call Jiki.s3_client once
    command.send(:s3_client)
    command.send(:s3_client)
  end
end
