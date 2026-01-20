require "test_helper"

class Lesson::Translation::TranslateToAllLocalesTest < ActiveSupport::TestCase
  test "enqueues background jobs for all non-English locales" do
    lesson = create(:lesson, :exercise)

    # Get all supported locales (excluding English)
    expected_locales = (I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES).map(&:to_s).uniq - ["en"]

    # Expect .defer to be called for each target locale
    expected_locales.each do |locale|
      Lesson::Translation::TranslateToLocale.expects(:defer).with(lesson, locale)
    end

    result = Lesson::Translation::TranslateToAllLocales.(lesson)

    assert_equal expected_locales.sort, result.sort
  end

  test "excludes English from target locales" do
    lesson = create(:lesson, :exercise)

    # Ensure .defer is never called with "en"
    Lesson::Translation::TranslateToLocale.expects(:defer).never.with(lesson, "en")

    # But should be called with other locales
    Lesson::Translation::TranslateToLocale.stubs(:defer)

    result = Lesson::Translation::TranslateToAllLocales.(lesson)

    refute_includes result, "en"
  end

  test "includes both SUPPORTED_LOCALES and WIP_LOCALES" do
    lesson = create(:lesson, :exercise)

    # Get all non-English locales from both constants
    (I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES).map(&:to_s).uniq

    # Should include at least one from each constant
    # Since we defined SUPPORTED_LOCALES = [:en, :hu] and WIP_LOCALES = [:fr]
    # we expect both "hu" and "fr" to be in the target locales
    assert_includes I18n::SUPPORTED_LOCALES.map(&:to_s), "en"
    assert_includes I18n::SUPPORTED_LOCALES.map(&:to_s), "hu"
    assert_includes I18n::WIP_LOCALES.map(&:to_s), "fr"

    # Verify the command uses both
    Lesson::Translation::TranslateToLocale.stubs(:defer)
    result = Lesson::Translation::TranslateToAllLocales.(lesson)

    assert_includes result, "hu" # From SUPPORTED_LOCALES
    assert_includes result, "fr" # From WIP_LOCALES
  end

  test "uses .defer() for background job execution" do
    lesson = create(:lesson, :exercise)

    # Get first non-English locale
    (I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES).map(&:to_s).find { |l| l != "en" }

    # Verify .defer is called (not .call)
    Lesson::Translation::TranslateToLocale.expects(:defer).at_least_once
    Lesson::Translation::TranslateToLocale.expects(:call).never

    Lesson::Translation::TranslateToAllLocales.(lesson)
  end

  test "returns array of locale strings" do
    lesson = create(:lesson, :exercise)

    Lesson::Translation::TranslateToLocale.stubs(:defer)

    result = Lesson::Translation::TranslateToAllLocales.(lesson)

    assert_kind_of Array, result
    assert(result.all? { |locale| locale.is_a?(String) })
    assert(result.all? { |locale| locale != "en" })
  end
end
