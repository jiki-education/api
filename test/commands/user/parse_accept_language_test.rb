require "test_helper"

class User::ParseAcceptLanguageTest < ActiveSupport::TestCase
  test "parses a simple header" do
    assert_equal %w[en], User::ParseAcceptLanguage.("en")
  end

  test "preserves header order for equal qualities" do
    assert_equal %w[hu en-GB en], User::ParseAcceptLanguage.("hu, en-GB, en")
  end

  test "orders by q-value" do
    assert_equal %w[hu en-GB en], User::ParseAcceptLanguage.("en;q=0.7, hu, en-GB;q=0.9")
  end

  test "normalizes casing" do
    assert_equal %w[en-GB pt-BR zh-Hant], User::ParseAcceptLanguage.("EN-gb, pt-br, ZH-HANT")
  end

  test "deduplicates after normalization" do
    assert_equal %w[en-GB], User::ParseAcceptLanguage.("en-GB, EN-gb;q=0.5")
  end

  test "ignores wildcard" do
    assert_equal %w[hu], User::ParseAcceptLanguage.("hu, *;q=0.5")
  end

  test "ignores entries with q=0" do
    assert_equal %w[hu], User::ParseAcceptLanguage.("hu, en;q=0")
  end

  test "ignores malformed entries" do
    assert_equal %w[en], User::ParseAcceptLanguage.("en, x, not a locale, 123, en--GB, -en")
  end

  test "handles whitespace and stray semicolon params" do
    assert_equal %w[hu en], User::ParseAcceptLanguage.(" hu ; q = 0.9 , en;q=0.8;level=1")
  end

  test "returns empty array for nil" do
    assert_empty User::ParseAcceptLanguage.(nil)
  end

  test "returns empty array for blank string" do
    assert_empty User::ParseAcceptLanguage.("")
  end

  test "returns empty array for garbage" do
    assert_empty User::ParseAcceptLanguage.("!!!, ???")
  end

  test "caps the number of stored locales" do
    header = ("aa".."zz").first(30).join(", ")
    assert_equal 10, User::ParseAcceptLanguage.(header).length
  end
end
