require "test_helper"

class User::Avatar::UploadTest < ActiveSupport::TestCase
  test "successfully uploads valid image" do
    user = create(:user)
    file = uploaded_file("test_image.jpg", "image/jpeg")

    User::Avatar::Upload.(user, file)

    assert user.avatar.attached?
  end

  test "sets custom key in xx/yy/zzz/uuid.ext format" do
    user = create(:user)
    file = uploaded_file("test_image.jpg", "image/jpeg")

    User::Avatar::Upload.(user, file)

    assert_match %r{\A[a-f0-9]{2}/[a-f0-9]{2}/[a-f0-9]{3}/[a-f0-9-]+\.jpg\z}, user.avatar.key
  end

  test "purges existing avatar before attaching new one" do
    user = create(:user)
    old_file = uploaded_file("test_image.jpg", "image/jpeg")
    new_file = uploaded_file("test_image.png", "image/png")

    User::Avatar::Upload.(user, old_file)
    old_key = user.avatar.key

    User::Avatar::Upload.(user, new_file)

    refute_equal old_key, user.avatar.key
    assert user.avatar.key.end_with?(".png")
  end

  test "raises InvalidAvatarError when no file provided" do
    user = create(:user)

    error = assert_raises(InvalidAvatarError) { User::Avatar::Upload.(user, nil) }
    assert_equal "No file provided", error.message
  end

  test "raises InvalidAvatarError for invalid content type" do
    user = create(:user)
    file = uploaded_file("test.txt", "text/plain")

    error = assert_raises(InvalidAvatarError) { User::Avatar::Upload.(user, file) }
    assert_equal "Invalid file type", error.message
  end

  test "raises AvatarTooLargeError for files exceeding 5MB" do
    user = create(:user)

    # Create a mock file that reports size > 5MB
    file = mock
    file.stubs(:present?).returns(true)
    file.stubs(:content_type).returns("image/jpeg")
    file.stubs(:size).returns(6.megabytes)

    error = assert_raises(AvatarTooLargeError) { User::Avatar::Upload.(user, file) }
    assert_equal "File exceeds 5MB limit", error.message
  end

  test "normalizes filename to avatar.ext" do
    user = create(:user)
    file = uploaded_file("test_image.jpg", "image/jpeg")

    User::Avatar::Upload.(user, file)

    assert_equal "avatar.jpg", user.avatar.filename.to_s
  end

  test "accepts JPEG images" do
    user = create(:user)
    file = uploaded_file("test_image.jpg", "image/jpeg")

    assert_nothing_raised do
      User::Avatar::Upload.(user, file)
    end
  end

  test "accepts PNG images" do
    user = create(:user)
    file = uploaded_file("test_image.png", "image/png")

    assert_nothing_raised do
      User::Avatar::Upload.(user, file)
    end
  end

  private
  def uploaded_file(filename, content_type)
    Rack::Test::UploadedFile.new(
      Rails.root.join('test', 'fixtures', 'files', filename),
      content_type
    )
  end
end
