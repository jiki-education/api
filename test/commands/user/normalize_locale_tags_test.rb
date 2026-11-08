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

  test "a script subtag decides the Chinese variant over the region" do
    assert_equal %w[zh-TW zh-CN], User::NormalizeLocaleTags.(%w[zh-Hant-CN zh-Hans-TW], %w[zh-CN zh-TW])
  end

  test "a script subtag whose variant is absent from the set falls through" do
    assert_equal %w[en], User::NormalizeLocaleTags.(%w[zh-Hant-TW en], %w[en zh-CN])
  end
end
