# Verifies that every production locale is complete: every key English has,
# present and non-empty.
#
# This is the gate that arms on promotion. `test/i18n_parity_test.rb` reports
# the same drift for work-in-progress locales, but only as a warning, because a
# half-translated WIP locale is a normal state that must not block anyone. The
# moment a locale enters PRODUCTION_LOCALES it is being served to users, and a
# missing key renders as an English fallback while an empty one renders as
# nothing at all - neither of which anything currently fails on.
#
# Presence is not translation: a value copied verbatim from English passes here,
# because no mechanical check can tell a deliberate loanword from an untranslated
# string. This answers "is anything blank or absent", which is the failure that
# reaches users as visibly broken output.
#
# Deliberately plain Ruby with no Rails, matching lib/curriculum_content_check.rb:
# it reads the YAML straight off disk, so CI needs no bundle, no database and
# none of the app's native dependencies.
#
#   ruby lib/locale_completeness_check.rb
require 'yaml'

module LocaleCompletenessCheck
  ROOT = File.expand_path('..', __dir__)
  LOCALES_DIR = File.join(ROOT, 'config', 'locales')
  INITIALIZER = File.join(ROOT, 'config', 'initializers', 'i18n.rb')
  REFERENCE_LOCALE = 'en'.freeze

  module_function

  def call
    locales = production_locales
    return [1, 'Could not read PRODUCTION_LOCALES from config/initializers/i18n.rb'] if locales.empty?

    reference = reference_catalogs
    return [1, "No #{REFERENCE_LOCALE} catalogs found under config/locales"] if reference.empty?

    problems = locales.flat_map { |locale| problems_for(locale, reference) }
    checked = locales.size * reference.values.sum(&:size)

    return [1, report(problems, checked)] if problems.any?

    [0, "✓ All #{checked} keys present and non-empty across #{locales.size} production " \
        "locale(s): #{locales.join(', ')}"]
  end

  # The single source of truth is the initializer, read rather than duplicated so
  # promoting a locale there arms this check with no second edit. It cannot be
  # required: the initializer touches Jiki.env and I18n at load time.
  def production_locales
    match = File.read(INITIALIZER)[/PRODUCTION_LOCALES\s*=\s*%w\[(.*?)\]/m]
    match ? Regexp.last_match(1).split : []
  end

  # catalog id (path minus the .en.yml suffix) => { dotted key => value }
  def reference_catalogs
    Dir.glob(File.join(LOCALES_DIR, '**', "*.#{REFERENCE_LOCALE}.yml")).sort.to_h do |path|
      [catalog_id(path), flatten(load_tree(path, REFERENCE_LOCALE))]
    end
  end

  def problems_for(locale, reference)
    reference.flat_map do |catalog, reference_keys|
      path = File.join(LOCALES_DIR, "#{catalog}.#{locale}.yml")
      next [[catalog, locale, 'catalog file is missing']] unless File.exist?(path)

      keys = flatten(load_tree(path, locale))

      missing = (reference_keys.keys - keys.keys).map { |key| [catalog, locale, "missing key '#{key}'"] }
      blank = keys.select { |_, value| value.to_s.strip.empty? }.
        map { |key, _| [catalog, locale, "empty value for '#{key}'"] }

      missing + blank
    end
  end

  def report(problems, checked)
    lines = problems.group_by { |_, locale, _| locale }.map do |locale, entries|
      ["\n#{entries.size} problem(s) in production locale '#{locale}':",
       *entries.map { |catalog, _, message| "  #{catalog}: #{message}" }]
    end

    [*lines.flatten,
     "\n#{problems.size} of #{checked} checked keys are missing or empty."].join("\n")
  end

  def catalog_id(path)
    path.sub("#{LOCALES_DIR}/", '').sub(/\.#{REFERENCE_LOCALE}\.yml\z/, '')
  end

  def load_tree(path, locale)
    (YAML.load_file(path) || {})[locale] || {}
  end

  # Flatten a nested translation hash into { "a.b.c" => value }.
  def flatten(tree, prefix = nil, acc = {})
    tree.each do |key, value|
      full_key = [prefix, key].compact.join('.')
      value.is_a?(Hash) ? flatten(value, full_key, acc) : acc[full_key] = value
    end
    acc
  end
end

# Command-line entrypoint: this runs as a bare script outside the Rails app, so
# stdout and a real exit status are the interface CI reads.
if $PROGRAM_NAME == __FILE__
  status, message = LocaleCompletenessCheck.()
  puts message # rubocop:disable Rails/Output
  exit status # rubocop:disable Rails/Exit
end
