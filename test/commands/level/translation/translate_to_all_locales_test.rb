require "test_helper"

class Level::Translation::TranslateToAllLocalesTest < ActiveSupport::TestCase
  test "enqueues background jobs for all non-English locales" do
    level = create(:level)

    # Get all supported locales (excluding English)
    expected_locales = (I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES).map(&:to_s).uniq - ["en"]

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

  test "includes both SUPPORTED_LOCALES and WIP_LOCALES" do
    level = create(:level)

    # Get all non-English locales from both constants
    (I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES).map(&:to_s).uniq

    # Should include at least one from each constant
    # Since we defined SUPPORTED_LOCALES = [:en, :hu] and WIP_LOCALES = [:fr]
    # we expect both "hu" and "fr" to be in the target locales
    assert_includes I18n::SUPPORTED_LOCALES.map(&:to_s), "en"
    assert_includes I18n::SUPPORTED_LOCALES.map(&:to_s), "hu"
    assert_includes I18n::WIP_LOCALES.map(&:to_s), "fr"

    # Verify the command uses both
    Level::Translation::TranslateToLocale.stubs(:defer)
    result = Level::Translation::TranslateToAllLocales.(level)

    assert_includes result, "hu" # From SUPPORTED_LOCALES
    assert_includes result, "fr" # From WIP_LOCALES
  end

  test "uses .defer() for background job execution" do
    level = create(:level)

    # Get first non-English locale
    (I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES).map(&:to_s).find { |l| l != "en" }

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
