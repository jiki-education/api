class MakeUserNameNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :users, :name, true
  end
end
