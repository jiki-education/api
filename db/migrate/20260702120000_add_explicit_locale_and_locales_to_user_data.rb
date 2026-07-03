class AddExplicitLocaleAndLocalesToUserData < ActiveRecord::Migration[8.1]
  # Locale becomes a derived value: an explicit user choice (explicit_locale)
  # wins, otherwise it's resolved at runtime from the browser's Accept-Language
  # preferences (locales). Both live on user_data alongside country_code.
  #
  # The old users.locale column is deliberately left in place for now: this
  # deploy stops reading it (User ignores the column), and a later migration
  # drops it once no running code references it any more.
  def change
    add_column :user_data, :explicit_locale, :string
    add_column :user_data, :locales, :string, array: true, default: [], null: false
  end
end
