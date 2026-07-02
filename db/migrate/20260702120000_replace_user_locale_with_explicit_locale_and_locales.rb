class ReplaceUserLocaleWithExplicitLocaleAndLocales < ActiveRecord::Migration[8.1]
  # Locale becomes a derived value: an explicit user choice (explicit_locale)
  # wins, otherwise it's resolved at runtime from the browser's Accept-Language
  # preferences (locales). Both live on user_data alongside country_code.
  # Every existing user has the old column's default ("en"), which was never an
  # explicit choice, so it isn't migrated — their locale will be derived from
  # their headers instead.
  def change
    remove_column :users, :locale, :string, default: "en", null: false

    add_column :user_data, :explicit_locale, :string
    add_column :user_data, :locales, :string, array: true, default: [], null: false
  end
end
