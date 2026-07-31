require "test_helper"

class User::NormalizeLocaleTagsTest < ActiveSupport::TestCase
  test "resolves each tag to its canonical form within the given set" do
    assert_equal %w[hu en], User::NormalizeLocaleTags.(%w[hu-HU en-GB], %w[hu en])
  end

  test "skips tags whose exact and collapsed forms are both absent from the set" do
    assert_equal %w[en], User::NormalizeLocaleTags.(%w[xx-YY en], %w[en])
  end

  test "dedupes repeated resolutions while preserving first-occurrence order" do
    assert_equal %w[en], User::NormalizeLocaleTags.(%w[en en-GB en-US], %w[en])
  end

  test "returns an empty array when tags is empty" do
    assert_equal [], User::NormalizeLocaleTags.([], %w[en])
  end
end
