require "test_helper"

class ExerciseSubmission::File::GenerateDigestTest < ActiveSupport::TestCase
  test "digests content" do
    assert_equal XXhash.xxh64("puts 'hello'").to_s, ExerciseSubmission::File::GenerateDigest.("puts 'hello'")
  end

  test "digests empty string" do
    assert_equal XXhash.xxh64("").to_s, ExerciseSubmission::File::GenerateDigest.("")
  end

  test "same content gives same digest" do
    assert_equal ExerciseSubmission::File::GenerateDigest.("abc"), ExerciseSubmission::File::GenerateDigest.("abc")
  end

  test "different content gives different digest" do
    refute_equal ExerciseSubmission::File::GenerateDigest.("abc"), ExerciseSubmission::File::GenerateDigest.("abd")
  end

  test "strips invalid UTF-8 bytes before digesting" do
    invalid = "hello\xC3world".dup.force_encoding("UTF-8")
    refute invalid.valid_encoding?

    assert_equal XXhash.xxh64("helloworld").to_s, ExerciseSubmission::File::GenerateDigest.(invalid)
  end
end
