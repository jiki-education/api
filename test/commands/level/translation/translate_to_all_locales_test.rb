require "test_helper"

class Level::Translation::TranslateToAllLocalesTest < ActiveSupport::TestCase
  test "enqueues background jobs for all non-English locales" do
    level = create(:level)

    expected_locales = I18n::ALL_LOCALES - ["en"]

    # Expect .defer to be called for each target locale
    expected_locales.each do |locale|
      Level::Translation::TranslateToLocale.expects(:defer).with(level, locale)
    end

    result = Level::Translation::TranslateToAllLocales.(level)

    assert_equal expected_locales.sort, result.sort
  end

  test "excludes English from target locales" do
    level = create(:level)

    # Ensure .defer is never called with "en"
    Level::Translation::TranslateToLocale.expects(:defer).never.with(level, "en")

    # But should be called with other locales
    Level::Translation::TranslateToLocale.stubs(:defer)

    result = Level::Translation::TranslateToAllLocales.(level)

    refute_includes result, "en"
  end

  test "targets draft locales as well as live ones" do
    level = create(:level)

    Level::Translation::TranslateToLocale.stubs(:defer)

    with_locales(live: %w[en xx], draft: %w[yy]) do
      assert_equal %w[xx yy], Level::Translation::TranslateToAllLocales.(level)
    end
  end

  test "uses .defer() for background job execution" do
    level = create(:level)

    # Verify .defer is called (not .call)
    Level::Translation::TranslateToLocale.expects(:defer).at_least_once
    Level::Translation::TranslateToLocale.expects(:call).never

    Level::Translation::TranslateToAllLocales.(level)
  end

  test "returns array of locale strings" do
    level = create(:level)

    Level::Translation::TranslateToLocale.stubs(:defer)

    result = Level::Translation::TranslateToAllLocales.(level)

    assert_kind_of Array, result
    assert(result.all? { |locale| locale.is_a?(String) })
    assert(result.all? { |locale| locale != "en" })
  end
end
