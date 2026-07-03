class DropUserLocaleColumn < ActiveRecord::Migration[8.1]
  # The locale column was retired in a previous deploy: nothing reads or writes
  # users.locale any more (User ignored the column, delegating locale to the
  # data record). It's now safe to drop. Merge this only once that deploy is
  # fully rolled out.
  def change
    remove_column :users, :locale, :string, default: "en", null: false
  end
end
