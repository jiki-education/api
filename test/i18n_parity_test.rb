require "test_helper"

# Locale-parity guard for the translation catalogs we own (config/locales/**).
#
# For every `*.en.yml` catalog we ship (api_errors, api_messages, our devise
# overrides, the validations catalog, the mailer YAMLs, ...) this walks each
# other locale and checks key-tree parity against English, including that each
# shared key carries the same %{interpolation} names.
#
# Severity is locale-set driven, not hardcoded to any one locale:
#   * HARD FAIL for any locale in I18n::PRODUCTION_LOCALES (other than en) that
#     is missing keys, has extra keys, or mismatches interpolations. Flipping a
#     locale into PRODUCTION_LOCALES therefore upgrades its warnings to failures.
#   * WARN (stderr, non-fatal) for every other locale that ships any catalog
#     file. hu today warns on premium_mailer (no hu file yet) - that's expected
#     and handled by a separate task.
#
# Gem-provided catalogs (rails-i18n, devise-i18n) live in the gems, not in
# config/locales, so they're naturally excluded. Catalogs a locale ships that
# have no en reference (e.g. activerecord attribute names) aren't parity-checked
# against en - there's nothing to compare them to.
class I18nParityTest < ActiveSupport::TestCase
  REFERENCE_LOCALE = "en".freeze
  LOCALES_DIR = Rails.root.join("config", "locales")
  INTERPOLATION = /%\{(\w+)\}/

  test "owned locale catalogs are key-tree and interpolation parity with en" do
    reference_catalogs = build_reference_catalogs

    failures = []

    locales_to_check.each do |locale|
      problems = problems_for(locale, reference_catalogs)
      next if problems.empty?

      if hard_fail_locale?(locale)
        failures << format_report(locale, problems)
      else
        warn_report(locale, problems)
      end
    end

    assert_empty failures, "i18n catalog parity failures:\n\n#{failures.join("\n\n")}"
  end

  private
  # Locale => catalog_id => { flattened_key => Set(interpolation names) }
  def build_reference_catalogs
    Dir.glob(LOCALES_DIR.join("**", "*.#{REFERENCE_LOCALE}.yml")).each_with_object({}) do |path, acc|
      acc[catalog_id(path)] = flatten_interpolations(load_tree(path, REFERENCE_LOCALE))
    end
  end

  # Every locale we should check: production locales (bar en) plus any locale
  # that ships at least one catalog file under config/locales.
  #
  # PRODUCTION_LOCALES is unioned in deliberately even though it contributes
  # nothing while production is en-only: when a locale is promoted, it must be
  # checked (and hard-fail) even if it ships NO catalog files at all -
  # otherwise a completely missing catalog would be silently skipped.
  def locales_to_check
    shipped = Dir.glob(LOCALES_DIR.join("**", "*.yml")).filter_map do |path|
      locale = File.basename(path).split(".")[-2]
      locale unless locale == REFERENCE_LOCALE || locale.nil?
    end

    (I18n::PRODUCTION_LOCALES + shipped).uniq - [REFERENCE_LOCALE]
  end

  def hard_fail_locale?(locale) = I18n::PRODUCTION_LOCALES.include?(locale)

  def problems_for(locale, reference_catalogs)
    problems = []

    reference_catalogs.each do |catalog, ref_keys|
      path = LOCALES_DIR.join("#{catalog}.#{locale}.yml")
      unless File.exist?(path)
        problems << "missing catalog file: #{catalog}.#{locale}.yml"
        next
      end

      locale_keys = flatten_interpolations(load_tree(path, locale))

      (ref_keys.keys - locale_keys.keys).sort.each do |key|
        problems << "#{catalog}: missing key '#{key}'"
      end
      (locale_keys.keys - ref_keys.keys).sort.each do |key|
        problems << "#{catalog}: extra key '#{key}' (not in en)"
      end
      (ref_keys.keys & locale_keys.keys).sort.each do |key|
        next if ref_keys[key] == locale_keys[key]

        problems << "#{catalog}: interpolation mismatch for '#{key}' " \
                    "(en: #{ref_keys[key].to_a.sort}, #{locale}: #{locale_keys[key].to_a.sort})"
      end
    end

    problems
  end

  def catalog_id(path)
    path.
      sub("#{LOCALES_DIR}/", "").
      sub(/\.#{REFERENCE_LOCALE}\.yml\z/, "")
  end

  def load_tree(path, locale)
    data = YAML.load_file(path) || {}
    data[locale] || {}
  end

  # Flatten a nested translation hash into { "a.b.c" => Set(interpolation names) }.
  def flatten_interpolations(tree, prefix = nil, acc = {})
    tree.each do |key, value|
      full_key = [prefix, key].compact.join(".")
      if value.is_a?(Hash)
        flatten_interpolations(value, full_key, acc)
      else
        acc[full_key] = value.to_s.scan(INTERPOLATION).flatten.to_set
      end
    end
    acc
  end

  def format_report(locale, problems)
    "[#{locale}] (PRODUCTION locale - must match en)\n  - #{problems.join("\n  - ")}"
  end

  def warn_report(locale, problems)
    warn "\n[i18n parity WARNING] locale '#{locale}' diverges from en " \
         "(non-production, not failing the build):\n  - #{problems.join("\n  - ")}\n"
  end
end
