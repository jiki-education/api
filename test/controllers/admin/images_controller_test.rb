require "test_helper"

class Admin::ImagesControllerTest < ApplicationControllerTest
  setup do
    @admin = create(:user, :admin)
    sign_in_user(@admin)
  end

  # Authentication and authorization guards
  guard_admin! :admin_images_path, method: :post

  # CREATE tests

  test "POST create successfully uploads image and returns URL" do
    image_data = File.binread(Rails.root.join('test', "fixtures", "files", "test_image.jpg"))
    image_file = Rack::Test::UploadedFile.new(
      Rails.root.join('test', "fixtures", "files", "test_image.jpg"),
      'image/jpeg'
    )

    Images::Upload.expects(:call).with(image_data, 'test_image.jpg').returns({
      r2_key: 'development/images/123/uuid.jpg',
      url: 'https://assets.jiki.io/development/images/123/uuid.jpg',
      digest: '123456'
    })

    post admin_images_path, params: { image: image_file }
    assert_response :created
    assert_json_response({
      url: 'https://assets.jiki.io/development/images/123/uuid.jpg'
    })
  end

  test "POST create returns 422 when no image file provided" do
    post admin_images_path, params: {}, as: :json

    assert_response :unprocessable_entity
    assert_json_response({
      error: 'No image file provided'
    })
  end

  test "POST create returns 422 when file size exceeds limit" do
    image_data = File.binread(Rails.root.join('test', "fixtures", "files", "test_image.jpg"))
    image_file = Rack::Test::UploadedFile.new(
      Rails.root.join('test', "fixtures", "files", "test_image.jpg"),
      'image/jpeg'
    )

    Images::Upload.expects(:call).with(image_data, 'test_image.jpg').raises(
      ImageFileTooLargeError.new('Image file size exceeds maximum of 5MB')
    )

    post admin_images_path, params: { image: image_file }
    assert_response :unprocessable_entity
    assert_json_response({
      error: 'Image file size exceeds maximum of 5MB'
    })
  end

  test "POST create returns 422 when invalid file type" do
    image_data = File.binread(Rails.root.join('test', "fixtures", "files", "test_image.jpg"))
    image_file = Rack::Test::UploadedFile.new(
      Rails.root.join('test', "fixtures", "files", "test_image.jpg"),
      'image/jpeg'
    )

    Images::Upload.expects(:call).with(image_data, 'test_image.jpg').raises(
      InvalidImageTypeError.new('Invalid image type. Allowed types: image/jpeg, image/png, image/gif, image/webp')
    )

    post admin_images_path, params: { image: image_file }
    assert_response :unprocessable_entity
    assert_json_response({
      error: 'Invalid image type. Allowed types: image/jpeg, image/png, image/gif, image/webp'
    })
  end

  test "POST create handles multipart form data" do
    image_data = File.binread(Rails.root.join('test', "fixtures", "files", "test_image.jpg"))
    image_file = Rack::Test::UploadedFile.new(
      Rails.root.join('test', "fixtures", "files", "test_image.jpg"),
      'image/jpeg'
    )

    Images::Upload.expects(:call).with(image_data, 'test_image.jpg').returns({
      r2_key: 'key',
      url: 'https://assets.jiki.io/key',
      digest: '123'
    })

    post admin_images_path, params: { image: image_file }
    assert_response :created
    assert_json_response({ url: 'https://assets.jiki.io/key' })
  end
end
