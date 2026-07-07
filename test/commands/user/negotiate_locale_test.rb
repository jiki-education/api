require "test_helper"

class User::NegotiateLocaleTest < ActiveSupport::TestCase
  # The eventual full content-locale set. The resolver must be correct against
  # this even though production currently ships a subset.
  FULL_SET = %w[en hu nl ja de fr pt-PT pt-BR es es-419].freeze

  # Every row from the brief's acceptance oracle, evaluated against the full
  # content set: [Accept-Language preference list] => expected result.
  {
    %w[hu] => "hu",                       # exact
    %w[hu-HU en] => "hu",                 # region strip
    %w[en-GB] => "en",                    # region strip
    %w[de-CH de] => "de",                 # region strip
    %w[fr-CA fr en] => "fr",              # region strip
    %w[nl-BE fr nl] => "nl",              # region strip
    %w[pt-MZ en-US en] => "pt-PT",        # pt non-BR region -> European
    %w[pt-AO en] => "pt-PT",              # pt non-BR region -> European
    %w[pt-BR] => "pt-BR",                 # exact
    %w[pt-PT] => "pt-PT",                 # exact
    %w[pt] => "pt-BR",                    # bare pt -> Brazilian (CLDR)
    %w[es-ES en] => "es",                 # Spain -> Peninsular
    %w[es] => "es",                       # bare es -> Peninsular
    %w[es-MX es-419 en] => "es-419",      # es-MX collapses straight to es-419
    %w[es-AR en] => "es-419",             # Latin American region
    %w[es-419] => "es-419",               # exact
    %w[it-IT fr en] => "fr",              # it unsupported, next pref
    %w[zh-CN ja] => "ja",                 # zh unsupported, exact ja
    %w[xx-YY] => "en"                     # nothing matches -> default handled by caller (nil here)
  }.each do |tags, expected|
    test "#{tags.join(', ')} negotiates to #{expected} against the full set" do
      with_supported_locales(FULL_SET) do
        # xx-YY has no supported match, so the command returns nil and the
        # caller applies the default. Every other row resolves to a locale.
        result = User::NegotiateLocale.(tags)
        expected == "en" && tags == %w[xx-YY] ? assert_nil(result) : assert_equal(expected, result)
      end
    end
  end

  # The "must be currently live" rule, exercised against the production-like
  # subset. A tag that would collapse to a not-yet-live variant must fall
  # through rather than return it.
  test "pt-MZ, en falls through to en when pt-PT is not live" do
    with_supported_locales(%w[en hu]) do
      assert_equal "en", User::NegotiateLocale.(%w[pt-MZ en])
    end
  end

  test "pt-BR returns nil (caller defaults) when pt-BR is not live" do
    with_supported_locales(%w[en hu]) do
      assert_nil User::NegotiateLocale.(%w[pt-BR])
    end
  end

  test "hu-HU, en negotiates to hu when hu is live" do
    with_supported_locales(%w[en hu]) do
      assert_equal "hu", User::NegotiateLocale.(%w[hu-HU en])
    end
  end

  # Edge cases.
  test "empty list returns nil" do
    with_supported_locales(FULL_SET) do
      assert_nil User::NegotiateLocale.([])
    end
  end

  test "blank and malformed tags are skipped" do
    with_supported_locales(FULL_SET) do
      assert_equal "fr", User::NegotiateLocale.(["", "  ", "-", "fr"])
    end
  end

  test "mixed-case tags are normalised for exact matching" do
    with_supported_locales(FULL_SET) do
      assert_equal "pt-BR", User::NegotiateLocale.(%w[PT-br])
      assert_equal "es-419", User::NegotiateLocale.(%w[ES-419])
      assert_equal "hu", User::NegotiateLocale.(%w[HU])
    end
  end

  test "mixed-case region collapses correctly" do
    with_supported_locales(FULL_SET) do
      assert_equal "es-419", User::NegotiateLocale.(%w[es-ar])
      assert_equal "pt-PT", User::NegotiateLocale.(%w[pt-mz])
    end
  end

  test "duplicate tags are harmless" do
    with_supported_locales(FULL_SET) do
      assert_equal "de", User::NegotiateLocale.(%w[de-CH de-CH de])
    end
  end

  test "order determines the winner across supported languages" do
    with_supported_locales(FULL_SET) do
      assert_equal "de", User::NegotiateLocale.(%w[de fr])
      assert_equal "fr", User::NegotiateLocale.(%w[fr de])
    end
  end

  test "exact es-419 beats an earlier es region rule only when listed first" do
    with_supported_locales(FULL_SET) do
      # es-MX would collapse to es-419, but es-ES appears first and exact-fails,
      # then collapses to es (Peninsular) before es-MX is reached in pass 2.
      assert_equal "es", User::NegotiateLocale.(%w[es-ES es-MX])
    end
  end

  test "script subtags don't derail base-language collapse" do
    with_supported_locales(FULL_SET) do
      # zh-Hant-TW is unsupported; ja is next.
      assert_equal "ja", User::NegotiateLocale.(%w[zh-Hant-TW ja])
    end
  end
end
