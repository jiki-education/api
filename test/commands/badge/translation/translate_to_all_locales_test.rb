require "test_helper"

class Badge::Translation::TranslateToAllLocalesTest < ActiveSupport::TestCase
  test "enqueues background jobs for all non-English locales" do
    badge = create(:member_badge)

    # Get all supported locales (excluding English)
    expected_locales = (I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES).map(&:to_s).uniq - ["en"]

    # Expect .defer to be called for each target locale
    expected_locales.each do |locale|
      Badge::Translation::TranslateToLocale.expects(:defer).with(badge, locale)
    end

    result = Badge::Translation::TranslateToAllLocales.(badge)

    assert_equal expected_locales.sort, result.sort
  end

  test "excludes English from target locales" do
    badge = create(:member_badge)

    # Ensure .defer is never called with "en"
    Badge::Translation::TranslateToLocale.expects(:defer).never.with(badge, "en")

    # But should be called with other locales
    Badge::Translation::TranslateToLocale.stubs(:defer)

    result = Badge::Translation::TranslateToAllLocales.(badge)

    refute_includes result, "en"
  end

  test "includes both SUPPORTED_LOCALES and WIP_LOCALES" do
    badge = create(:member_badge)

    # Verify the command uses both
    Badge::Translation::TranslateToLocale.stubs(:defer)
    result = Badge::Translation::TranslateToAllLocales.(badge)

    assert_includes result, "hu" # From SUPPORTED_LOCALES
    assert_includes result, "fr" # From WIP_LOCALES
  end

  test "uses .defer() for background job execution" do
    badge = create(:member_badge)

    # Verify .defer is called (not .call)
    Badge::Translation::TranslateToLocale.expects(:defer).at_least_once
    Badge::Translation::TranslateToLocale.expects(:call).never

    Badge::Translation::TranslateToAllLocales.(badge)
  end

  test "returns array of locale strings" do
    badge = create(:member_badge)

    Badge::Translation::TranslateToLocale.stubs(:defer)

    result = Badge::Translation::TranslateToAllLocales.(badge)

    assert_kind_of Array, result
    assert(result.all? { |locale| locale.is_a?(String) })
    assert(result.all? { |locale| locale != "en" })
  end
end
