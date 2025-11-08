class RemoveJtiFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_index :users, :jti
    remove_column :users, :jti, :string
  end
end
