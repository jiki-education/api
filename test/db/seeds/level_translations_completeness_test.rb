require "test_helper"

# Guards db/seeds/level_translations/*.json against drifting out of sync with
# db/seeds/curriculum.json - the only translated content in this repo that
# isn't a plain config/locales/**/*.yml catalog (see test/i18n_parity_test.rb
# for those), so it needs its own completeness check. See docs/i18n.md.
#
# Severity mirrors I18nParityTest: hard-fail for I18n::PRODUCTION_LOCALES,
# warn (non-fatal) for every other locale that ships a level_translations file.
class LevelTranslationsCompletenessTest < ActiveSupport::TestCase
  CURRICULUM_FILE = Rails.root.join("db", "seeds", "curriculum.json")
  TRANSLATIONS_DIR = Rails.root.join("db", "seeds", "level_translations")
  REQUIRED_FIELDS = %w[milestone_email_subject milestone_email_content_markdown].freeze

  test "every level has a translation entry for every locale it ships" do
    level_uuids = JSON.parse(File.read(CURRICULUM_FILE))["levels"].pluck("uuid")
    entries_by_locale = load_entries_by_locale

    failures = []

    locales_shipped(entries_by_locale).each do |locale|
      problems = problems_for(level_uuids, entries_by_locale[locale] || [])
      next if problems.empty?

      if I18n::PRODUCTION_LOCALES.include?(locale)
        failures << "[#{locale}] (PRODUCTION locale - must be complete)\n  - #{problems.join("\n  - ")}"
      else
        warn "\n[level translations WARNING] locale '#{locale}' is incomplete " \
             "(non-production, not failing the build):\n  - #{problems.join("\n  - ")}\n"
      end
    end

    assert_empty failures, "level_translations completeness failures:\n\n#{failures.join("\n\n")}"
  end

  private
  # One entry array per locale, keyed by the file's basename (e.g. "hu").
  def load_entries_by_locale
    Dir.glob(TRANSLATIONS_DIR.join("*.json")).index_by { |path| File.basename(path, ".json") }.
      transform_values { |path| JSON.parse(File.read(path)) }
  end

  # Every locale we should check: production locales (there always must be
  # complete coverage, even if that means zero entries are needed because en
  # lives on Level itself) plus any locale that ships a file.
  def locales_shipped(entries_by_locale)
    (I18n::PRODUCTION_LOCALES + entries_by_locale.keys).uniq - ["en"]
  end

  def problems_for(level_uuids, entries_for_locale)
    by_uuid = entries_for_locale.index_by { |e| e["level_uuid"] }

    problems = []
    level_uuids.each do |uuid|
      entry = by_uuid[uuid]
      if entry.nil?
        problems << "missing entry for level #{uuid}"
        next
      end

      REQUIRED_FIELDS.each do |field|
        problems << "level #{uuid}: blank '#{field}'" if entry[field].blank?
      end
    end
    problems
  end
end
