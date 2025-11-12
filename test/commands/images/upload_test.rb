require "test_helper"

class Images::UploadTest < ActiveSupport::TestCase
  test "successfully uploads image to R2 and returns URL" do
    image_data = File.read(Rails.root.join('test', "fixtures", "files", "test_image.jpg"))
    filename = "test_image.jpg"

    Utils::R2::Upload.expects(:call).with do |r2_key, body, content_type|
      assert_match %r{^test/images/\d+/[\w-]+\.jpg$}, r2_key
      assert_equal image_data, body
      assert_equal 'image/jpeg', content_type
      true
    end

    result = Images::Upload.(image_data, filename)

    assert_match %r{^test/images/\d+/[\w-]+\.jpg$}, result[:r2_key]
    assert_match %r{^https://assets\.jiki\.io/test/images/\d+/[\w-]+\.jpg$}, result[:url]
    assert result[:digest].present?
  end

  test "generates hash-based key structure" do
    image_data = "fake-image-data"
    filename = "test.png"

    Utils::R2::Upload.expects(:call)

    result = Images::Upload.(image_data, filename)

    # Verify the key includes env/images/hash/uuid.ext
    assert_match %r{^test/images/\d+/[\w-]+\.png$}, result[:r2_key]
  end

  test "detects JPEG content type" do
    image_data = File.read(Rails.root.join('test', "fixtures", "files", "test_image.jpg"))

    Utils::R2::Upload.expects(:call).with do |_key, _body, content_type|
      assert_equal 'image/jpeg', content_type
      true
    end

    Images::Upload.(image_data, "image.jpg")
  end

  test "detects PNG content type" do
    # Create minimal PNG data (PNG header)
    image_data = "\x89PNG\r\n\x1a\n"

    Utils::R2::Upload.expects(:call).with do |_key, _body, content_type|
      assert_equal 'image/png', content_type
      true
    end

    Images::Upload.(image_data, "image.png")
  end

  test "raises error for file size exceeding 5MB" do
    large_image_data = "x" * (5.megabytes + 1)
    filename = "large.jpg"

    error = assert_raises(ImageFileTooLargeError) do
      Images::Upload.(large_image_data, filename)
    end

    assert_match(/exceeds maximum/, error.message)
    assert_match(/5MB/, error.message)
  end

  test "raises error for invalid content type" do
    # Create a text file disguised as image
    image_data = "This is not an image"
    filename = "fake.txt"

    error = assert_raises(InvalidImageTypeError) do
      Images::Upload.(image_data, filename)
    end

    assert_match(/Invalid image type/, error.message)
  end

  test "accepts JPEG images" do
    image_data = File.read(Rails.root.join('test', "fixtures", "files", "test_image.jpg"))
    Utils::R2::Upload.expects(:call)

    assert_nothing_raised do
      Images::Upload.(image_data, "test.jpg")
    end
  end

  test "accepts PNG images" do
    image_data = "\x89PNG\r\n\x1a\n"
    Utils::R2::Upload.expects(:call)

    assert_nothing_raised do
      Images::Upload.(image_data, "test.png")
    end
  end

  test "accepts GIF images" do
    image_data = "GIF89a"
    Utils::R2::Upload.expects(:call)

    assert_nothing_raised do
      Images::Upload.(image_data, "test.gif")
    end
  end

  test "accepts WebP images" do
    # Minimal WebP header
    image_data = "RIFF\x00\x00\x00\x00WEBP"
    Utils::R2::Upload.expects(:call)

    assert_nothing_raised do
      Images::Upload.(image_data, "test.webp")
    end
  end

  test "generates consistent digest for same content" do
    image_data = "consistent-content"
    filename = "test.jpg"

    Utils::R2::Upload.expects(:call).twice

    result1 = Images::Upload.(image_data, filename)
    result2 = Images::Upload.(image_data, filename)

    assert_equal result1[:digest], result2[:digest]
  end

  test "returns CDN URL with correct format" do
    image_data = File.read(Rails.root.join('test', "fixtures", "files", "test_image.jpg"))
    filename = "test.jpg"

    Utils::R2::Upload.expects(:call)

    result = Images::Upload.(image_data, filename)

    # Verify URL format (actual key will be different due to hash/uuid)
    assert_match %r{^https://assets\.jiki\.io/test/images/\d+/[\w-]+\.jpg$}, result[:url]
  end
end
