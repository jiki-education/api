require "test_helper"

class Internal::Profile::AvatarsControllerTest < ApplicationControllerTest
  setup do
    @user = create(:user)
    sign_in_user(@user)
  end

  guard_incorrect_token! :internal_profile_avatar_path, method: :put
  guard_incorrect_token! :internal_profile_avatar_path, method: :delete

  test "PUT update returns profile with avatar_url" do
    image_file = Rack::Test::UploadedFile.new(
      Rails.root.join('test', 'fixtures', 'files', 'test_image.jpg'),
      'image/jpeg'
    )

    User::Avatar::Upload.expects(:call).with(@user, anything).returns(@user)

    put internal_profile_avatar_path, params: { avatar: image_file }
    assert_response :success
    json = response.parsed_body
    assert json.key?("profile")
  end

  test "PUT update returns error for invalid file type" do
    image_file = Rack::Test::UploadedFile.new(
      Rails.root.join('test', 'fixtures', 'files', 'test.txt'),
      'text/plain'
    )

    User::Avatar::Upload.expects(:call).with(@user, anything).raises(
      InvalidAvatarError.new("Invalid file type")
    )

    put internal_profile_avatar_path, params: { avatar: image_file }
    assert_json_error(:unprocessable_entity, error_type: :invalid_avatar)
  end

  test "PUT update returns error for missing file" do
    User::Avatar::Upload.expects(:call).with(@user, nil).raises(
      InvalidAvatarError.new("No file provided")
    )

    put internal_profile_avatar_path, params: {}
    assert_json_error(:unprocessable_entity, error_type: :invalid_avatar)
  end

  test "PUT update returns error for file too large" do
    image_file = Rack::Test::UploadedFile.new(
      Rails.root.join('test', 'fixtures', 'files', 'test_image.jpg'),
      'image/jpeg'
    )

    User::Avatar::Upload.expects(:call).with(@user, anything).raises(
      AvatarTooLargeError.new("File exceeds 5MB limit")
    )

    put internal_profile_avatar_path, params: { avatar: image_file }
    assert_json_error(:unprocessable_entity, error_type: :avatar_too_large)
  end

  test "DELETE destroy returns profile with null avatar_url" do
    User::Avatar::Delete.expects(:call).with(@user).returns(@user)

    delete internal_profile_avatar_path
    assert_response :success
    json = response.parsed_body
    assert json.key?("profile")
    assert_nil json["profile"]["avatar_url"]
  end

  test "DELETE destroy works when no avatar attached" do
    User::Avatar::Delete.expects(:call).with(@user).returns(@user)

    delete internal_profile_avatar_path
    assert_response :success
  end
end
