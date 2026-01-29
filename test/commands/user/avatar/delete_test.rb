require "test_helper"

class User::Avatar::DeleteTest < ActiveSupport::TestCase
  test "purges avatar when attached" do
    user = create(:user)
    file = Rack::Test::UploadedFile.new(
      Rails.root.join('test', 'fixtures', 'files', 'test_image.jpg'),
      'image/jpeg'
    )
    user.avatar.attach(io: file, filename: "avatar.jpg", content_type: "image/jpeg")

    assert user.avatar.attached?

    User::Avatar::Delete.(user)

    refute user.reload.avatar.attached?
  end

  test "does not raise error when no avatar attached" do
    user = create(:user)

    assert_nothing_raised do
      User::Avatar::Delete.(user)
    end
  end
end
