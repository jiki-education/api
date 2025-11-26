require "test_helper"

class Utils::R2::UploadTest < ActiveSupport::TestCase
  test "uploads file to R2" do
    r2_key = "development/images/abc123/uuid.jpg"
    body = "test-image-content"
    content_type = "image/jpeg"

    mock_r2_client = mock('r2_client')
    Jiki.expects(:r2_client).returns(mock_r2_client)
    mock_r2_client.expects(:put_object).with(
      bucket: Jiki.config.r2_bucket_assets,
      key: r2_key,
      body: body,
      content_type: content_type
    )

    Utils::R2::Upload.(r2_key, body, content_type)
  end

  test "uses bucket name from Jiki.config" do
    r2_key = "test/file.png"
    body = "content"
    content_type = "image/png"

    mock_r2_client = mock('r2_client')
    Jiki.expects(:r2_client).returns(mock_r2_client)

    # Verify it uses the correct bucket from config
    mock_r2_client.expects(:put_object).with(
      bucket: Jiki.config.r2_bucket_assets,
      key: r2_key,
      body: body,
      content_type: content_type
    )

    Utils::R2::Upload.(r2_key, body, content_type)
  end

  test "memoizes r2_client" do
    r2_key = "test/file.jpg"
    body = "content"
    content_type = "image/jpeg"

    mock_r2_client = mock('r2_client')
    # Jiki.r2_client should only be called once due to memoization
    Jiki.expects(:r2_client).once.returns(mock_r2_client)

    command = Utils::R2::Upload.new(r2_key, body, content_type)
    # Access r2_client twice internally - should only call Jiki.r2_client once
    command.send(:r2_client)
    command.send(:r2_client)
  end
end
