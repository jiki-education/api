require "test_helper"

class User::DetermineLocalesTest < ActiveSupport::TestCase
  test "returns every matching locale, live and draft, in preference order" do
    with_locales(live: %w[en], draft: %w[xx es-ES]) do
      assert_equal %w[xx es-ES en], User::DetermineLocales.(%w[xx es-ES en])
    end
  end

  test "collapses region variants against the full live + draft set" do
    with_locales(live: %w[en], draft: %w[pt-PT pt-BR]) do
      assert_equal %w[pt-PT], User::DetermineLocales.(%w[pt-MZ])
    end
  end

  test "dedupes repeated resolutions" do
    with_locales(live: %w[en]) do
      assert_equal %w[en], User::DetermineLocales.(%w[en en-GB])
    end
  end

  test "returns an empty array when nothing matches" do
    with_locales(live: %w[en]) do
      assert_equal [], User::DetermineLocales.(%w[xx-YY])
    end
  end
end
