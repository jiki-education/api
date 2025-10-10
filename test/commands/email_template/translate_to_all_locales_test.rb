require "test_helper"

class EmailTemplate::TranslateToAllLocalesTest < ActiveSupport::TestCase
  test "enqueues background jobs for all non-English locales" do
    source = create(:email_template, locale: "en")

    # Get all supported locales (excluding English)
    expected_locales = (I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES).map(&:to_s).uniq - ["en"]

    # Expect .defer to be called for each target locale
    expected_locales.each do |locale|
      EmailTemplate::TranslateToLocale.expects(:defer).with(source, locale)
    end

    result = EmailTemplate::TranslateToAllLocales.(source)

    assert_equal expected_locales.sort, result.sort
  end

  test "raises error if source template is not English" do
    source = create(:email_template, :hungarian, locale: "hu")

    error = assert_raises ArgumentError do
      EmailTemplate::TranslateToAllLocales.(source)
    end

    assert_equal "Source template must be in English (en)", error.message
  end

  test "includes both SUPPORTED_LOCALES and WIP_LOCALES" do
    source = create(:email_template, locale: "en")

    # Get all non-English locales from both constants
    (I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES).map(&:to_s).uniq

    # Should include at least one from each constant
    # Since we defined SUPPORTED_LOCALES = [:en, :hu] and WIP_LOCALES = [:fr]
    # we expect both "hu" and "fr" to be in the target locales
    assert_includes I18n::SUPPORTED_LOCALES.map(&:to_s), "en"
    assert_includes I18n::SUPPORTED_LOCALES.map(&:to_s), "hu"
    assert_includes I18n::WIP_LOCALES.map(&:to_s), "fr"

    # Verify the command uses both
    EmailTemplate::TranslateToLocale.stubs(:defer)
    result = EmailTemplate::TranslateToAllLocales.(source)

    assert_includes result, "hu" # From SUPPORTED_LOCALES
    assert_includes result, "fr" # From WIP_LOCALES
  end

  test "excludes English from target locales" do
    source = create(:email_template, locale: "en")

    # Ensure .defer is never called with "en"
    EmailTemplate::TranslateToLocale.expects(:defer).never.with(source, "en")

    # But should be called with other locales
    EmailTemplate::TranslateToLocale.stubs(:defer)

    result = EmailTemplate::TranslateToAllLocales.(source)

    refute_includes result, "en"
  end

  test "uses .defer() for background job execution" do
    source = create(:email_template, locale: "en")

    # Get first non-English locale
    (I18n::SUPPORTED_LOCALES + I18n::WIP_LOCALES).map(&:to_s).find { |l| l != "en" }

    # Verify .defer is called (not .call)
    EmailTemplate::TranslateToLocale.expects(:defer).at_least_once
    EmailTemplate::TranslateToLocale.expects(:call).never

    EmailTemplate::TranslateToAllLocales.(source)
  end
end
