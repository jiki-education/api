class RemoveProviderFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :provider, :string
  end
end
