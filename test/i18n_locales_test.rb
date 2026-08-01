require "test_helper"

# Guards the shape of the locale constants. They're hand-maintained in step with
# the front end's ALL_LOCALES (app/lib/locales.ts), and a locale that drifts in
# casing or gets duplicated fails in a way that's hard to trace: the
# explicit_locale validation and the tag negotiation both match exactly, so
# "zh-cn" would be advertised by the front end and then 422 on selection.
class I18nLocalesTest < ActiveSupport::TestCase
  ALL = (I18n::PRODUCTION_LOCALES + I18n::WIP_LOCALES).freeze

  test "locales are unique across the production and WIP sets" do
    assert_equal ALL.uniq, ALL, "duplicate locale(s): #{ALL.tally.select { |_, n| n > 1 }.keys.inspect}"
  end

  test "locales use canonical BCP-47 casing" do
    # Language lowercase; region either a 2-letter country (uppercase) or a
    # 3-digit UN M.49 area, e.g. es-419.
    ALL.each do |locale|
      assert_match(/\A[a-z]{2,3}(-([A-Z]{2}|\d{3}))?\z/, locale, "#{locale.inspect} isn't canonically cased")
    end
  end

  test "every locale with a region variant has a sibling or a collapse rule" do
    # A region-suffixed locale is only reachable if a tag can resolve to it:
    # either the browser sends it verbatim, or LANGUAGE_VARIANTS routes the
    # bare language to it. Without a rule, a bare "zh" would resolve to nothing.
    ALL.select { |locale| locale.include?("-") }.map { |locale| locale.split("-").first }.uniq.each do |language|
      assert_includes User::NormalizeLocaleTags::LANGUAGE_VARIANTS.keys, language,
        "#{language} ships region variants but has no LANGUAGE_VARIANTS rule, so a bare #{language.inspect} resolves to nothing"
    end
  end

  test "every LANGUAGE_VARIANTS target is a real locale" do
    User::NormalizeLocaleTags::LANGUAGE_VARIANTS.each do |language, variant|
      targets = [variant[:bare], variant[:fallback], *variant[:regions].values].uniq
      targets.each do |target|
        assert_includes ALL, target, "#{language} maps to #{target.inspect}, which isn't a known locale"
      end
    end
  end
end
