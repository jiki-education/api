require "test_helper"

class User::Avatar::CopyFromUrlTest < ActiveSupport::TestCase
  test "downloads image and uploads it as the user's avatar" do
    user = create(:user)
    url = "https://exercism.org/avatars/1530/0"
    image_data = "fake-image-bytes"

    stub_request(:get, url).to_return(
      status: 200,
      body: image_data,
      headers: { 'Content-Type' => 'image/jpeg' }
    )

    User::Avatar::Upload.expects(:call).with do |upload_user, file|
      upload_user == user &&
        file.content_type == 'image/jpeg' &&
        file.original_filename == 'avatar.jpg' &&
        file.read == image_data
    end

    User::Avatar::CopyFromUrl.(user, url)
  end

  test "uses extension matching the content type" do
    user = create(:user)
    url = "https://exercism.org/avatars/1530/0"

    stub_request(:get, url).to_return(
      status: 200,
      body: "fake-png-bytes",
      headers: { 'Content-Type' => 'image/png' }
    )

    User::Avatar::Upload.expects(:call).with do |_upload_user, file|
      file.original_filename == 'avatar.png'
    end

    User::Avatar::CopyFromUrl.(user, url)
  end

  test "no-ops when download fails" do
    user = create(:user)
    url = "https://exercism.org/avatars/missing/0"

    stub_request(:get, url).to_return(status: 404, body: "Not found")

    User::Avatar::Upload.expects(:call).never

    User::Avatar::CopyFromUrl.(user, url)
  end

  test "no-ops when upload rejects the file" do
    user = create(:user)
    url = "https://exercism.org/avatars/1530/0"

    stub_request(:get, url).to_return(
      status: 200,
      body: "<svg></svg>",
      headers: { 'Content-Type' => 'image/svg+xml' }
    )

    User::Avatar::Upload.expects(:call).raises(InvalidAvatarError.new("Invalid file type"))

    # Should not raise - avatars are best-effort
    User::Avatar::CopyFromUrl.(user, url)
  end

  test "handles content type with charset suffix" do
    user = create(:user)
    url = "https://exercism.org/avatars/1530/0"

    stub_request(:get, url).to_return(
      status: 200,
      body: "fake-image-bytes",
      headers: { 'Content-Type' => 'image/jpeg; charset=utf-8' }
    )

    User::Avatar::Upload.expects(:call).with do |_upload_user, file|
      file.content_type == 'image/jpeg' && file.original_filename == 'avatar.jpg'
    end

    User::Avatar::CopyFromUrl.(user, url)
  end
end
